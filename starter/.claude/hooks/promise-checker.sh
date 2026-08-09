#!/bin/bash
# promise-checker.sh — Stop hook
#
# Fires when Claude finishes a response. Scans the last assistant turn for
# "performative compliance" phrases — cases where Claude says it saved, noted,
# or remembered something without actually calling a write tool.
#
# Adapted from flonat/claude-research (github.com/flonat/claude-research).
#
# Install: add to .claude/settings.json under "Stop":
#   "Stop": [{
#     "hooks": [{"type": "command", "command": "bash .claude/hooks/promise-checker.sh"}]
#   }]

set -euo pipefail

# Phrases that indicate Claude claims to have persisted something.
PROMISE_PATTERNS=(
  "I'll remember"
  "I've noted"
  "I've saved"
  "I've recorded"
  "I'll note"
  "I've logged"
  "noted that"
  "I'll keep that in mind"
  "I've updated"
  "I've added that"
  "saved to memory"
  "I've made a note"
)

# Read Claude Code hook input from stdin (JSON).
INPUT=$(cat)

# Extract the last assistant message text.
LAST_TURN=$(echo "$INPUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
messages = data.get('messages', [])
for msg in reversed(messages):
    if msg.get('role') == 'assistant':
        content = msg.get('content', '')
        if isinstance(content, list):
            text = ' '.join(b.get('text','') for b in content if isinstance(b,dict))
        else:
            text = str(content)
        print(text)
        break
" 2>/dev/null || echo "")

# No early exit on an empty LAST_TURN: the handoff check below does not depend on
# the transcript, and bailing here used to skip it whenever the last turn could
# not be parsed.

# Check whether any write tools were called in this turn.
WROTE_FILE=$(echo "$INPUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
tool_uses = [m for m in data.get('messages', []) if m.get('role') == 'tool_use']
write_tools = {'Write', 'Edit', 'MultiEdit', 'NotebookEdit'}
found = any(t.get('name','') in write_tools for t in tool_uses)
print('yes' if found else 'no')
" 2>/dev/null || echo "no")

# Scan for promise phrases (nothing to scan if the turn could not be parsed).
FOUND_PROMISE=""
if [ -n "$LAST_TURN" ]; then
  for pattern in "${PROMISE_PATTERNS[@]}"; do
    if echo "$LAST_TURN" | grep -qi "$pattern"; then
      FOUND_PROMISE="$pattern"
      break
    fi
  done
fi

# --- handoff stub check (no-op unless this project has a handoff/ mailbox) -----
# A message left as an empty template is worse than no message: the other agent
# opens a blank form and the thread stalls. hx.sh refuses to create a body-less
# message; this is the backstop for the explicit `--stub` path, and for a stub
# that got written and then forgotten. Must not abort the hook: || true.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HX_LINT=""
if [ -f "$REPO_ROOT/handoff/hx.sh" ]; then
  HX_LINT=$( (cd "$REPO_ROOT" && bash handoff/hx.sh lint 2>&1) || true )
  case "$HX_LINT" in
    *FAIL*) : ;;          # keep it, there is something to report
    *)      HX_LINT="" ;; # clean, say nothing
  esac
fi

# Both checks can fire in the same turn, and they are independent problems — so
# report BOTH rather than letting whichever is tested first mask the other.
PROMISE_HIT=""
[ -n "$FOUND_PROMISE" ] && [ "$WROTE_FILE" = "no" ] && PROMISE_HIT="$FOUND_PROMISE"

if [ -n "$PROMISE_HIT" ] || [ -n "$HX_LINT" ]; then
  PROMISE_HIT="$PROMISE_HIT" HX_LINT="$HX_LINT" python3 -c "
import json, os
notes = []
phrase = os.environ.get('PROMISE_HIT', '')
lint = os.environ.get('HX_LINT', '')
if phrase:
    notes.append(
        'promise-checker: You said something like \"%s\" but no file was written. '
        'If you intended to save or record something, do it now with a Write or Edit call. '
        'If you only meant it conversationally, that is fine — but be precise: '
        'do not say you have saved something you have not saved.' % phrase
    )
if lint:
    notes.append(
        'handoff-lint: an outgoing handoff message is unfilled or over the line cap. '
        'Do NOT leave it — the other agent would open a blank template. Fix it now, '
        'then re-run: bash handoff/hx.sh lint\n' + lint
    )
feedback = {
  'hookSpecificOutput': {
    'hookEventName': 'Stop',
    'permissionDecision': 'allow',
    'additionalContext': '\n\n'.join(notes)
  }
}
print(json.dumps(feedback))
"
fi

exit 0
