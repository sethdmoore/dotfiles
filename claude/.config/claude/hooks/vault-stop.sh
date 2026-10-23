#!/usr/bin/env bash
# Stop hook. The logic is `notes.py stop`. A failure there prints nothing and exits 0, so a broken check never blocks a stop.
python3 "$(dirname "${BASH_SOURCE[0]}")/notes.py" stop 2>/dev/null
exit 0
