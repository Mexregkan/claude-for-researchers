#!/usr/bin/env bash
# selftest.sh — regression suite for gate_audit.sh.
#
# Usage:  bash .claude/skills/claim-audit/selftest.sh
#
# WHY THIS EXISTS. gate_audit.sh is a tool whose OUTPUT IS AN ABSENCE: most of what it
# prints is "none". That makes it uniquely dangerous when it breaks, because a detector
# that has quietly stopped firing looks exactly like a clean script. Two real instances,
# neither of which crashed and both of which printed a plausible number:
#
#   (a) a file containing NO checks at all was reported as a clean run;
#   (b) the helper's own DEFINITION (`gate[l_, c_] := ...`) was counted as a check,
#       inflating every count the tool had ever printed by one.
#
# So every case below asserts that a detector FIRES on input designed to trip it. A control
# that cannot fail is not a control — the same rule the claim-audit skill applies to your
# research checks, applied here to itself. Run this after ANY edit to gate_audit.sh.
#
# Exit 0 = all cases pass; 1 = at least one regression.

set -uo pipefail
cd "$(dirname "$0")"
AUDIT="./gate_audit.sh"
TD=$(mktemp -d)
trap 'rm -rf "$TD"' EXIT

pass=0; fail=0
WDEF='gate[lbl_, cond_] := Module[{}, If[TrueQ[cond], Print["PASS ", lbl], Print["ABORT ", lbl]]];'
PDEF='def gate(label, ok):
    print(("PASS  " if ok else "FAIL  ") + label)
    return ok'

# check <name> <file> <expected-exit> <regex that MUST appear in output>
check() {
  local name="$1" file="$2" wantrc="$3" wantre="$4"
  local out rc
  out=$("$AUDIT" "$file" 2>&1); rc=$?
  if [ "$rc" = "$wantrc" ] && printf '%s' "$out" | grep -qE "$wantre"; then
    printf "  PASS  %s\n" "$name"; pass=$((pass+1))
  else
    printf "  FAIL  %s  (exit %s, wanted %s; pattern /%s/ %s)\n" \
      "$name" "$rc" "$wantrc" "$wantre" \
      "$(printf '%s' "$out" | grep -qE "$wantre" && echo found || echo MISSING)"
    fail=$((fail+1))
  fi
}

echo "=== gate_audit.sh self-test"
echo

# --- 1. bug (a): no checks at all must be LOUD, not silent, and must not exit 0
printf 'x = 1;\nPrint["hello"];\n' > "$TD/nogates.wls"
check "zero checks -> loud banner + exit 3" "$TD/nogates.wls" 3 'PARSED ZERO LABELLED CHECKS'

# --- 2. bug (a), subtler: the helper is DEFINED but never used. Still vacuous.
printf '%s\n' "$WDEF" > "$TD/defonly.wls"
check "definition but no checks -> still vacuous" "$TD/defonly.wls" 3 'PARSED ZERO LABELLED CHECKS'
printf '%s\n' "$PDEF" > "$TD/defonly.py"
check "python def but no checks -> still vacuous" "$TD/defonly.py" 3 'PARSED ZERO LABELLED CHECKS'

# --- 3. bug (b): the definition must NOT be counted as a check
{ printf '%s\n' "$WDEF"
  printf 'gate["a1 plain check", red[x] === 0];\n'
  printf 'gate["a2 plain check", red[y] === 0];\n'; } > "$TD/three.wls"
check "2 checks + 1 definition -> parsed 2"   "$TD/three.wls" 0 'checks parsed +: 2'
check "2 checks + 1 definition -> 1 skipped"  "$TD/three.wls" 0 'definitions skipped +: 1'

# --- 4. accounting must reconcile against the independent occurrence count
check "parse accounting consistent" "$TD/three.wls" 0 'consistent: every call site'

# --- 5. detector [2]: an over-budget label
{ printf '%s\n' "$WDEF"
  printf 'gate["%s", red[x] === 0];\n' "$(printf 'y%.0s' $(seq 1 200))"; } > "$TD/long.wls"
check "[2] fires on a >120-char label" "$TD/long.wls" 0 '1 of 1 labels exceed'

# --- 6. detector [3]: multi-word advocacy. This is the shape that caught a real regex bug
#        where every multi-word alternative had silently become unmatchable.
{ printf '%s\n' "$WDEF"
  printf 'gate["this is not merely a restatement of the hypothesis", red[x] === 0];\n'; } > "$TD/adv.wls"
check "[3] fires on multi-word advocacy" "$TD/adv.wls" 0 '1 advocacy labels'

# --- 7. detector [4]: bodies true for every input of their type
{ printf '%s\n' "$WDEF"
  printf 'gate["k check", Simplify[MatrixExp[-A] - Inverse[MatrixExp[A]]] === 0];\n'; } > "$TD/univ.wls"
check "[4] fires on exp(-A) vs Inverse[exp(A)]" "$TD/univ.wls" 0 '1 universal-shape bodies'
{ printf '%s\n' "$PDEF"
  printf 'gate("sym check", np.allclose(M @ M.T, (M @ M.T).T))\n'; } > "$TD/univ.py"
check "[4] fires on a transpose symmetry (python)" "$TD/univ.py" 0 '1 universal-shape bodies'
{ printf '%s\n' "$PDEF"
  printf 'gate("same twice", np.allclose(M, M))\n'; } > "$TD/same.py"
check "[4] fires on the same argument twice" "$TD/same.py" 0 '1 universal-shape bodies'

# --- 8. detector [1]: a hand-assigned element, in both bracket styles
{ printf '%s\n' "$WDEF"
  printf 'B[[3, 4]] = -1;\n'
  printf 'gate["b check", red[B] === 0];\n'; } > "$TD/hand.wls"
check "[1] fires on a Wolfram hand-assigned part" "$TD/hand.wls" 0 'B\[\[3, 4\]\] = -1'
{ printf '%s\n' "$PDEF"
  printf 'T[3,1] = -1.0\n'
  printf 'gate("b check", ok)\n'; } > "$TD/hand.py"
check "[1] fires on a python element assignment" "$TD/hand.py" 0 'T\[3,1\] = -1.0'

# --- 9. a custom helper name must work, and its absence must still be loud
{ printf 'def check(label, ok):\n    return ok\n'
  printf 'check("a real check", x == 1)\n'; } > "$TD/custom.py"
check "GATE=check finds a renamed helper" "$TD/custom.py" 3 'PARSED ZERO LABELLED CHECKS'
out=$(GATE=check "$AUDIT" "$TD/custom.py" 2>&1); rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -qE 'checks parsed +: 1'; then
  printf "  PASS  %s\n" "GATE=check parses the renamed helper"; pass=$((pass+1))
else
  printf "  FAIL  %s (exit %s)\n" "GATE=check parses the renamed helper" "$rc"; fail=$((fail+1))
fi

# --- 10. an unreadable file is a DISTINCT failure from a vacuous parse
check "missing file -> exit 2" "$TD/does-not-exist.wls" 2 'usage:'

echo
printf "=== %d passed, %d failed\n" "$pass" "$fail"
[ "$fail" = 0 ] || exit 1
