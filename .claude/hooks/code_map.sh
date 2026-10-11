#!/bin/bash
# Перед каждым «git commit» от Claude: обновить карту кода и добавить её в коммит.
cmd=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)
case "$cmd" in
  *"git commit"*)
    cd "$CLAUDE_PROJECT_DIR" || exit 0
    python3 tools/gen_code_map.py >/dev/null 2>&1 && git add docs/code_map.md
    ;;
esac
exit 0
