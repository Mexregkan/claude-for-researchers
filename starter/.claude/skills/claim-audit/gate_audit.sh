#!/usr/bin/env bash
# gate_audit.sh — mechanical tells that a check's LABEL claims more than its BODY tests.
#
# Usage:  bash .claude/skills/claim-audit/gate_audit.sh <script>
#         GATE=check bash .claude/skills/claim-audit/gate_audit.sh <script>   # other helper name
#         LABELCAP=80 bash .claude/skills/claim-audit/gate_audit.sh <script>  # tighter budget
#
# WHAT IT NEEDS FROM YOU. It reads scripts whose checks are written as a labelled call:
#
#     gate["short neutral description", <expression that must be True>]     (Wolfram)
#     gate("short neutral description", <expression that must be True>)     (Python, Julia, R)
#
# If your checks are bare asserts with no label, this script has nothing to read — and that
# is itself the finding. A check without a label cannot be audited, and cannot be reported
# honestly either, because the sentence you eventually write about it is invented later,
# from memory, in a different pass. Wrapping checks in a two-argument helper is a five-line
# change and it is the thing that makes the rest of this skill possible.
#
# WHAT IT IS. A HEURISTIC PRE-FILTER, not a verdict. It cannot read mathematics. It surfaces
# four shapes that ship overclaims, so the corresponding BODIES get read before any prose is
# written about them. A clean run means "no cheap tell fired" — NEVER "the labels are
# honest". The ledger in SKILL.md is the actual gate, and it is not optional when this is
# quiet.
#
# EXIT STATUS: 0 = ran (findings or not) · 2 = unreadable file · 3 = parsed ZERO checks, so
# it did not actually run. 3 is deliberately not 0: a silent clean report on a file this
# script could not parse is the one failure that would make it worse than useless.

set -uo pipefail

f="${1:-}"
if [ -z "$f" ] || [ ! -f "$f" ]; then
  echo "usage: bash gate_audit.sh <script>" >&2
  exit 2
fi
LABELCAP="${LABELCAP:-120}"
GATE="${GATE:-gate}"

echo "=== gate_audit: $f"
echo "    helper name: $GATE()   label budget: $LABELCAP chars"
echo

# ---------------------------------------------------------------- 1. hand assignments
# A quantity written in by direct element-assignment is an ASSUMPTION. Any check downstream
# of it tests the consistency of your own typing, not the mathematics. (BUGS.md sec I.)
echo "--- [1] HAND-ASSIGNED ELEMENTS (ASSUMED, never 'derived')"
if grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*(\[\[[^]]*\]\]|\[[0-9]+[^]]*\]|\[[0-9]+\]\[[0-9]+\])[[:space:]]*=[^=]' "$f"; then
  echo "    ^ report each as ASSUMED; downstream checks say 'consistent with the"
  echo "      assumption', never 'derived'. If a solve or a recursion should have"
  echo "      produced the value, run the solve instead of typing the answer."
else
  echo "    none"
fi
echo

# ------------------------------------------- 2-4. per-check extraction and shape tells
GATE="$GATE" LABELCAP="$LABELCAP" python3 - "$f" <<'PY'
import os, re, sys

path = sys.argv[1]
gate = os.environ.get("GATE", "gate")
cap  = int(os.environ.get("LABELCAP", "120"))
src  = open(path, encoding="utf-8", errors="replace").read()

OPEN = {"[": "]", "(": ")"}

def extract(src, name):
    """Find name[...] / name(...) calls; split first string arg (label) from the rest (body)."""
    out = []
    for m in re.finditer(r'(?<![A-Za-z0-9_.])' + re.escape(name) + r'\s*([\[(])', src):
        opener = m.group(1)
        closer = OPEN[opener]
        i = m.end()                      # first char inside the bracket
        # skip the helper's own definition:  gate[l_, b_] :=   /   def gate(label, ok):
        pre = src[max(0, m.start() - 4):m.start()]
        if pre.strip().endswith("def"):
            continue
        depth, j = 1, i
        label, body, past, instr, quote = "", "", False, False, ""
        while j < len(src) and depth > 0:
            c = src[j]
            if instr:
                if c == "\\":
                    j += 2
                    continue
                if c == quote:
                    instr = False
                elif past:
                    body += c
                else:
                    label += c
                j += 1
                continue
            if c in "\"'":
                instr, quote = True, c
                j += 1
                continue
            if c in "[(":
                depth += 1
            elif c in "])":
                depth -= 1
                if depth == 0:
                    break
            elif c == "," and depth == 1:
                past = True
                j += 1
                continue
            if past:
                body += c
            j += 1
        if not past:                     # one-argument call: not a labelled check
            continue
        out.append({
            "line": src.count("\n", 0, m.start()) + 1,
            "label": label.strip(),
            "body": re.sub(r"\s+", " ", body).strip(),
        })
    return out

gates = extract(src, gate)

# --- [0] did it run at all? ----------------------------------------------------------
if not gates:
    print("!!! [0] PARSED ZERO LABELLED CHECKS — THIS AUDIT DID NOT RUN. !!!")
    print()
    print(f"    Nothing in {path} matches  {gate}[\"label\", body]  or  {gate}(\"label\", body).")
    print("    This is NOT a clean result. Either the script uses a different helper name")
    print(f"    (re-run with  GATE=<name> ...), or its checks carry no labels at all — in")
    print("    which case there is nothing to audit mechanically and the ledger in SKILL.md")
    print("    is the whole audit. Do not report 'gate_audit clean'.")
    sys.exit(3)

# --- [2] label budget ----------------------------------------------------------------
print(f"--- [2] LABEL BUDGET: a label is a NEUTRAL DESCRIPTION of the check, <= {cap} chars")
over = [g for g in gates if len(g["label"]) > cap]
print(f"    {len(over)} of {len(gates)} labels exceed the budget.")
if over:
    print("    lines: " + ", ".join(str(g["line"]) for g in over))
    print("    ^ every character over budget is interpretation living in the wrong field.")
    print("      Move it to the report, where it can be audited as a CLAIM.")
    print("      Target for a new script: 0 over budget.")
print()

# --- [3] advocacy --------------------------------------------------------------------
print("--- [3] ADVOCACY IN LABELS (a label that defends itself is defending something)")
ADVOCACY = re.compile(
    r"not\s+merely|not\s+just|not\s+a\s+tautology|not\s+trivial|not\s+the\s+trivial|"
    r"stops\s+this\s+from\s+being|what\s+makes\s+this\s+(bite|non-?trivial)|"
    r"rather\s+than\s+a\s+restatement|reproduc\w+\s+rather\s+than|"
    r"genuinely|actually\s+(tests|checks|shows)|real\s+distinction|"
    r"which\s+is\s+the\s+only\s+part\s+claimed|in\s+the\s+sense\s+that|"
    r"this\s+is\s+what\s+(rules\s+out|excludes)|is\s+NOT\s+(a|an)\s",
    re.IGNORECASE,
)
adv = [g for g in gates if ADVOCACY.search(g["label"])]
for g in adv:
    print(f"  L{g['line']:<5} {g['label'][:130]}...")
if not adv:
    print("    none")
else:
    print("    ^ ANTICIPATORY DEFENCE. Open the body and write the WEAKEST statement that")
    print("      makes it pass. That sentence is the honest label.")
print()

# --- [4] bodies that may be true for every input --------------------------------------
print("--- [4] BODIES THAT MAY BE TRUE FOR EVERY INPUT")
def universal_tells(b):
    why = []
    # X compared with itself, possibly through a call:  f(a) - f(a),  x == x,  allclose(M, M)
    if re.search(r"([A-Za-z_][\w.]*\s*[\[(][^)\]]{0,60}[\])])\s*[-=!]=?=?\s*\1", b):
        why.append("both sides are the SAME expression — an identity, not evidence")
    if re.search(r"(?<![\w.])([A-Za-z_]\w*)\s*(?:-|==|!=|===|=!=)\s*\1(?![\w(])", b):
        why.append("a quantity compared with itself")
    # a comparison helper handed the same argument twice: allclose(M, M), SameQ[x, x]
    if re.search(r"[\[(]\s*([A-Za-z_][\w.]*)\s*,\s*\1\s*[\])]", b):
        why.append("a comparison helper given the SAME argument twice")
    # substituting v -> -v into something already written at -v
    if re.search(r"/\.\s*(\w+)\s*->\s*-\s*\1", b) or re.search(r"subs\(\s*(\w+)\s*,\s*-\s*\1", b):
        why.append("substitution v -> -v compared against an expression already at -v")
    # symmetry of a product that is symmetric for every input
    if re.search(r"(Transpose|\.T\b|transpose|adjoint)", b) and re.search(r"(Symmetric|allclose|==|===)", b):
        why.append("a transpose/symmetry relation that may hold for EVERY object of the type")
    # invertibility/nonsingularity of something built invertible
    if re.search(r"(Det|det|Determinant)\b", b) and re.search(r"(!=\s*0|=!=\s*0|> ?0|Not\[.*0\])", b):
        why.append("a nonzero-determinant check — vacuous if the object was assembled invertible")
    # inverse-of-exponential style identities
    if re.search(r"(MatrixExp|expm|matrix_exp)\s*[\[(]\s*-", b) and re.search(r"(Inverse|inv)\s*[\[(]\s*(MatrixExp|expm|matrix_exp)", b):
        why.append("exp(-A) against inverse(exp(A)) — an identity for EVERY A")
    return why

sc = 0
for g in gates:
    why = universal_tells(g["body"])
    if not why:
        continue
    sc += 1
    print(f"  L{g['line']:<5} {'; '.join(why)}")
    print(f"         body: {g['body'][:150]}")
if not sc:
    print("    none")
print()

print(f"=== SUMMARY: {len(gates)} labelled checks, {len(over)} over label budget, "
      f"{len(adv)} advocacy labels, {sc} universal-shape bodies.")
PY
status=$?

echo
if [ "$status" -eq 3 ]; then
  echo "=== AUDIT DID NOT RUN (see [0] above). Fix the invocation, or do the ledger by hand."
else
  echo "=== This is a PRE-FILTER. Fill the ledger in SKILL.md before writing any prose."
fi
exit "$status"
