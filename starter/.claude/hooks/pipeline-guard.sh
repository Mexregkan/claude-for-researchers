#!/bin/bash
# pipeline-guard.sh — PostToolUse hook (matcher: Write|Edit|NotebookEdit)
#
# Nudges the Pipeline workflow (see CLAUDE.md "## Pipeline workflow"):
#   - you edited a pipeline DOC   -> nudge /apply-pipeline (code follows the doc),
#                                    or /check-pipeline if the code was ground truth.
#   - you edited a documented CODE -> nudge /check-pipeline (+ a pipeline-auditor pass).
#
# It only NUDGES (emits additionalContext); it never blocks an edit.
#
# SELF-QUIETING: on a code edit it says nothing until at least one Pipeline/*.md
# actually exists. So this hook is harmless to leave enabled from day one — it stays
# silent until you adopt the workflow (write your first pipeline doc with /write-pipeline),
# then starts helping automatically. No need to predict at setup whether the project
# will get big.
#
# NOTE: live notebook edits made through a live-kernel MCP (e.g. Wolfbook) do NOT fire
# Write/Edit/NotebookEdit, so this hook won't catch those — the workflow rule in
# CLAUDE.md covers the MCP-edit case.
#
# --- CONFIGURE: which directories hold the project's "main" code -----------------
# Space-separated path fragments. A file edit under any of these is treated as a
# code edit. Default: numerics/. Add yours (e.g. "src/ engine/ notebooks/").
CODE_DIRS="numerics/"
# ---------------------------------------------------------------------------------

set -euo pipefail

INPUT=$(cat)

# extract the edited path (Write/Edit use file_path; NotebookEdit uses notebook_path)
FP=$(echo "$INPUT" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin); ti=d.get('tool_input',{}) or {}
    print(ti.get('file_path') or ti.get('notebook_path') or '')
except Exception:
    print('')
" 2>/dev/null || echo "")

[ -z "$FP" ] && exit 0

BASE=$(basename "$FP")
NUDGE=""

case "$FP" in
  */Pipeline/*.md|Pipeline/*.md)
    NUDGE="pipeline-guard: you edited the pipeline doc '$BASE'. WORKFLOW: when a pipeline updates, the code follows it — run /apply-pipeline to reconcile the documented code (or confirm the code already matches). If instead the code was ground truth and the doc merely drifted, that is /check-pipeline."
    ;;
  *)
    # A code edit only matters once the workflow is in use — stay silent until a
    # pipeline doc exists anywhere in the repo (recursively, so nested stage docs count).
    [ -n "$(find Pipeline -name '*.md' -type f 2>/dev/null | head -1)" ] || exit 0
    # Is the edited file under one of the configured code dirs?
    in_code=0
    for d in $CODE_DIRS; do
      case "$FP" in *"$d"*) in_code=1; break;; esac
    done
    [ "$in_code" -eq 1 ] || exit 0
    NUDGE="pipeline-guard: you edited main code '$BASE'. WORKFLOW: run /check-pipeline on its Pipeline/ doc to catch code/doc drift, and consider a pipeline-auditor pass to confirm it stays healthy + optimized. (If it is one half of a mirrored pair, e.g. .wb/.nb, also sync the mirror.)"
    ;;
esac

[ -z "$NUDGE" ] && exit 0

python3 -c "
import json
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PostToolUse',
    'additionalContext': '''$NUDGE'''
  }
}))
"
exit 0
