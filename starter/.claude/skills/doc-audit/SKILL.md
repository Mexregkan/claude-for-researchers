---
name: doc-audit
description: Evaluate one project document in detail — a workbook section, big picture, strategy map, handoff message, paper, brief, or primer — without editing it. Runs the mechanical lint, builds a claim ledger, types every headline against the eight claim statuses in CLAUDE.md, traces cited evidence to the scripts and logs that exist, detects drift against the strategy map / CHANGELOG / newest handoff, sends the load-bearing claims to a fresh-context reader, and writes a report under audits/. Use when asked to audit, evaluate, review, check, or proofread a .tex or .md document. Not a referee report — no recommendation, no author, no edits.
---

# doc-audit — a hostile, evidence-bound read of one document

## Why this exists

Every record in a research project — workbook section, strategy-map cell, big picture,
handoff message, paper — is written in the same pass, from the same context, as the claims
it records. Nobody reads it adversarially before it is relied on: the next session, the
other agent and your collaborator all read it as true. `claim-audit` guards the moment a
*computation* becomes prose. This skill treats the **document as the object**: is what it
says supported, typed, current, complete enough to learn from, and pointing at evidence
that still exists?

Everything editorial is deliberately removed. There is no recommendation to an editor and
no author to address. The product is an evaluation *you* read, then decide what to change.

## Usage

```
/doc-audit <path>                              # standard depth
/doc-audit <path> --depth quick                # lint + headline ledger + drift; no verification
/doc-audit <path> --depth full                 # every row verified; all load-bearing rows to a fresh reader; citations verified
/doc-audit <path> --section "<\label or heading>"   # one section of a large document
/doc-audit <path> --against <other-doc>        # add an explicit drift target
/doc-audit <path> --recompute                  # allow re-running cited scripts (default: read existing logs only)
```

Typical targets: `workbook.tex` (or one of its `sections/*.tex`), `bigPicture.tex`,
`strategy-map.md`, `brief.tex`, `handoff/msgs/*.md`, a paper draft, a crash-course
appendix, `CLAUDE.md`. The rubric for each type is in [`rubrics.md`](rubrics.md); the
report shape is [`report-template.md`](report-template.md).

## Hard rules

1. **Never edit the document under audit**, its siblings, or any research record during the
   audit. Proposed corrections go in the report as quoted before/after text. The user
   applies them, or asks for that in a separate turn.
2. **A verdict without evidence is not a verdict.** Every ledger row carries a location
   (`file:line` or `\label`), what was read or run, and what the check does **not** cover.
3. **No manufactured dissent.** A finding must be stateable as *input → step → corrected
   statement*. If the corrected statement cannot be written, it is a `QUESTION`, labelled
   as such — never dressed as an error.
4. **Agreement is a result.** `SUPPORTED` needs the same evidence as `OVERCLAIMED`. "Looks
   right" is not evidence, and neither is "the strategy map says so": the strategy map is a
   co-claim written by the same process, and drift between records is itself a finding.
5. **Do not launch long computations** unless `--recompute` was given. Evidence tracing
   reads scripts, logs and outputs that already exist.
6. **Cover the answer while you derive.** For any row you re-derive, read only the inputs,
   write your value down, then compare. If the document's answer went past your eyes first,
   write *contaminated* in the row.
7. **Never claim anything was recorded unless the file was written in the same turn.**

## Steps

### 0 — Type the document, load its rubric, fix its state

- Detect the type (the lint prints it in `[0]`), then read that block of `rubrics.md`.
- Read the *authoritative context* the rubric names: for a workbook section, the
  `strategy-map.md` entry and the `CHANGELOG.md` rows it cites; for a handoff, the message
  it replies to (`bash handoff/hx.sh thread <slug>`); for a big picture, the strategy map;
  for a paper, the workbook sections it summarises.
- Record the document's git state: `git log -1 --format='%h %ad' --date=short -- <file>`
  and whether it has uncommitted changes. The report audits *that* version.

### 1 — Mechanical pre-filter

```bash
bash .claude/skills/doc-audit/doc_lint.sh <file>        # LINTMAX=80 to list more lines
```

Read `[0]` before anything else: exit 3 is a vacuous run and is not evidence about the
document. Then **read every flagged line**; a regex hit becomes a finding only after
reading confirms it. Section `[5]` (pointers that do not resolve) is the one to trust most
literally — after a folder reorganisation it is the only cheap way to see which evidence a
document can no longer reach. After any edit to `doc_lint.sh`:

```bash
bash .claude/skills/doc-audit/selftest.sh                 # must print 0 failed
```

### 2 — Sweep into a claim ledger (no verdicts yet)

For a document over ~400 lines, or a whole workbook, fan out the read-only `doc-sweeper`
agent **in parallel, one per `\section` / `##` heading**, then merge the rows. Otherwise
sweep yourself. Hand each sweeper the **label universe** — the master's `\input` closure,
which the lint prints in `[0]` — or it will report labels defined in a sibling file as
missing. Sweep kinds in this order, because the first ones are where the value is:

1. headline and status statements (box titles, bold status words, "closes", "proved");
2. typed statements (theorem / proposition / lemma / conjecture environments and boxes);
3. imported inputs ("frozen", "imported", "assume", "conditional on", hand-assigned values);
4. every pointer to a script, log, data file, handoff id or CHANGELOG row;
5. every number quoted as a result (coefficient, order, count, bound);
6. definitions and conventions used (the ones pinned in `CLAUDE.md § Conventions`);
7. cross-record statements ("the strategy map says", "CHANGELOG row", "the other agent accepted");
8. citations;
9. pedagogical gaps — a step the intended reader cannot reproduce from what is written.

Row schema (one line per row, verbatim quote kept short):

| id | where | claim, phrased so it could be false | type as written | load | proposed check |
|---|---|---|---|---|---|

`load` is `LOAD-BEARING` (a strategy-map cell, a later section, or a paper depends on it),
`SUPPORTING`, or `PRESENTATION`. `type as written` is one of the eight statuses from
`CLAUDE.md § Research-claim discipline` — definition, exact identity, proved theorem,
conditional theorem, conjecture, finite verification, numerical evidence, obstruction — or
`UNTYPED`.

### 3 — Verify: load-bearing rows at standard depth, every row at full

Choose an evidence class per row and record it:

- **TRACE** — the cited script / log / output exists and is tracked; the check whose body
  tests the claim is identified; its label says what the document says it says; the log's
  pass / abort / error counts match the prose; the checks *bear on* the claim (`claim-audit`
  ledger columns 1–2: object literally constructed, restriction actually established).
  Vacuous checks are named with the word *vacuous*.
- **DERIVE** — blind re-derivation of a cheap step (rule 6). Not a long job.
- **DRIFT** — the same statement in `strategy-map.md`, `CHANGELOG.md`, `bigPicture.tex`,
  `brief.tex`, `CLAUDE.md § Current status`, the newest handoff, `BUGS.md`: same strength,
  same list of conditions, same numbers? Quote both sides. Decide which is right only when
  evidence does; otherwise report the disagreement as the finding.
- **TYPE** — the type as written versus the type the evidence supports, with the **weakest
  supported statement written out in full**. A finite check is never a proved theorem; a
  hand-assigned value is an assumption; an accepted correction is restated at the
  corrector's strength, never stronger.
- **CITE** — `/verify-citation` for every external reference the document introduces or
  that looks off; and check it is cited *for what it actually says*.
- **CONVENTION** — against `CLAUDE.md § Conventions`. Any quantity transported from another
  source's convention must say where the translation happened.

Verdict vocabulary: `SUPPORTED` · `OVERCLAIMED` (+ weakest supported statement) ·
`UNSUPPORTED` (no evidence reachable from the document) · `CONTRADICTED` (+ by what, quoted) ·
`STALE` (evidence moved, superseded, or retracted elsewhere) · `UNVERIFIABLE` · `QUESTION` ·
`N-A`. Each verdict has a witness count; it is 1 until step 4.

### 4 — Fresh-context read

Spawn the read-only `doc-auditor` agent on the top load-bearing rows (3 at standard depth,
all at full), in parallel. Give it **only** the bare claim, `file:lines`, the path to the
definitions or conventions it needs, and the evidence paths. Do **not** give it your
verdict, your ledger or the session narrative — those are what the fresh read is testing
around.

Two rules that come from getting this wrong:

- **Quote the document, never a sibling record.** If you hand the reader the strategy map's
  paraphrase of the claim, it audits a sentence the document does not contain and its
  verdict is worthless.
- **If a fresh read is lost** — a rate limit, an interrupted run — rerun it. Do not silently
  downgrade to a single witness; if you cannot rerun, say so in § 7 of the report.

Record its verdict as a second witness column. Disagreement is the payoff: report both
readings and the single check that would decide. Never average.

### 5 — Rubric pass

Walk the type's checklist in `rubrics.md`. Each item is `PASS` / `FAIL` with a location /
`N-A`. This is where pedagogy (workbooks, primers), ledger consistency (big pictures),
status currency (strategy maps), the verdict split (handoffs) and abstract-versus-body
(papers) get judged.

### 6 — Write the report

`audits/YYYY-MM-DD-<doc-slug>.md`, from `report-template.md`, in that order of sections:
header · summary verdict (typed, ≤ 5 lines) · findings ranked `BLOCKING` / `MAJOR` /
`MINOR` / `QUESTION`, each with where, verbatim quote, problem, evidence, consequence,
proposed replacement text, witnesses · drift table · ledger · rubric · fresh-context
reads verbatim · **what was not checked** · next. If an earlier audit of the same document
exists, link it and say what changed since.

### 7 — Report in chat

Verdict and scope first, the top findings, the report path, what was not checked. Do not
describe the report as "written" unless step 6 wrote it.

## Forbidden

- A verdict before its ledger row exists; a lint hit counted as a finding without reading.
- "N/N checks passed" or "0 errors" offered as the reason a statement is true.
- Treating the strategy map, `CHANGELOG.md`, a handoff or `CLAUDE.md` as ground truth for
  the document; they are co-claims, and their disagreement is a finding.
- Editing the document, or any record, so that the audit passes.
- Refereeing language: publish / reject / novelty / priority, unless the user asks for it.
- Launching a long computation without `--recompute`.

## The report is an evaluation, not a verdict on the document

An audit report is itself a document written in one pass, and it overclaims the same way
everything else does. In the first real run of this workflow the user had the audit audited:
of fifteen findings, twelve were accepted as written and **three had their strongest wording
rejected** — a count was one off, a "the proof survives only in an old commit" claim was
wrong because the proof scripts were still on disk, and a terminology correction was right
but omitted the exceptions. Every one of the three was accepted *in substance*. That is the
expected shape, and it is why the report proposes replacement text instead of applying it.

## Related

`claim-audit` (computation → prose; this skill audits the prose that resulted),
`simple-case-gate`, `reality-check`, `cross-validate`, `verify-citation`, `latex-compile`
(a clean compile is a rubric item for workbooks and papers), `sync-brief`.
Agents: `.claude/agents/doc-sweeper.md`, `.claude/agents/doc-auditor.md`.
