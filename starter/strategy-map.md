# [Branch or Project] — strategy map (the route plan)

<!--
WHAT THIS IS
  A strategy map is the *route* from where you are to the goal, written down as a
  set of named, ordered strategies (A, B, C, ...). Each is a multi-step plan
  toward one sub-goal, with a status and cross-references.

WHY IT IS SEPARATE FROM next-session-prompts.md
  next-session-prompts.md answers "what is the very next action". This file
  answers "what is the overall plan, and which routes have been tried or ruled
  out". The queue is the next step; the strategy map is the strategy. On a
  multi-month proof or analysis, writing the strategy down stops you re-attempting
  dead ends and makes the dependency structure explicit.

  (Do not confuse this with the *pipeline* workflow — that documents a big *code*.
  A strategy map plans the *research*: proofs, analytic work, write-ups, as well
  as code.)

HOW TO KEEP IT
  - One file per active branch/sub-project (e.g. topic-a-strategy.md).
  - Give a recommended order at the top.
  - When a strategy completes, fold its result into CHANGELOG.md and the
    big-picture status ledger (bigPicture.tex), and mark it DONE here.
  - Record falsified detours so nobody (you, a collaborator, or Claude) repeats
    a route you already ruled out.
  - Keep the honesty ledger at the end current — it is what stops "tried one
    case numerically" from silently becoming "proven".
-->

**Recommended order:** A → C → E  (B and D are optional / can run in parallel).

---

## Strategy A — [sub-goal in a few words]

**Idea:** [one line: the approach, why it should work].
**Status:** [not started / in progress / blocked on X / DONE].

1. [step] — [script or workbook.tex \S] — [result, or "open"]
2. [step] — [...] — [...]
3. [step] — [...] — [...]

**Falsified detours:** [what was tried on this route and ruled out, with the
one-line reason, so it is not attempted again].

---

## Strategy B — [sub-goal]

**Idea:** [one line].
**Status:** [...].

1. [step] — [...] — [...]
2. [...]

**Falsified detours:** [none yet / ...].

---

## Strategy C — [sub-goal]

**Idea:** [one line].
**Status:** [...].

1. [...]

**Falsified detours:** [...].

---

## Honesty ledger — what is EXACTLY proven

<!-- The short, blunt list that keeps status from inflating. Update it whenever a
     strategy moves. Distinguish the epistemic levels explicitly. -->

- **Proven (theorem / machine-checked):** [list, or "nothing yet"].
- **Numerically verified to N digits (structure clear, value not analytic):** [list].
- **Argument modulo stated inputs (rigorous IF [X] holds):** [list the assumed inputs].
- **Open:** [the current frontier — what is genuinely unproven].

<!-- Rule: a claim moves up a level only when the work to justify the higher level
     is actually done. "Checked one case" is the second bullet, never the first. -->
