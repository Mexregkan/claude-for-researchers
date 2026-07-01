---
name: check-pipeline
description: Check that a code and its Pipeline/ .md are still compatible — that every symbol, cell number, data file, and data-flow claim in the pipeline doc still matches the current code (drift detection). Use after editing a documented notebook/engine/script, before trusting a pipeline doc, or on request ("does the pipeline still match the code?"). Reports mismatches (missing symbols, wrong cell numbers, renamed functions, changed I/O) and can update the doc. Companion to /write-pipeline.
---

# /check-pipeline — verify a code matches its pipeline doc

Pipeline docs drift when the code changes: a function gets renamed, a cell is inserted (shifting all
later cell numbers), a data file is dropped, an I/O contract changes. This skill compares a
`Pipeline/*.md` against the current source and reports every mismatch, so the map stays trustworthy.

## When to use
- Right after editing a documented code.
- Before relying on a pipeline doc you didn't just write.
- On request: "is the pipeline still accurate?", "check the codes match the pipelines".
- Across the board (no argument): check every `Pipeline/*.md` against its code.

## Method

**1. Pair each pipeline doc with its code.** The doc's header names it ("Code: path/to/<file>").
Read the header, or scan the folder if checking everything.

**2. Dump the code** to readable text (same helper the writer uses):
```bash
python3 .claude/skills/write-pipeline/dump_code.py "$SCRATCH" "path/to/<file>"
```

**3. Extract the doc's checkable claims and verify each against the dump:**
- **Symbols** (every name in the "Key symbols" table and in prose code-spans): does it still appear
  in the code? `grep -F 'symbolName'` the `.full.txt` (or source). Flag any that are **absent**
  (renamed/removed) — the highest-value drift signal.
- **Cell numbers**: for each `| Symbol | Cell N |` row, confirm the symbol's definition is at/near
  cell N in `<base>.outline.txt` (±2 tolerates minor insertions; larger shifts = flag "cell numbers
  stale, N inserted/removed above"). If many rows are off by a constant, an insert/delete happened —
  report the offset and the pivot cell.
- **Data files**: every input/output file the doc says is loaded/written — does the code still
  read/write it, and does the file exist on disk (`ls`)?
- **Upstream/downstream links**: the "Inputs/outputs" section names producers/consumers — spot-check
  those still hold (e.g. the doc says stage B consumes symbol `X` from stage A; grep that `X` is
  still built the way the doc claims).
- **Copied-layer coupling**: if the doc says "this section is copied verbatim from `<other code>`",
  diff the copied definitions against the source — silent divergence there is a real correctness
  risk, not just doc drift.

**4. Report.** Produce a compact verdict per doc:
```
Pipeline/<doc>.md  vs  <code>
  OK: 24/27 symbols present, cell numbers within ±1, all data files load.
  DRIFT:
    - symbol `oldName` (row "…", cell 42) NOT FOUND — renamed to `newName`?
    - cell numbers off by +3 from cell 130 onward (3 cells inserted at ~128).
    - doc says it writes results.csv — no such write in code, file absent.
```
Classify each finding: **BROKEN** (symbol/file gone, math claim contradicted) vs **STALE** (cell
numbers shifted, wording outdated but still correct). Do not rewrite the code to match the doc — the
**code is ground truth**; the doc follows it.

**5. Offer to fix the doc.** If the user approves (or asked for `--fix`), update the pipeline `.md`
in place: correct cell numbers, rename symbols, fix I/O. For a large rewrite, hand off to
`/write-pipeline`. Never "fix" by editing the code.

## Guardrails
- The **code is authoritative**; a mismatch means the *doc* is wrong — UNLESS the code change was
  itself a mistake. If a documented guardrail was silently removed from the code, flag it as a
  possible regression rather than quietly updating the doc to match.
- A doc citing a symbol that no longer exists is worse than a stale cell number — rank BROKEN first.
- Cell-number drift is expected and cheap to fix; don't over-alarm on ±1–2.
- Report; only edit the doc with approval or an explicit `--fix`.
