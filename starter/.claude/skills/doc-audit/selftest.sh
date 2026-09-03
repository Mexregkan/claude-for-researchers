#!/usr/bin/env bash
# selftest.sh — regression suite for doc_lint.sh.
#
# Usage:  bash .claude/skills/doc-audit/selftest.sh
#
# WHY THIS EXISTS.  A pre-filter whose detectors have quietly stopped firing is worse than
# no pre-filter, because its "none" is read as evidence.  Each case below asserts that a
# detector FIRES on input designed to trip it, and the negative cases assert that a
# well-formed input is NOT flagged — a control that cannot fail is not a control.
#
# Exit 0 = all cases pass; 1 = at least one regression.

set -uo pipefail
cd "$(dirname "$0")"
LINT="$(pwd)/doc_lint.sh"
TD=$(mktemp -d "${TMPDIR:-/tmp}/doclint-self.XXXXXX")
trap 'rm -rf "$TD"' EXIT

# A fake project root in the starter layout.
R="$TD/root"
mkdir -p "$R/numerics" "$R/sections" "$R/handoff/msgs" "$R/publications" "$R/archive-old"
printf 'print(1)\n' > "$R/numerics/real_script.py"
printf 'MAXLINES=20\n' > "$R/handoff/hx.sh"
printf 'x\n' > "$R/archive-old/old_script.py"

pass=0; fail=0
# check <name> <file> <expected-exit> <regex that MUST appear> [<regex that must NOT appear>]
check() {
  local name="$1" file="$2" wantrc="$3" wantre="$4" notre="${5:-}"
  local out rc ok=1
  out=$("$LINT" "$file" --root "$R" 2>&1); rc=$?
  [ "$rc" = "$wantrc" ] || ok=0
  echo "$out" | grep -qE "$wantre" || ok=0
  if [ -n "$notre" ] && echo "$out" | grep -qE "$notre"; then ok=0; fi
  if [ "$ok" = 1 ]; then printf "  PASS  %s\n" "$name"; pass=$((pass+1))
  else
    printf "  FAIL  %s  (exit %s, wanted %s; must-have /%s/ %s%s)\n" "$name" "$rc" "$wantrc" "$wantre" \
      "$(echo "$out" | grep -qE "$wantre" && echo found || echo MISSING)" \
      "$( [ -n "$notre" ] && (echo "$out" | grep -qE "$notre" && echo "; forbidden /$notre/ PRESENT" || echo "") )"
    fail=$((fail+1))
  fi
}

echo "=== doc_lint.sh self-test"
echo

# --- 1. missing file is a usage failure, distinct from a vacuous parse
check "missing file -> exit 2" "$R/does-not-exist.tex" 2 'usage:'

# --- 2. an empty document must be LOUD, not a clean run
: > "$R/sections/empty.tex"
check "empty file -> vacuous banner + exit 3" "$R/sections/empty.tex" 3 'VACUOUS'

# --- 3. [1] dangling \ref and unknown \cite must fire; a defined label must not
cat > "$R/workbook.tex" <<'EOF'
\documentclass{article}
\begin{document}
\input{sections/s1}
\bibitem{knownkey} K.
\end{document}
EOF
cat > "$R/sections/s1.tex" <<'EOF'
\section{S}
\label{sec:s1}
See \ref{sec:s1} and \eqref{eq:missing} and \cite{knownkey,nokey}.
EOF
check "[1] fires on dangling \\ref" "$R/sections/s1.tex" 0 'ref\{eq:missing\} -> no'
check "[1] fires on unknown \\cite" "$R/sections/s1.tex" 0 'cite\{nokey\} -> no'
check "[1] does not flag a defined label / known key" "$R/sections/s1.tex" 0 'label universe +: master' 'ref\{sec:s1\}|cite\{knownkey\}'
check "[1] master found through \\input closure" "$R/sections/s1.tex" 0 'workbook.tex and its \\input closure \(2 file'

# --- 4. [1] duplicate label in the universe must fire
cat > "$R/sections/s2.tex" <<'EOF'
\section{T}
\label{sec:s1}
Text.
EOF
sed -i.bak 's|\\input{sections/s1}|\\input{sections/s1}\\input{sections/s2}|' "$R/workbook.tex"
check "[1] fires on duplicate \\label" "$R/sections/s2.tex" 0 'duplicate \\label\{sec:s1\}'

# --- 4b. a master whose \input paths do not resolve relative to its own directory (moved
#        master, odd layout) must still find its sections through the index fallback
mkdir -p "$R/docs/workbooks/odd/sections"
printf '\\documentclass{article}\\begin{document}\\input{odd/sections/o1}\\end{document}\n' > "$R/docs/workbooks/odd/workbookOdd.tex"
printf '\\section{O}\\label{sec:o1}\nSee \\ref{sec:o1}.\n' > "$R/docs/workbooks/odd/sections/o1.tex"
check "[1] closure falls back to the index for an odd master layout" "$R/docs/workbooks/odd/sections/o1.tex" 0 'closure \(2 file' 'ref\{sec:o1\}'

# --- 5. [2] an untyped strength word fires; the same word typed in-paragraph or inside a theorem env does not
cat > "$R/sections/s3.tex" <<'EOF'
\section{U}
This is proved for every n and the mechanism is canonical.

This is a finite verification: proved to n = 8 only.

\begin{theorem}
For all n, the statement is proved.
\end{theorem}
EOF
check "[2] fires on untyped 'proved'" "$R/sections/s3.tex" 0 '1 untyped:'
check "[2] counts the typed paragraph as typed" "$R/sections/s3.tex" 0 '1 strength line\(s\) typed'
check "[2] ignores the theorem environment" "$R/sections/s3.tex" 0 'L2 ' 'L7 '

# --- 6. [3] advocacy must fire on a multi-word phrase (the /x-flag class of bug)
printf '\\section{V}\nIt is easy to see that this is not merely a restatement.\n' > "$R/sections/s4.tex"
check "[3] fires on multi-word advocacy" "$R/sections/s4.tex" 0 '1 advocacy lines'

# --- 7. [4] count leads must fire, and arithmetic must NOT
printf '\\section{W}\nThe claim holds: 38/38 gates, 0 errors.\n' > "$R/sections/s5.tex"
check "[4] fires on '38/38 gates'" "$R/sections/s5.tex" 0 '1 count leads'
printf '\\section{W2}\nAll 12/12 pass.\n' > "$R/sections/s5b.tex"
check "[4] fires on a bare N/N" "$R/sections/s5b.tex" 0 '1 count leads'
# A matrix row with T^2/2 is arithmetic, not a pass count: the guard that stops the bare
# N/N pattern from reading LaTeX fractions as evidence.  (Found by a real audit run.)
cat > "$R/sections/s5c.tex" <<'EOF'
\section{W3}
\begin{pmatrix} 1 & T & T^2/2 \\ 0 & 1 & T \end{pmatrix} and $x^{4}/4$ and 2/25 of them.
EOF
check "[4] does NOT fire on T^2/2 arithmetic" "$R/sections/s5c.tex" 0 '0 count leads'

# --- 8. [5] pointer resolution: missing / moved / present must be told apart
cat > "$R/sections/s6.tex" <<'EOF'
\section{X}
Script \texttt{numerics/real\_script.py} exists.
Script \texttt{numerics/old\_script.py} moved.
Script \texttt{numerics/gone\_script.py} is gone.
EOF
check "[5] resolves an existing path with \\_ escape" "$R/sections/s6.tex" 0 '2 unresolved' 'real_script.py ->'
check "[5] reports a moved file with its new location" "$R/sections/s6.tex" 0 'old_script.py -> not at that path; basename exists at: archive-old/old_script.py'
check "[5] reports a file missing everywhere" "$R/sections/s6.tex" 0 'gone_script.py -> NOT FOUND'

# --- 9. [6] markers and [8] relative dates
printf '\\section{Y}\nTODO finish this; it was run yesterday.\n' > "$R/sections/s7.tex"
check "[6] fires on TODO" "$R/sections/s7.tex" 0 '1 markers'
check "[8] fires on 'yesterday'" "$R/sections/s7.tex" 0 '1 relative dates'

# --- 10. [7] retraction phrase in a workbook gets the replace-in-place advice
printf '\\section{Z}\nThe earlier claim is retracted.\n' > "$R/sections/s8.tex"
check "[7] fires on 'retracted' with workbook advice" "$R/sections/s8.tex" 0 'must be gone, not contradicted'

# --- 11. [9] handoff structure: a bad message fires on every field; a good one is clean
cat > "$R/handoff/msgs/2026-01-01-01-claude-to-codex-bad.md" <<'EOF'
ID: 2026-01-01-01
FROM: claude (X)
TO: codex (Y)
VERDICT: CONFIRMED -- all accepted, and ROUND 9 DELIVERS the theorem.
Body line one.
Body line two.
Body line three.
Body line four.
Body line five.
EOF
check "[9] fires on missing THIS ROUND" "$R/handoff/msgs/2026-01-01-01-claude-to-codex-bad.md" 0 'no THIS ROUND line'
check "[9] fires on missing ## Gates" "$R/handoff/msgs/2026-01-01-01-claude-to-codex-bad.md" 0 'no "## Gates"'
check "[9] fires on missing scope clause" "$R/handoff/msgs/2026-01-01-01-claude-to-codex-bad.md" 0 'no scope clause'
check "[9] fires on a laundering VERDICT line" "$R/handoff/msgs/2026-01-01-01-claude-to-codex-bad.md" 0 'acceptance token'
cat > "$R/handoff/msgs/2026-01-01-02-claude-to-codex-good.md" <<'EOF'
ID: 2026-01-01-02
FROM: claude (X)
TO: codex (Y)
VERDICT: CORRECTED -- your point 2 stands; point 3 is one order off.
THIS ROUND: finite verification to n = 8; it does not establish the all-order statement.

## Claim
One line.

## Gates
G1 exact identity; does not cover n > 8.

## Touched
none

## Needs from you
nothing -- FYI
EOF
check "[9] clean on a well-formed message" "$R/handoff/msgs/2026-01-01-02-claude-to-codex-good.md" 0 'all structural fields present'
check "[9] reads the line cap from hx.sh" "$R/handoff/msgs/2026-01-01-02-claude-to-codex-good.md" 0 'handoff line cap +: 20'
# over the cap
{ cat "$R/handoff/msgs/2026-01-01-02-claude-to-codex-good.md"; for i in $(seq 1 10); do echo "pad $i"; done; } > "$R/handoff/msgs/2026-01-01-03-claude-to-codex-long.md"
check "[9] fires over the line cap" "$R/handoff/msgs/2026-01-01-03-claude-to-codex-long.md" 0 'lines, cap is 20'

# --- 12. markdown: dead relative link fires; inline math with brackets does not
cat > "$R/strategy-map.md" <<'EOF'
## Honesty ledger — what is EXACTLY proven
Next task: none. Stop rule: none.
See [the script](numerics/nothere.py) and [z](M(z)+M(-z)) and [ok](numerics/real_script.py).
EOF
check "[1] fires on a dead markdown link" "$R/strategy-map.md" 0 'dead relative link \(numerics/nothere.py\)'
check "[1] ignores bracketed inline math" "$R/strategy-map.md" 0 '1 dangling refs' 'M\(z\)'
check "[10] strategy-map structure satisfied" "$R/strategy-map.md" 0 "nothing missing for type 'strategy-map'"
# detected as a strategy map by its heading, not its filename
printf '# Route map for the project\nSome prose with no ledger and no next step.\n' > "$R/docs/route.md"
check "type: strategy-map by heading" "$R/docs/route.md" 0 'type detected +: strategy-map'
check "[10] fires on a strategy map with no stop rule" "$R/docs/route.md" 0 'no "stop rule"'

# --- 13. type detection by name and path
printf '\\documentclass{article}\\title{T}\\begin{document}\\begin{abstract}A\\end{abstract}x\\end{document}\n' > "$R/publications/p.tex"
check "type: paper" "$R/publications/p.tex" 0 'type detected +: paper'
printf '\\documentclass{article}\\begin{document}open, proven\\end{document}\n' > "$R/bigPicture.tex"
check "type: big-picture" "$R/bigPicture.tex" 0 'type detected +: big-picture'
# brief.tex has \documentclass AND \title, so it must be matched by NAME before the paper rule
printf '\\documentclass{article}\\title{Brief}\\begin{document}x\\end{document}\n' > "$R/brief.tex"
check "type: brief (not paper)" "$R/brief.tex" 0 'type detected +: brief'
check "type: workbook-master" "$R/workbook.tex" 0 'type detected +: workbook-master'
printf '# Project\n\n## Files\n- x\n' > "$R/CLAUDE.md"
check "type: agent-guide" "$R/CLAUDE.md" 0 'type detected +: agent-guide'
check "[10] fires on an agent guide with no Current status" "$R/CLAUDE.md" 0 'no "Current status" section'

echo
printf "=== %d passed, %d failed\n" "$pass" "$fail"
[ "$fail" = 0 ] || exit 1
