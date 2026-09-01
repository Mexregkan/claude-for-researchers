---
name: claim-audit
description: Audit what a passing script actually established, before writing any prose about it — build the computed-object ledger, rewrite every check's label as the weakest statement that makes its body pass, and separate the verdict on someone else's work from your own new claim. Run after the script passes and BEFORE the summary, commit message, CHANGELOG row or workbook section exists.
---

# claim-audit — be the first hostile reader of your own result

## Why this exists

The calculation is usually right. The **naming** is what goes wrong.

The mechanism is worth stating precisely, because it tells you where to intervene. An
overclaim is not invented in the summary. It is minted earlier, in the **label on a check** —
and the summary, the commit message, the `CHANGELOG.md` row and the workbook section then all
inherit that label, because they are written in the same pass, from the same context, by the
same process. By the time you are drafting prose, you are not writing a claim; you are copying
one. Auditing the summary audits the copy.

The structural consequence: if nobody reads the label against the body, **the first adversarial
reader of a result is whoever you send it to** — a collaborator, a referee, or a second agent.
So of course they find something. Nothing upstream of them ever tested the claim against a
hostile reading.

This skill inserts that hostile read *before* the claim leaves the session.

## When to invoke

**Mandatory** before any of these exists for a piece of work: a summary to the user, a commit
message, a `CHANGELOG.md` row, a workbook section, a message to another agent. Also invoke when
adjudicating someone else's result, and whenever you are about to write the words *proved*,
*derived*, *constructed*, *canonical*, *unique*, *complete*, *exactly*, *every*, *all orders*,
or *resolves*.

Order of operations: **script passes → claim-audit → prose.** Never prose first.

## Step 0 — mechanical pre-filter

```bash
bash .claude/skills/claim-audit/gate_audit.sh <script>
```

It reports four things: hand-assigned values, label-budget violations, advocacy language in
labels, and bodies whose shape may be true for every input. It is a **pre-filter, not a
verdict** — it cannot read mathematics. A clean run means no cheap tell fired, never that the
labels are honest. Steps 1–3 are the actual audit and are not optional when step 0 is quiet.

It needs your checks to carry labels — `gate("short neutral description", <expression>)` or the
bracket form in Wolfram. If it reports **PARSED ZERO LABELLED CHECKS**, it did not run; do not
report it as clean. That is also a finding in itself: a check with no label cannot be audited,
and cannot be reported honestly either, because the sentence you eventually write about it gets
invented later, from memory, in a different pass.

## Step 1 — the computed-object ledger (the load-bearing step)

One row per headline you intend to write. Fill the columns **left to right**; never write
column 3 first and reverse-engineer column 1.

| # | symbol **literally constructed in the code** | quantifier actually established | headline as drafted |
|---|---|---|---|
| 1 | `L = A @ D` (leading term only) | leading order; no higher term exists in the file | ~~"the full operator is constructed"~~ |

**Rules, each of which catches a distinct real overclaim:**

- **A noun in column 3 that does not appear in column 1 is banned.** If the code contains a
  leading matrix and the headline says "the operator", the headline is wrong on sight — the
  noun was chosen for what the object is *meant to become*.
- **Column 2 must name the restriction explicitly**: leading vs full, this order vs all
  orders, generic vs special case, one component vs both, sub vs quotient, sampled vs proved.
  If you cannot state the restriction, you have not identified the object.
- **Anything assigned by hand is ASSUMED.** Downstream checks report "consistent with the
  assumption", never "derived". If a solve or a recursion should have produced the value,
  run the solve; typing the answer and checking its consequences proves only that you can type.
- **A check downstream of an assumption inherits the assumption.** Mark the whole chain.

## Step 2 — the weakest-statement rewrite

For **every** check, answer in one sentence: *what is the weakest statement that makes this
body pass?* Then make that sentence the label. Not a summary of what you hoped to test — the
weakest thing that could have made it pass.

Apply the three killers first:

1. **Is it true for every input of its type?** `M @ M.T` is symmetric for every `M`;
   `f(a) - f(a) == 0`; a determinant is nonzero on a matrix assembled to be invertible. If the
   body would still pass with a random object of the same type substituted for yours, the check
   tests nothing about yours. Substitute one and see.
2. **Was it evaluated where it cannot bite?** A degenerate case, a vanishing leading term, a
   single sampled point instead of the general statement, a regime where the quantity you are
   probing is fixed by construction.
3. **Does it test your typing, or the mathematics?** See the hand-assignment rule above.

> **The single strongest tell, and it costs nothing to apply: if you are writing a sentence
> explaining why a check is *not* trivial, the check is trivial.** That sentence is advocacy —
> generated by anticipating the objection, not by reading the body. It runs *ahead* of the
> check rather than after it, and it typically appears on the same line as the flaw it denies.
> Delete the defence and read the body instead.

**Label discipline going forward.** A label is a **neutral description of the check** —
short (the pre-filter's default budget is 120 characters), no adjectives, no interpretation,
no emphasis markers. Interpretation belongs in the report, where it can be audited as a claim.
Target for any new script: zero budget violations from step 0.

## Step 3 — the honest-report shape

The report — summary, commit message, `CHANGELOG.md` row, message to another agent — carries,
in this order:

1. **What was computed** — the objects from ledger column 1, with column 2's restrictions.
2. **What that licenses** — the headline, already narrowed by steps 1–2, carrying one of the
   statuses from `CLAUDE.md § Research-claim discipline`.
3. **What it explicitly does NOT establish** — mandatory, never omitted, never softened into
   "further work will show". Name the missing object concretely.
4. **Which checks were vacuous** — if a control could not have failed, say **vacuous**. Never
   reword a control until it appears to pass. (`BUGS.md` § C, § I.)

"Passed N/N checks" is not evidence for a mathematical claim. It is evidence that N assertions
about typed objects held. The ledger is what says which of them bear on the claim.

## Step 4 — separate the verdict from the new claim

When replying to someone else — a collaborator, or the other agent through `handoff/` — the
verdict line adjudicates **only the previous exchange**: what you accept, correct, or reject of
*their* points. Your new result gets its **own** line, with its own status and its own step-3
item 3.

Why: a single line reading "confirmed, all corrections accepted — and this round establishes X"
lets an acceptance token launder a claim nobody has read. The acceptance was real; X was not
audited. Two claims, two lines.

Related: never promote an accepted correction into a stronger claim than the corrector made.
"The obstacle is not where you said" does not become "the obstacle is gone". Quote the
correction before building on it.

## Step 5 — the fresh-context check, for a headline that would move a frontier

Hand the script and the drafted headline to a context with **no session narrative** — a
subagent, a second model via `/cross-validate`, or `/reality-check` — asking only:

> Here is a script and a claim. What is the weakest statement consistent with what the script
> actually computes? Which checks would pass for an arbitrary object of the same type?

Do not include your reasoning, your intended conclusion, or the story of how you got there.
Those are exactly what you are trying to test around. Report both readings; do not silently
adopt either.

## Forbidden

- Writing the headline, summary or reply before the ledger exists.
- "Passed N/N checks" offered as the evidence for a claim.
- Reporting a control as passing without stating what it could have detected.
- Reporting `gate_audit.sh` as clean when it parsed zero labelled checks.

## Related

`BUGS.md` § I (claim generation), § C (controls that cannot bite), § H (escalation).
`CLAUDE.md § Research-claim discipline` (the status vocabulary this skill's step 3 uses).
Skills: `/simple-case-gate` (run it *before* computing; this skill runs *after*),
`/reality-check`, `/cross-validate`.
