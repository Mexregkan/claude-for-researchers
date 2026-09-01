# BUGS.md — recurring-mistake registry (READ BEFORE WRITING ANY CODE)

<!--
INSTRUCTIONS FOR FILLING THIS IN:
- This is a CHECKLIST, not a logbook. Each entry is 2-6 lines: symptom -> cause -> guard.
  The full story of an incident belongs in workbook.tex / CHANGELOG.md; link to it.
- Keep the sections you need, delete the rest, add your own. The letters (A, B, C...)
  exist so entries can be cited in chat and in commit messages ("BUGS.md sec-C").
- The entries below marked [EXAMPLE] are illustrative — replace them with real ones as
  soon as your own project bites you. The unmarked ones are true in almost any project
  and are worth keeping until you know otherwise.
- ADD A NEW CLASS IN THE SAME TURN YOU FIX IT. A trap written down a week later is
  written down wrong, and usually not at all.
-->

**Standing rule (YOUR NAME, DATE): before writing or editing any code, read this file
first** and confirm the change does not repeat a mistake below. After hitting a NEW class
of bug, add it here — **symptom → cause → guard** — in the same turn you fix it. This is
the fast checklist; the full narrative of any single incident lives in the `workbook.tex`
section and the `CHANGELOG.md` row the entry names.

<!-- If a second agent (Codex, etc.) also works in this repo, keep the next line and put
     the registry in ONE file both read. Two copies drift, and the stale one is believed. -->
This file is **shared** — the other agent reads it too. Do not maintain two copies.

Legend: 🔴 has bitten us more than once · ⚠ silent (produced a confident *wrong* answer,
not an error) · ✅ has a mechanical guard.

> **The single most important pattern in this file.** Almost every entry below produced a
> *plausible number*, not a crash. Two consequences, both hard-won:
> **(i) when two diagnostics in one run disagree, the bug is in a diagnostic, not in the
> science** — that disagreement is usually the only tell; and **(ii) a control that cannot
> fail is worse than no control**, because it reads as confirmation. Before reporting a
> control as passing, ask what it could possibly have detected, and if the answer is
> "nothing", say **vacuous**.

---

## A. The engine and its language

<!-- Traps in the computer-algebra system, array library, or language itself: constructs
     that return something wrong rather than raising. This section fills up fastest. -->

- ⚠ **A rewrite rule that matches nothing returns the input unchanged** — which reads as
  "already in the right form", not as an error. Every substitution, simplification, or
  regex pass can fail this way. **Guard: assert the rewrite fired** — compare a term count,
  a hash, or a marker symbol before and after, and abort if the expression is untouched.
- ⚠ **A search or pattern helper that excludes the top level** silently returns "nothing
  found" when the whole expression *is* the thing you were looking for, and every operator
  built on it then returns zero. **Guard: test each helper on the one-element case** before
  trusting it on real data. [EXAMPLE — replace with your engine's actual form of this]
- ⚠ **A container whose equality test is order-sensitive** reports two identical objects as
  different (or two different ones as equal). **Guard: compare by canonical difference —
  build `a − b` and test that it is empty/zero — never by structural equality.**
- 🔴 **Renaming a variable must rename the pattern and the body together.** A half-done
  rename leaves a definition whose left side binds one name and whose right side reads
  another; it keeps working by accident as long as an outer scope supplies the value.

## B. Zero tests, rank tests, and "clean" results that were not

<!-- The verification layer is where wrong answers get certified. Entries here are the
     ones that cost the most, because a bad gate makes everything downstream look fine. -->

- 🔴⚠ **A quantity built at the wrong shape/index/weight is the ZERO object, and comparing
  it against anything reads as agreement.** **Guard: assert both sides are non-trivial
  before comparing them.** A test that cannot name a negative is not a test.
- ⚠ **An aggregate over an EMPTY collection returns a scalar zero, not the zero object** of
  the right shape, so a `≠ 0` check counts a degenerate case as a real result and the
  scalar then flows into code expecting a matrix. **Guard: seed the aggregate with an
  explicit zero of the right type, and report degenerate samples separately.**
- ⚠ **Precision mismatch fits noise.** Feeding a fitting or relation-finding routine more
  digits than your data actually has makes it fit the garbage tail — and it returns a
  confident answer. **Guard: set every input to one common precision strictly INSIDE the
  true accuracy, and gate the result on something other than the residual** (a size /
  height / complexity bound the true answer is known to satisfy).
- ⚠ **A solver on an overdetermined inexact system can return "no solution" for a
  consistent one** (cross-row noise fails its internal check). Never conclude
  "inconsistent" from an empty solve on inexact data — gate consistency separately, then
  solve a well-conditioned square subsystem and verify on all rows.
- 🔴 **Never read numbers off by fitting** (least squares, min-norm) **when the question is
  whether a solution exists.** Fitting an inconsistent system fabricates plausible numbers
  silently; an exact solver fails loudly. Diagnostics that *measure* consistency are fine —
  the ban is on extracting values by fitting.

## C. Controls that cannot bite

<!-- Negative controls are the main defence against everything in section B — which makes
     a broken control the most expensive bug in the project. -->

- 🔴 **A control applied as a post-hoc rewrite of an already-computed result is a no-op.**
  By the time you mutate it, the expression has evaluated and nothing matches, so the
  "control" returns the prediction unchanged — a residual of zero, read as a pass.
  **Guard: carry the mutated quantity as an INPUT, never as a rewrite of the output.**
- 🔴 **A control is vacuous if the thing it removes satisfies the same relation on its own.**
  The controls that bite remove something whose *source* is left uncancelled.
- 🔴 **A control can be true by construction.** If the case you test lands where the claim
  holds *by theorem*, it passes for free and probes nothing. Test against the equation, or
  mutate a coefficient.
- ⚠ **Check for emptiness before scoring.** Half of the natural controls in a structured
  problem are empty by parity/symmetry/degree. **Print the vacuity rather than counting the
  pass.**
- ⚠ **"The old test imposed fewer conditions, so its negative holds a fortiori" — WRONG when
  the test was of a different object.** A-fortiori reasoning needs one system to be a
  literal subsystem of the other: same equations, more of them. A changed map, parameter, or
  target breaks that, and the only honest repair is to re-run and say so. The failure mode
  is seductive because it converts a wasted computation into a free result.

## D. Conventions and dictionaries

<!-- Sign, normalization, ordering and coordinate conventions. These produce beautifully
     self-consistent wrong answers, and they are the hardest class to detect from inside. -->

- 🔴⚠ **A formula imported from a paper is written in the paper's conventions.** Ordering,
  orientation, normalization, and even variable names differ silently, and a mismatched
  import computes perfectly — it just answers a different question. **Guard: gate an
  imported object against something this project measured independently before building
  anything on it.**
- ⚠ **A map written in the wrong chart/basis is still a well-defined map, so it runs and
  returns a clean verdict — the right verdict for the wrong question.** **Guard: check that
  the map permutes a computed invariant** (spectrum, exponents, degrees) rather than
  checking it against a remembered formula.
- ⚠ **Never carry a label across a transform without composing the dictionary.** Re-derive
  the correspondence and gate it by checking it reproduces *both* known cases, with the
  swapped assignment as a control. [EXAMPLE]
- ⚠ **Pin the vocabulary.** Write down which words are synonyms in this project and which
  are not; a term that quietly widens its meaning across sessions ends up asserting
  something you never proved.

## E. Running jobs: headless runs, logs, and long computations

- 🔴 **A clean exit status is not a pass.** A parse failure or a swallowed block can exit 0
  with a truncated or empty log. The real gates are: zero engine error messages in the log,
  zero `ABORT` markers, and the log ends with the script's own done-line. Check all three.
- 🔴 **Never pipe a `tee`-based runner into `head`** — the SIGPIPE kills the job mid-run and
  the truncated log reads like a crash inside your script. Redirect to a file and read it
  afterwards.
- 🔴⚠ **A cached state plus a "we already did X" flag is a stale-data hazard.** The flag says
  done, the data is missing, and the run proceeds with a hole in it — dressed as a passing
  gate. **Guard: verify the DATA per entry, never the flag; make the check idempotent on the
  data so re-running is safe.**
- ✅ **A run that takes much longer than its predecessor is SUSPECT — re-read the code as a
  critic.** Do not just wait, and do not reflex-kill either: diff what changed since the
  last fast run and hunt for the wrong construct. A silent fallback to a slow path (symbolic
  instead of numeric, unpacked instead of packed) is usually a *correctness* bug wearing a
  performance costume.
- ⚠ **Diagnostics belong at cheap precision; reserve expensive precision for the answer.**
- 🔴⚠ **A finished run that never exits.** Symptom: the log is perfect — results written,
  counters printed, done-line present — and the process then holds a core at 100%
  indefinitely. One measured instance burned **40.7 CPU-hours after the mathematics was
  over**, found only because the laptop was hot. Two silent consequences: a runner that
  blocks on the engine never reaches its own gate block, so **the runner's verdict is never
  printed** and you read the raw log instead and assume the runner agreed; and the process
  is reparented to init, so it outlives the terminal, the session and the agent, invisible
  to any per-session check. **Guard: end every script with an explicit quit/exit after the
  done-line, and check the runner's gate block actually printed — a done-line in the log is
  not evidence that the runner returned. As a safety net, run a reaper that kills a job ONLY
  when its log already contains the script's own completion marker.**
- ⚠ **Never kill a long job on elapsed time or CPU load.** Legitimate research runs are
  silent for hours; a staleness rule eventually kills live work, which is worse than a
  wasted core. **Guard: the script's own completion marker is the only admissible evidence
  that the work is over.** A job with no marker is untouchable however long it has run.

## F. LaTeX and documents

- ⚠ **Never alter mathematical content to fix a layout warning** — fix layout only.
- ⚠ **Never edit generated files** (`.aux`, `.log`, `.pdf`, `.bbl`).
- ⚠ **Corrections REPLACE in place, never append.** Sessions read different parts of a long
  document; a stale statement with a distant correction will be found and believed.

## G. Git, files, and process

- ⚠ **Stage explicitly; never `git add .`** — generated and scratch files leak into history.
- ⚠ **One writer at a time.** Commit before handing over to a collaborator or another agent;
  expect commits you did not make.
- 🔴 **Before declaring an obstruction, grep the repo for it.** An "obstruction" claim costs
  one search to check against what the project already proved; spend it. A whole session's
  headline can otherwise go to a solved problem.
- ⚠ **A verdict written in a file header *before* the run keeps its guesses.** After the run,
  re-read the header against the log line by line — a header is a claim, not a plan.
- ⚠ **The always-loaded status section re-grows.** It is appended to instead of replaced, and
  every line costs tokens in every future session. Before deleting anything from it, verify
  the content survives elsewhere (grep each distinctive constant against `CHANGELOG.md`).
- 🔴 **Deleting generated files by extension, size or age eventually deletes a result.** In a
  symbolic project the 2 GB file you must keep and the 2 GB file you must not look identical
  from the outside — same extension, same size, same directory. **Guard: never let a cleanup
  rule decide what is precious. Ask git: only files matching
  `git ls-files --others --ignored --exclude-standard` are candidates, so a tracked file
  cannot be selected at all.** The corollary is that **`.gitignore` is your delete list** —
  if a heavy generated file is precious, commit it or un-ignore it, and one file then drives
  both git and the cleanup.
- ⚠ **Identical file size is a hint, not evidence of a duplicate.** Report candidates,
  confirm with `cmp`, and delete by hand. A dedupe pass that acts on size alone is a
  data-loss bug waiting for its first collision.
- 🔴⚠ **"Gitignored" is a necessary condition for disposable, never a sufficient one.**
  Symptom: a cleanup that correctly refuses to touch tracked files still queues up your
  evidence, because a `generated/` tree is ignored WHOLESALE (most of it is scratch) and some
  of it is the record behind a published claim — with the same extension as the scratch beside
  it. Real collisions, all gitignored: `*.out` meaning hyperref bookmarks *and* engine result
  logs; `*.log` meaning noise *and* the file carrying a cited rank line; `*.mx` meaning scratch
  *and* frozen regression base states. Cause: reading "git calls this ignorable" as "this is
  worthless". **Guard: keep an explicit keep-list of ignored-but-precious paths, have the tool
  COUNT and REPORT what it held back, and run the first sweep of any project as a dry run and
  read every line.** If a precious generated file is small, commit it and the question
  disappears.
- ⚠ **A cleanup tool that logs its own runs becomes a disk-growth source.** Rotate or
  truncate its log on every run.

## H. Strategy selection and escalation

<!-- Sections A-G are bugs in a CALCULATION. This one and section I are bugs in the step
     between calculating and deciding what to do next — and they cost whole weeks, not hours. -->

- 🔴 **A failed simple case is not an invitation to add complexity.** Symptom: a mechanism or
  a claimed-universal formula fails at the lowest admissible order, weight, depth, rank, or
  dimension, and the next thing tried is a *harder* case — or a case with extra free
  parameters that only exist there — in the hope that the missing structure will appear.
  Cause: treating complexity as evidence instead of confronting a counterexample to an
  all-cases claim. **Guard: identify the simplest admissible nondegenerate case and make the
  exact proposal pass there first. If it genuinely fails, preserve the first exact residual
  and stop escalating: diagnose and repair on that same case, or narrow the claim. A modified
  proposal is a new proposal and restarts the gate.** See the `simple-case-gate` skill.
- ⚠ **A simple case excluded *after* it failed is not excluded.** Symptom: "that case is
  degenerate / too simple / outside what we meant" — said for the first time immediately
  after the case broke the proposal. **Guard: the exclusion must follow from the stated
  domain, written down before the test. If you cannot derive it, the failure stands.**
- ⚠ **Replacing an exact failure with a looser test.** Symptom: an exact identity fails, and
  the next run checks it numerically, or on a projection, or averaged over a range — and
  passes. Cause: the looser test cannot see the residual that just appeared. **Guard: a
  weaker test after a failure is not a retest. Keep the exact residual and explain it.**
- ⚠ **A task whose success and failure both change nothing.** Symptom: a proposed calculation
  where you cannot say what a pass would license or what a failure would rule out. Cause: the
  task was chosen because it is runnable, not because it is decision-relevant. **Guard: before
  running it, write one sentence for each outcome. If both read the same, pick another task.**

---

## I. Claim generation — naming more than you computed

<!-- The bug here is not in the number. The number is right. The bug is in the NOUN. -->

> **Why this section exists.** The overclaim is not written in the summary — it is minted
> earlier, in the **label on the check**, and the summary, the commit message, the
> `CHANGELOG.md` row and the workbook section then all inherit it, because they are written
> in one pass from one context by one process. Auditing the summary is auditing a copy.
> **Guard for the whole section: audit the labels after the script passes and BEFORE any
> prose about it exists.** See the `claim-audit` skill.

- 🔴⚠ **The label asserts more than the body checks.** Symptom: `N/N checks passed`, every
  label a confident sentence, and the bodies turn out to be identities. **Guard: a label is a
  NEUTRAL DESCRIPTION of the computation — short, no adjectives, no interpretation.
  Interpretation goes in the report, where it can be audited as a claim. For every check, ask:
  what is the weakest statement that makes this body pass? Make that the label.**
- 🔴⚠ **A sentence explaining why a check is *not* trivial is the strongest evidence that it
  is.** Symptom: prose inside the label pre-empting an objection — "not merely", "not a
  tautology", "this is what stops it from being circular", "genuinely different". Cause: that
  sentence is generated by anticipating criticism, not by reading the body; it runs *ahead* of
  the check rather than after it. **Guard: on writing such a sentence, stop and open the body.
  Delete the defence and state what the body does.**
- 🔴⚠ **A body that would pass for any object of its type.** Symptom: the check compares an
  expression with itself after a substitution, or asserts something true by construction —
  `M @ M.T` is symmetric for every `M`; `f(a) - f(a) == 0`; a determinant is nonzero on a
  matrix assembled to be invertible. **Guard: substitute a random object of the same type. If
  the check still passes, it tests nothing about yours — mark it vacuous and say so.**
- 🔴⚠ **The computed object is restricted; the reported object is not.** Symptom: the code
  builds a leading term, one component, a special case, or a single parameter point, and the
  headline names the whole thing. Cause: the noun is chosen for what the object is *meant to
  become*. **Guard: the computed-object ledger — column 1 the symbol literally constructed in
  the code, column 2 the restriction actually established (leading vs full, this order vs all
  orders, one component vs both, generic vs special), column 3 the headline. A noun in column 3
  that is absent from column 1 is banned.**
- 🔴⚠ **A value assigned by hand, then checked downstream, reads as a derivation.** Symptom:
  an entry is typed in because you know what it should be, and the next check verifies a
  consequence of it — which holds because the algebra is consistent with your typing, not
  because anything produced the value. **Guard: every hand-assignment is ASSUMED. Downstream
  checks say "consistent with the assumption", never "derived". If a recursion or a solve
  should have produced it, run the solve.**
- ⚠ **An acceptance token launders an unaudited claim.** Symptom: one verdict line that
  correctly grades *someone else's* corrections and then, in the same breath, announces a new
  result nobody has read. **Guard: the verdict line adjudicates only the previous exchange.
  A new result gets its own line, its own status tag, and an explicit "what this does not
  establish".**
- ⚠ **Promoting an accepted correction into a stronger claim than the corrector made.**
  Symptom: the corrector says "the obstacle is not where you said"; the report says "the
  obstacle is gone". **Guard: quote the correction before building on it.**

<!-- ---------------------------------------------------------------------------
MAINTAINING THIS FILE

- Promote guards into mechanical gates whenever you can: an assert that aborts beats a
  sentence asking you to remember. Mark those entries ✅ — and say plainly which traps the
  gate does NOT cover, because those still need the human read.
- When an entry has been mechanically eliminated, say so at the top of the section rather
  than deleting it: "these are now abort gates inside <engine>" is useful history.
- Promote a ⚠ to 🔴 the second time it bites. The count is the whole point: it tells you
  where a mechanical guard is worth building.
- Keep it lean. This file is read before code work, so it costs tokens every time. Entries
  earn their place by being short and by naming a guard — an entry with no guard is a
  story, and stories belong in the workbook.
--------------------------------------------------------------------------- -->
