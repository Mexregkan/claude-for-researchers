# audits/ — document evaluation reports

One file per run of the `/doc-audit` skill: a detailed, evidence-bound evaluation of one
project document — a workbook section, a big picture, a strategy map, a handoff message, a
paper, a brief, a primer or `CLAUDE.md`. Not referee reports: no recommendation, no author,
no edits to the document.

- **Name:** `YYYY-MM-DD-<doc-slug>.md`, e.g. `2026-09-03-workbook-sec-12-residues.md`.
  A re-audit of the same document gets a new dated file that links the previous one.
- **Shape:** `.claude/skills/doc-audit/report-template.md` — summary verdict, ranked
  findings with verbatim quotes and proposed replacement text, drift table, claim ledger,
  rubric, fresh-context reads, **what was not checked**.
- **Status:** an audit report is an *evaluation*, never canonical truth. It is written in
  one pass, from one context, like everything else — so it overclaims like everything else.
  Corrections it proposes are applied to the source record by your decision, in a separate
  turn, and the same correction then updates the strategy map, the task queue and
  `CHANGELOG.md` in that turn.
- **Tooling:** `bash .claude/skills/doc-audit/doc_lint.sh <file>` is the mechanical
  pre-filter; `bash .claude/skills/doc-audit/selftest.sh` is its regression suite. The
  read-only agents `doc-sweeper` and `doc-auditor` live in `.claude/agents/`.

Reports are not part of the research record: they do not go in the workbook, they are not
mirrored to a collaborator's repository, and nothing downstream may cite one as evidence.
Cite what the audit *checked*, not the audit.
