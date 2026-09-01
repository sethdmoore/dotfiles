-- Redragon K724 config GUI — dev builds of ~/scratch/k724-tool/cmd/k724.
--
-- Fyne sets the Wayland app_id from the app's UniqueID
-- ("com.github.k724tool.k724"), but only when built with `-tags wayland`:
--   go run -tags wayland ./cmd/k724
--   go build -tags wayland -o /tmp/k724 ./cmd/k724
-- Without that tag Fyne runs under XWayland with a generic class and this
-- rule will not match.
--
-- Keeps the window parked on workspace 1, floating, without stealing focus.
hl.window_rule({
    name = "k724-dev-to-ws1",
    match = {
        class = "^com\\.github\\.k724tool\\.k724$",
    },
    workspace = "1 silent",
    no_initial_focus = true,
    float = true,
})
