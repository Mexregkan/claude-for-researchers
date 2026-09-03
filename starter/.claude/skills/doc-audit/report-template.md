# Document audit — `<path>`

| field | value |
|---|---|
| document | `<path>` — type: `<workbook-section / workbook-master / big-picture / strategy-map / handoff / paper / brief / primer / other>` |
| audited | `<YYYY-MM-DD>`; document at commit `<hash> <date>`; working tree: `clean` / `uncommitted changes present` |
| depth | `quick` / `standard` / `full`; `--section <…>`; `--recompute` yes / no; `--against <…>` |
| auditor | `<agent + model>`, main session; fresh-context reads by `doc-auditor` × `<n>`; sweeps by `doc-sweeper` × `<n>` |
| previous audit | `audits/<…>.md` — what changed since / none |
| lint | `<the === SUMMARY line of doc_lint.sh, verbatim>` |
| compile | `<for .tex: passes, errors, undefined refs, over/underfull boxes, pages — or N-A>` |

## 1. Summary verdict

<≤ 5 lines. Each headline claim of the document: the type it is written as → the type the
evidence supports. Then one sentence: what a reader may rely on, and what they must not.
No adjectives.>

## 2. Findings, ranked

### F1 — [BLOCKING | MAJOR | MINOR | QUESTION] <one-line title>

- **Where:** `<file:line>` / `\label{<…>}`
- **Says:** "<verbatim quote>"
- **Problem:** <input → step → what is wrong>
- **Evidence:** <what was read or run; paths; and what this evidence does NOT cover>
- **Consequence:** <which downstream statement changes; "none, cosmetic" if so>
- **Proposed replacement:** "<text>" — not applied
- **Witnesses:** main session / `doc-auditor` agree | disagree — deciding check: <…>

### F2 — …

## 3. Drift table

| statement | this document | strategy map | `CHANGELOG.md` | big picture / newest handoff | agree? |
|---|---|---|---|---|---|
| <object> | "<quote>" | "<quote>" | "<quote>" | "<quote>" | yes / NO — <which is right, if evidence decides> |

## 4. Claim ledger

| id | where | claim (phrased so it could be false) | type as written | type supported | load | evidence class | verdict | witnesses | not covered |
|---|---|---|---|---|---|---|---|---|---|
| D01 | `<file:line>` | <…> | <one of the eight / UNTYPED> | <one of the eight> | LOAD-BEARING / SUPPORTING / PRESENTATION | TRACE / DERIVE / DRIFT / TYPE / CITE / CONVENTION | SUPPORTED / OVERCLAIMED / UNSUPPORTED / CONTRADICTED / STALE / UNVERIFIABLE / QUESTION / N-A | 1 / 2 | <scope> |

## 5. Rubric — `<type>`

| item | result | where / note |
|---|---|---|
| C1 typed headlines | PASS / FAIL / N-A | <…> |
| … | | |

## 6. Fresh-context reads

<For each `doc-auditor` run: the claim id, then its `WEAKEST SUPPORTED STATEMENT`, `VERDICT`
and `BREAKS` lines verbatim. Disagreements with the main session are listed, not resolved,
unless evidence decides. A read that was lost and could not be rerun is named here as a
single-witness row, not omitted.>

## 7. Not checked

<Explicit: rows left UNCHECKED and why; scripts not re-run; citations not verified;
sections not swept; anything that needed `--recompute` or `--depth full`. This section is
the honest half of the report — an audit with a short "not checked" list is usually an
audit that did not look.>

## 8. Next

<One line per open row: the single check that would settle it. No edits were made to the
document or to any record during this audit.>

## Audit-tooling notes

<Anything the lint, the sweepers or the fresh readers got wrong during this run — a false
positive worth a regex guard, a missing input in an agent prompt. Fix it in the skill and
add a `selftest.sh` case; this section is where the next fix comes from.>
