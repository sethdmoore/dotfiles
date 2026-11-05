#!/usr/bin/env bash
# Binds Option+1..5 to the native "Switch to Desktop 1..5" shortcuts.
# A shortcut only works once its Desktop exists in Mission Control.
set -euo pipefail

option=524288
keycodes=(18 19 20 21 23)

for i in 0 1 2 3 4; do
    hotkey=$((118 + i))
    ascii=$((49 + i))
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$hotkey" \
        "{enabled = 1; value = { parameters = ($ascii, ${keycodes[$i]}, $option); type = standard; }; }"
done

# Applies the new shortcuts without logging out.
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
