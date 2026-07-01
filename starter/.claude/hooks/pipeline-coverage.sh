#!/bin/bash
# pipeline-coverage.sh — on-demand coverage check for the Pipeline workflow.
#
# Answers "does every main code have a Pipeline/ doc, and does every doc still point
# at a real code?" Prints a table of  main code -> pipeline doc  (present / MISSING),
# and flags orphan docs (a Pipeline file whose code is gone). Run from the repo root:
#     bash .claude/hooks/pipeline-coverage.sh
#
# This is NOT a git/PostToolUse hook — run it yourself when you want a coverage report
# (e.g. after adding a code). Early in a project it will simply report "no pipeline docs
# yet" and not nag: you adopt the workflow only when a code grows big enough to warrant it.
#
# --- CONFIGURE: the map of main code -> its pipeline doc --------------------------
# One "code<TAB>doc" line per MAIN code (the notebooks / engines the project depends
# on — NOT scratch scripts). Fill this in as you write pipeline docs. Examples:
#   numerics/main.wb	Pipeline/main/README.md
#   numerics/engine.m	Pipeline/engine.md
MAP=$(cat <<'EOF'
EOF
)
# ---------------------------------------------------------------------------------

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

# If neither the MAP nor any pipeline docs exist yet, say so and stop (no nagging).
if [ -z "$(printf '%s' "$MAP" | tr -d '[:space:]')" ] && [ -z "$(find Pipeline -name '*.md' -type f 2>/dev/null | head -1)" ]; then
  echo "No pipeline docs yet, and the coverage MAP is empty."
  echo "Adopt the workflow when a code grows too big to hold in context: /write-pipeline it,"
  echo "then add a 'code<TAB>doc' line to the MAP at the top of this script."
  exit 0
fi

echo "=== Pipeline coverage (invariant: every main code has a pipeline) ==="
missing=0
while IFS=$'\t' read -r code doc; do
  [ -z "$code" ] && continue
  cstat="  "; dstat="OK    "
  [ -e "$code" ] || cstat="?!"      # code file missing (map stale)
  [ -e "$doc" ]  || { dstat="MISSING"; missing=$((missing+1)); }
  printf "  [%s] %-40s -> %-40s %s\n" "$cstat" "$code" "$doc" "$dstat"
done <<< "$MAP"

echo ""
echo "=== Orphan pipeline docs (doc present, code not in MAP) ==="
# Pipeline/*.md files not referenced as a doc above (informational).
comm -23 \
  <(find Pipeline -name '*.md' 2>/dev/null | sort) \
  <(printf '%s\n' "$MAP" | cut -f2 | sort -u) \
  | sed 's/^/  (unmapped) /' || true

echo ""
if [ "$missing" -gt 0 ]; then
  echo "RESULT: $missing main code(s) WITHOUT a pipeline — run /write-pipeline for each."
  exit 1
else
  echo "RESULT: all mapped main codes have a pipeline."
fi
