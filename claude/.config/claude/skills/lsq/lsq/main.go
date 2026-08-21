// lsq — a zero-dependency Logseq helper for the notes-to-linear skill.
//
// It wraps the Logseq local HTTP API and owns the *canonical* note-signature
// hashing used for two-way sync change-detection, so the hash is byte-identical
// on every run (no LLM-derived drift). Linear is intentionally NOT touched here —
// that stays on the claude.ai MCP connector.
//
// Build:   go build -o lsq .        (or GOOS=linux GOARCH=amd64 for the container)
// Env:     LOGSEQ_API_TOKEN   (required)
//          LOGSEQ_API_URL     (optional, default http://host.docker.internal:12315/api)
//
// Commands:
//   lsq search <query> [limit]   → JSON array: blocks whose content matches (case-insensitive)
//   lsq scan  <page>              → JSON array: candidate blocks (index + change flags), lean
//   lsq get   <uuid>              → JSON: one block's full subtree (for building descriptions)
//   lsq sig   <uuid>              → JSON: {uuid, sig, hash} canonical signature + hash
//   lsq prop  <uuid> <key> <val>  → set a block property (non-destructive)
//   lsq append <uuid> <text>      → append a child block, prints new uuid
//   lsq done  <uuid>              → flip the block to a leading DONE marker, prints new hash
package main

import (
	"bytes"
	"crypto/sha1"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"strings"
)

var (
	apiURL  = normalizeURL(envOr("LOGSEQ_API_URL", "http://host.docker.internal:12315/api"))
	token   = os.Getenv("LOGSEQ_API_TOKEN")
	todoSub = regexp.MustCompile(`#(TODO|todo|DOING|doing)\b`) // stripped from signature text
	todoTag = regexp.MustCompile(`#(TODO|todo)\b`)             // open-item marker
	tagRe   = regexp.MustCompile(`#([A-Za-z][\w/-]*)`)
	wsRe    = regexp.MustCompile(`\s{2,}`)
)

// ---- Logseq block model -------------------------------------------------

type Block struct {
	UUID       string          `json:"uuid"`
	Content    string          `json:"content"`
	Marker     string          `json:"marker"`
	Properties map[string]any  `json:"properties"`
	Children   json.RawMessage `json:"children"`
}

func childrenOf(b Block) []Block {
	if len(b.Children) == 0 {
		return nil
	}
	var cs []Block
	if json.Unmarshal(b.Children, &cs) != nil {
		return nil // shallow ["uuid", x] form — treat as no children
	}
	return cs
}

// ---- canonical signature / hash (MUST stay stable across versions) ------

func firstToken(s string) string {
	f := strings.Fields(s)
	if len(f) == 0 {
		return ""
	}
	return strings.ToUpper(f[0])
}

func isDone(b Block) bool {
	switch firstToken(b.Content) {
	case "DONE", "CANCELED", "CANCELLED":
		return true
	}
	switch strings.ToUpper(b.Marker) {
	case "DONE", "CANCELED", "CANCELLED":
		return true
	}
	return strings.Contains(strings.ToLower(b.Content), "#done")
}

func hasTodo(b Block) bool {
	switch firstToken(b.Content) {
	case "TODO", "DOING":
		return true
	}
	return todoTag.MatchString(b.Content)
}

// clean drops property lines (containing "::"), removes workflow tags, trims.
func clean(content string) string {
	var lines []string
	for _, ln := range strings.Split(content, "\n") {
		if strings.Contains(ln, "::") {
			continue
		}
		lines = append(lines, ln)
	}
	txt := strings.Join(lines, "\n")
	txt = todoSub.ReplaceAllString(txt, "")
	return strings.TrimSpace(txt)
}

func gatherOpen(children []Block, acc *[]string) {
	for _, c := range children {
		if isDone(c) {
			continue
		}
		if t := clean(c.Content); t != "" {
			*acc = append(*acc, t)
		}
		gatherOpen(childrenOf(c), acc)
	}
}

func rawSig(b Block) string {
	parts := []string{clean(b.Content)}
	var kids []string
	gatherOpen(childrenOf(b), &kids)
	parts = append(parts, kids...)
	return strings.TrimSpace(strings.Join(parts, "\n"))
}

func hash12(s string) string {
	sum := sha1.Sum([]byte(s))
	return fmt.Sprintf("%x", sum)[:12]
}

// ---- property extraction ------------------------------------------------

func parseProps(content string) map[string]string {
	m := map[string]string{}
	for _, ln := range strings.Split(content, "\n") {
		i := strings.Index(ln, ":: ")
		if i < 0 {
			continue
		}
		key := strings.TrimSpace(ln[:i])
		if key == "" || strings.Contains(key, " ") {
			continue
		}
		m[key] = strings.TrimSpace(ln[i+3:])
	}
	return m
}

type LinearMeta struct {
	ID     string `json:"id"`
	URL    string `json:"url,omitempty"`
	Origin string `json:"origin,omitempty"`
	Synced string `json:"synced,omitempty"`
	Hash   string `json:"hash,omitempty"`
}

func linMeta(b Block) *LinearMeta {
	p := parseProps(b.Content)
	get := func(kebab, camel string) string {
		if v := p[kebab]; v != "" {
			return v
		}
		if b.Properties != nil {
			if v, ok := b.Properties[camel].(string); ok {
				return v
			}
		}
		return ""
	}
	id := get("linear-id", "linearId")
	if id == "" {
		return nil
	}
	return &LinearMeta{
		ID:     id,
		URL:    get("linear-url", "linearUrl"),
		Origin: get("linear-origin", "linearOrigin"),
		Synced: get("linear-synced", "linearSynced"),
		Hash:   get("linear-hash", "linearHash"),
	}
}

func title(content string) string {
	first := strings.Split(content, "\n")[0]
	first = tagRe.ReplaceAllString(first, "")
	first = wsRe.ReplaceAllString(first, " ")
	return strings.TrimSpace(first)
}

func tagsOf(content string) []string {
	var out []string
	seen := map[string]bool{}
	for _, ln := range strings.Split(content, "\n") {
		if strings.Contains(ln, "::") {
			continue
		}
		for _, m := range tagRe.FindAllStringSubmatch(ln, -1) {
			t := m[1]
			switch strings.ToUpper(t) {
			case "TODO", "DOING", "DONE", "CANCELED", "CANCELLED":
				continue
			}
			if !seen[t] {
				seen[t] = true
				out = append(out, t)
			}
		}
	}
	return out
}

// ---- HTTP ---------------------------------------------------------------

func api(method string, args ...any) ([]byte, error) {
	if token == "" {
		return nil, fmt.Errorf("LOGSEQ_API_TOKEN is not set")
	}
	body, _ := json.Marshal(map[string]any{"method": method, "args": args})
	req, err := http.NewRequest("POST", apiURL, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return nil, fmt.Errorf("logseq %s: HTTP %d: %s", method, resp.StatusCode, strings.TrimSpace(string(data)))
	}
	return data, nil
}

func getBlockTree(uuid string) (Block, error) {
	raw, err := api("logseq.Editor.getBlock", uuid, map[string]any{"includeChildren": true})
	if err != nil {
		return Block{}, err
	}
	var b Block
	if err := json.Unmarshal(raw, &b); err != nil {
		return Block{}, err
	}
	if b.UUID == "" {
		return Block{}, fmt.Errorf("block not found (stale/unknown uuid?): %s", uuid)
	}
	return b, nil
}

// ---- commands -----------------------------------------------------------

type ScanNode struct {
	UUID    string      `json:"uuid"`
	Page    string      `json:"page,omitempty"`
	Title   string      `json:"title"`
	Todo    bool        `json:"todo"`
	Done    bool        `json:"done"`
	Tags    []string    `json:"tags,omitempty"`
	Hash    string      `json:"hash"`
	Linear  *LinearMeta `json:"linear,omitempty"`
	Changed bool        `json:"changed"`
}

func walk(b Block, out *[]ScanNode, page string) {
	lm := linMeta(b)
	if hasTodo(b) || lm != nil {
		n := ScanNode{
			UUID: b.UUID, Page: page, Title: title(b.Content),
			Todo: hasTodo(b), Done: isDone(b), Tags: tagsOf(b.Content),
			Hash: hash12(rawSig(b)), Linear: lm,
		}
		if lm != nil {
			n.Changed = lm.Hash != n.Hash
		}
		*out = append(*out, n)
		return // a candidate owns its subtree — do not descend for more
	}
	for _, c := range childrenOf(b) {
		walk(c, out, page)
	}
}

func cmdScan(page string) {
	raw, err := api("logseq.Editor.getPageBlocksTree", page)
	must(err)
	var top []Block
	must(json.Unmarshal(raw, &top))
	out := []ScanNode{}
	for _, b := range top {
		walk(b, &out, page)
	}
	emit(out)
}

type Detail struct {
	Text     string   `json:"text"`
	Done     bool     `json:"done,omitempty"`
	Children []Detail `json:"children,omitempty"`
}

func toDetail(b Block) Detail {
	d := Detail{Text: clean(b.Content), Done: isDone(b)}
	for _, c := range childrenOf(b) {
		d.Children = append(d.Children, toDetail(c))
	}
	return d
}

func cmdGet(uuid string) {
	b, err := getBlockTree(uuid)
	must(err)
	out := map[string]any{
		"uuid":  b.UUID,
		"title": title(b.Content),
		"hash":  hash12(rawSig(b)),
		"done":  isDone(b),
	}
	if lm := linMeta(b); lm != nil {
		out["linear"] = lm
	}
	kids := []Detail{}
	for _, c := range childrenOf(b) {
		kids = append(kids, toDetail(c))
	}
	out["children"] = kids
	emit(out)
}

func cmdSig(uuid string) {
	b, err := getBlockTree(uuid)
	must(err)
	s := rawSig(b)
	emit(map[string]string{"uuid": uuid, "sig": s, "hash": hash12(s)})
}

// ---- search -------------------------------------------------------------

type SearchHit struct {
	UUID    string `json:"uuid"`
	Page    string `json:"page,omitempty"`
	Snippet string `json:"snippet"`
}

// digStr pulls the first non-empty value for any of the candidate keys out of a
// generic map. Logseq's HTTP layer is inconsistent about namespacing pull keys
// (":block/uuid" vs "block/uuid" vs "uuid"), so we try every spelling.
func digStr(m map[string]any, keys ...string) string {
	for _, k := range keys {
		if v, ok := m[k]; ok {
			if s, ok := v.(string); ok && s != "" {
				return s
			}
		}
	}
	return ""
}

func digMap(m map[string]any, keys ...string) map[string]any {
	for _, k := range keys {
		if v, ok := m[k]; ok {
			if mm, ok := v.(map[string]any); ok {
				return mm
			}
		}
	}
	return nil
}

// snippet trims property lines / workflow tags and clips to a single readable line.
func snippet(content string) string {
	s := clean(content)
	s = wsRe.ReplaceAllString(strings.ReplaceAll(s, "\n", " "), " ")
	s = strings.TrimSpace(s)
	if len(s) > 160 {
		s = s[:157] + "..."
	}
	return s
}

func cmdSearch(query string, limit int) {
	q := strings.TrimSpace(query)
	if q == "" {
		emit([]SearchHit{})
		return
	}
	// Case-insensitive literal-substring match. This Logseq build's datascript
	// sandbox does NOT expose clojure.string/lower-case, and a regex passed as an
	// :in parameter arrives as a bare string (".exec is not a function"). The only
	// form that works is building the pattern INSIDE the query with (re-pattern …),
	// so we embed a "(?i)"-flagged, metacharacter-escaped literal of the query.
	pat := clojureStr("(?i)" + regexp.QuoteMeta(q))
	ds := `[:find (pull ?b [:block/uuid :block/content {:block/page [:block/original-name :block/name]}])
	         :where
	         [?b :block/content ?c]
	         [(re-pattern "` + pat + `") ?re]
	         [(re-find ?re ?c)]]`
	raw, err := api("logseq.DB.datascriptQuery", ds)
	must(err)

	// A bad query comes back as HTTP 200 with an {"error": "..."} body, so surface
	// it instead of silently returning no hits.
	var errObj struct {
		Error string `json:"error"`
	}
	if json.Unmarshal(raw, &errObj) == nil && errObj.Error != "" {
		must(fmt.Errorf("logseq datascript: %s", errObj.Error))
	}

	var rows []json.RawMessage
	if err := json.Unmarshal(raw, &rows); err != nil || len(rows) == 0 {
		emit([]SearchHit{})
		return
	}
	out := []SearchHit{}
	seen := map[string]bool{}
	for _, r := range rows {
		// Each row is a one-element vector holding the pulled map — but tolerate
		// a bare map too, in case the shape changes.
		var obj map[string]any
		var arr []map[string]any
		if json.Unmarshal(r, &arr) == nil && len(arr) > 0 {
			obj = arr[0]
		} else if json.Unmarshal(r, &obj) != nil {
			continue
		}
		uuid := digStr(obj, "block/uuid", ":block/uuid", "uuid")
		if uuid == "" || seen[uuid] {
			continue
		}
		seen[uuid] = true
		content := digStr(obj, "block/content", ":block/content", "content")
		pg := digMap(obj, "block/page", ":block/page", "page")
		page := ""
		if pg != nil {
			page = digStr(pg, "block/original-name", ":block/original-name", "original-name",
				"block/name", ":block/name", "name")
		}
		out = append(out, SearchHit{UUID: uuid, Page: page, Snippet: snippet(content)})
		if limit > 0 && len(out) >= limit {
			break
		}
	}
	emit(out)
}

func cmdProp(uuid, key, val string) {
	_, err := api("logseq.Editor.upsertBlockProperty", uuid, key, val)
	must(err)
	fmt.Println("ok")
}

func cmdAppend(uuid, text string) {
	raw, err := api("logseq.Editor.insertBlock", uuid, text, map[string]any{"sibling": false})
	must(err)
	var nb Block
	_ = json.Unmarshal(raw, &nb)
	emit(map[string]string{"uuid": nb.UUID})
}

func cmdDone(uuid string) {
	raw, err := api("logseq.Editor.getBlock", uuid)
	must(err)
	var b Block
	must(json.Unmarshal(raw, &b))
	if b.UUID == "" {
		must(fmt.Errorf("block not found (stale/unknown uuid?): %s", uuid))
	}
	lines := strings.Split(b.Content, "\n")
	first := todoTag.ReplaceAllString(lines[0], "")
	first = strings.TrimSpace(wsRe.ReplaceAllString(first, " "))
	switch firstToken(first) {
	case "TODO", "DOING":
		fields := strings.Fields(first)
		first = strings.TrimSpace(strings.TrimPrefix(first, fields[0]))
	case "DONE", "CANCELED", "CANCELLED":
		// already done
	}
	if ft := firstToken(first); ft != "DONE" && ft != "CANCELED" && ft != "CANCELLED" {
		first = "DONE " + first
	}
	lines[0] = first
	_, err = api("logseq.Editor.updateBlock", uuid, strings.Join(lines, "\n"))
	must(err)
	nb, err := getBlockTree(uuid)
	must(err)
	emit(map[string]string{"uuid": uuid, "first": first, "hash": hash12(rawSig(nb))})
}

// ---- helpers ------------------------------------------------------------

// normalizeURL tolerates LOGSEQ_API_URL being set with or without the /api path.
func normalizeURL(u string) string {
	u = strings.TrimRight(u, "/")
	if !strings.HasSuffix(u, "/api") {
		u += "/api"
	}
	return u
}

// clojureStr escapes a string so it is safe to embed as the body of a
// double-quoted Clojure/EDN string literal inside a datascript query (the
// argument to re-pattern in cmdSearch). Escape backslashes before quotes.
func clojureStr(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `"`, `\"`)
	return s
}

func envOr(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func emit(v any) {
	b, err := json.Marshal(v)
	must(err)
	fmt.Println(string(b))
}

func must(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, "lsq: "+err.Error())
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: lsq <search|scan|get|sig|prop|append|done> ARGS")
	os.Exit(2)
}

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	a := os.Args[2:]
	need := func(n int) {
		if len(a) < n {
			usage()
		}
	}
	switch os.Args[1] {
	case "search":
		need(1)
		limit := 50
		if len(a) > 1 {
			if _, err := fmt.Sscanf(a[1], "%d", &limit); err != nil {
				limit = 50
			}
		}
		cmdSearch(a[0], limit)
	case "scan":
		need(1)
		cmdScan(a[0])
	case "get":
		need(1)
		cmdGet(a[0])
	case "sig":
		need(1)
		cmdSig(a[0])
	case "prop":
		need(3)
		cmdProp(a[0], a[1], a[2])
	case "append":
		need(2)
		cmdAppend(a[0], a[1])
	case "done":
		need(1)
		cmdDone(a[0])
	default:
		usage()
	}
}
