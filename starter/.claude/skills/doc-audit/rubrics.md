# doc-audit rubrics, by document type

Each block names the document's purpose, the **authoritative context** to read before
auditing it, what is **load-bearing** in it, the checklist for step 5 of `SKILL.md`, and the
failure modes that make it worth checking (with the `BUGS.md` section they belong to).

Items marked ★ are the ones that have caught real errors in practice — start there when you
are short of time. Paths below are the starter layout; rename them to your own.

## Common to every type

- **C1 Typed headlines.** Every headline is one of the eight statuses in
  `CLAUDE.md § Research-claim discipline`, and the type as written is the type the evidence
  supports. ★ (`BUGS.md` § I)
- **C2 Scope clause.** Every proved/finite/numerical statement says what it does *not*
  establish, at the point of use, not in a distant caveat. ★
- **C3 Evidence exists.** Every script, log, output, handoff id and CHANGELOG row named in
  the document resolves (`doc_lint.sh [5]`) and is tracked by git. ★ (the usual cause is a
  folder reorganisation: nothing errors, the pointers just stop resolving)
- **C4 Corrections replace.** No false statement is left standing with a later
  contradiction; grep the distinctive constant or phrase across the file and its siblings. ★
  (`BUGS.md` § F — a later reader may open only the earlier page)
- **C5 Conventions.** Every convention the document uses is the one pinned in
  `CLAUDE.md § Conventions`, and a quantity transported from another source's convention
  says where the translation happened. ★ (`BUGS.md` § D. The model failure: a bound imported
  from a paper with a normalisation one factor off, then inherited by every downstream
  record — nothing errors, and the number is wrong everywhere at once.)
- **C6 Absolute dates and versions.** Relative dates ("yesterday", "last session") are
  forbidden in a record; dates and script versions match `CHANGELOG.md`.
- **C7 Counts are controls.** A "12/12 checks passed" or "0 errors" line is status, never
  the evidence for a mathematical statement. ★ (`BUGS.md` § C)
- **C8 Reader can reproduce.** The intended reader — you, six months later, or a
  collaborator — can get from the displayed inputs to the displayed result without a step
  that is "easy to see".

## Workbook section — `workbook.tex`, `sections/*.tex`

Purpose: the detailed working record; you learn the topic from it, so every middle step and
every definition belongs in it. Corrections replace false text in place.

Context to read first: the `strategy-map.md` entry for the same work; the `CHANGELOG.md`
rows the section names; the script(s) it names and their logs; the master file's macro list
for notation.

Load-bearing: theorem / proposition statements; result-box contents; anything "derived
rather than cited"; the provenance of every normalisation constant or hand-assigned value;
every "conditional on …" list; the section's own summary sentence.

- **W1 Pedagogy.** Each displayed result is reachable from displayed inputs by steps the
  reader can execute; definitions precede use; no "one finds" over a nontrivial step.
- **W2 Script trace.** For each named script: it exists; the check whose body tests the
  prose's claim is identified; label matches body; the log's pass / abort / error counts
  match the prose; vacuous checks named. ★
- **W3 Typing.** Finite checks never "proved"; hand-assigned entries reported as assumed and
  downstream checks as "consistent with the assumption". ★ (`BUGS.md` § C, § I)
- **W4 In-place correction.** Earlier text in this or an earlier section does not still
  assert what this section retracts. ★ (`BUGS.md` § F)
- **W5 Drift.** Numbers and condition lists agree with the strategy map and the CHANGELOG
  row. ★
- **W6 Compile.** If labels, environments or macros changed, `/latex-compile` the master:
  zero undefined references, zero errors.
- **W7 Boxes are honest.** A box titled "proved" / "theorem" contains a proof, not a list of
  passing checks; a "claim I wrote and the script refuted" box names the refuting diagnostic.

## Big picture — `bigPicture.tex`

Purpose: 4–8 pages, equation-light, with explicit established / measured / open ledgers;
read before the workbook.

Context: `strategy-map.md`; the workbook sections it points to by title.

Load-bearing: every ledger row and its status word; the implication chain (each link, and
which links are unproved); every "what is proven" sentence.

- **B1 Ledger ↔ strategy map.** Each ledger row's status and condition list matches the
  strategy map. A big picture may lag but never lead. ★
- **B2 No promoted finite check.** "Verified up to N" stays a finite verification; the
  implication chain is never shortened. ★
- **B3 Pointers.** Quoted workbook section titles exist verbatim; named scripts resolve.
  (A plausible-but-invented section title is the classic failure here.) ★
- **B4 Equation-light.** Displayed equations are only the ones a reader needs to orient.
- **B5 Open is open, both ways.** Every open item in the strategy map appears as open here;
  nothing here is open that the strategy map has since closed (or vice versa).
- **B6 Dates.** Dates and script versions match `CHANGELOG.md`.

## Strategy map / route plan — `strategy-map.md`

Purpose: dependencies, stop rules, the current next task; the authoritative status that
outranks the task queue and chronology.

Context: the newest handoff addressed to each agent (a newer handoff may legitimately
update a status); the last `CHANGELOG.md` rows; `next-session-prompts.md`.

Load-bearing: every status cell; the override notes; "current next task"; the honesty
ledger; the list of things ruled out.

- **R1 Currency.** The statuses reflect the newest adjudicated handoff; if a handoff
  corrected a status, it is corrected *in place*, not only in a note underneath. ★
- **R2 Internal consistency.** No cell says PROVED where the note or the next-task paragraph
  says CONDITIONAL; a condition list has the same length everywhere it appears. ★ (the model
  failure: "two inputs" in one place and "three inputs" in another, for the same theorem)
- **R3 Stop rules.** Each strategy names the exact first residual that would kill it. A
  route with no stop rule cannot fail, so it can absorb unlimited time. ★ (`BUGS.md` § H)
- **R4 Next task.** Names what it advances, the simplest admissible case, a pass criterion
  and a stop criterion.
- **R5 Consistency with the standing rules.** Anything ruled out here is also ruled out in
  `CLAUDE.md` and `next-session-prompts.md`.
- **R6 Pointers.** Script names, handoff ids and CHANGELOG references resolve.
- **R7 Size.** Superseded history has moved to `CHANGELOG.md` rather than stacking inside a
  live cell.

## Handoff message — `handoff/msgs/*.md`, `handoff/archive/*.md`

Purpose: verdict + checks with non-coverage + touched files + pointers, within the `hx.sh`
line cap; never a derivation.

Context: the message it replies to (`bash handoff/hx.sh thread <slug>`); the script and log
it names; the status it claims to update.

Load-bearing: the `VERDICT:` line; the `THIS ROUND:` line; each check's scope statement; the
list of accepted corrections; the "what this does NOT establish" clause.

- **H1 Verdict split.** `VERDICT:` adjudicates only the previous exchange; the new round's
  status lives on `THIS ROUND:` with a typed status and a does-not-establish clause. An
  acceptance token carrying the new round's headline is how an unaudited claim gets
  laundered into the record. ★ (`BUGS.md` § I)
- **H2 Deliverables.** Each deliverable the previous message requested is marked DONE /
  PARTIAL / NOT RUN / DIFFERENT TASK before any new proposal.
- **H3 Checks with scope.** Every check says what it covers and does not; vacuous checks are
  called vacuous. ★ (`BUGS.md` § C)
- **H4 Corrections at the corrector's strength.** An accepted correction is not restated
  stronger than the corrector made it ("the obstruction is not where you said" is not "the
  blocker dissolves"). ★
- **H5 Evidence committed.** Scripts referenced are tracked and runnable from a clean
  checkout, relative paths only.
- **H6 Loop check.** The tuple (target, simple case, exact residual, what it would decide)
  differs from the previous round's, or the message says why not.
- **H7 Cap and form.** Within the `hx.sh` line cap; `## Claim / ## Gates / ## Touched /
  ## Needs from you` present; body written to a file and sent with `hx.sh`.

## Paper / publication — `paper.tex`, `publications/*.tex`

Purpose: finished or paper-style write-up; its claims must not exceed the strategy map's
status for the same objects.

Context: the workbook sections and strategy map it summarises; its `\bibitem`s or `.bib`.

Load-bearing: abstract, introduction and conclusion claims; each theorem with its condition
list; the main result's assumptions; every citation; the conventions section.

- **P1 Abstract ↔ body.** Every abstract / conclusion claim maps to a body statement with
  the same conditions, no stronger.
- **P2 Proofs present.** Each theorem has a proof whose steps are reversible from the stated
  inputs; "one can show" over a load-bearing step is a finding.
- **P3 Citations.** Every reference exists (`/verify-citation`) and is cited for what it
  says. ★ (a bibitem pointing at the wrong arXiv id is the classic one — the title and the
  number belong to different papers, and nothing checks that.)
- **P4 Conventions.** Stated once, used consistently; every point where the source's
  convention was translated is named. ★
- **P5 Numbers.** Every quoted constant agrees with the workbook / CHANGELOG source; quote
  both.
- **P6 Status.** No claim stronger than the strategy map's status for the same object.
- **P7 Compile.** `/latex-compile` clean, zero undefined references.
- **P8 Leakage.** Project-internal jargon (round numbers, script names, "the other agent
  accepted") does not appear unless intended.
- **P9 Markers.** No TODO / placeholder text.
- Not evaluated unless asked: novelty, priority, journal fit, any recommendation.

## Brief — `brief.tex`

Purpose: the compressed view of the workbook, kept in step by `/sync-brief`.

- **Br1** Every load-bearing workbook statement that changed since the last sync is
  reflected.
- **Br2** Nothing in the brief is absent from the workbook.
- **Br3** Same types and conditions as the workbook; a brief never promotes. The coarse
  three-way tags (ESTABLISHED / CONJECTURED / OPEN) are summaries of the eight statuses, and
  the finer status stays with the claim in the workbook.

## Primer / crash course — workbook appendices, `publications/crash-courses/`

Purpose: pedagogical; you learn the topic from it.

- **Pr1** Definitions complete and in dependency order; every symbol defined before use.
- **Pr2** Every example actually computed, not asserted.
- **Pr3** Conventions match the project's, and each place where the primer's source
  convention differs is named.
- **Pr4** No unproved statement presented as standard fact without a citation.

## `CLAUDE.md` / `AGENTS.md`, `README.md`, task queues

- **A1** Currency: `§ Current status` and `next-session-prompts.md` agree with the strategy
  map.
- **A2** Size: within the budget the file's own header states (a CLAUDE.md that grows past
  it stops being read carefully).
- **A3** Every pointer resolves.
- **A4** Instruction precedence is stated and not contradicted by a nested file.

## Not covered here

`Pipeline/*.md` code documents have their own auditor — use `/check-pipeline`, which
compares the document against the code it describes. `BUGS.md` is a checklist, not a claim
record; audit it only for A1–A3.
