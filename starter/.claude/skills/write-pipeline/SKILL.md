---
name: write-pipeline
description: Write (or refresh) a Pipeline/ .md that documents the calculation-and-code pipeline of ANY large code in the project — a notebook (.wb/.nb/.ipynb), an engine, or a script. Use when a load-bearing code has no pipeline doc yet, when a new main code is added, or when the user asks to "write the pipeline" for a file. Produces the standard Purpose / data-flow diagram / key-symbols table / gotchas / inputs-outputs format used across Pipeline/, cross-referenced to the project's authoritative notes (workbook.tex).
---

# /write-pipeline — document the pipeline of any code

The `Pipeline/` folder holds one `.md` per main code describing **what it computes and how the code
flows**, so future sessions read the map before the (large) source. This skill writes or refreshes
one of those files for a target code. Read `Pipeline/README.md` first — match its house style.

**When is a code "main" enough to document?** When it has grown too big to hold in context or read
top-to-bottom — the file you dread opening. A 40-line script does not need this; a 300-cell
notebook or a multi-pass engine does. That growing-too-big moment is the trigger to run this skill.

## When to use
- A load-bearing code has no `Pipeline/*.md` yet (a notebook/engine/script has crossed the "too big
  to hold in context" threshold, or a new main code was added).
- An existing pipeline doc is stale (use `/check-pipeline` to detect drift, then this to rewrite).
- The user points at a file and says "write its pipeline".

## Method (do these in order)

**1. Make the code readable.** Notebooks are JSON — dump them:
```bash
python3 .claude/skills/write-pipeline/dump_code.py \
    "$SCRATCH" "path/to/<target>.wb"      # .wb/.ipynb → outline+full; .m/.wls/.py printed as-is
```
`$SCRATCH` = the session scratchpad. For a notebook this writes `<base>.outline.txt` (one line per
cell) and `<base>.full.txt`. **Read the outline first**, then read the full dump for the cells that
matter. In a `.wb` cell, kind: 1=markdown, 2=code; the source key is `value`, language in
`languageId` (an `.ipynb` uses `source`). Plain source files (`.m`/`.wls`/`.py`/…) are read directly.

**2. Learn the math/intent from your authoritative notes.** Every pipeline file cites the
`workbook.tex` sections (or paper equations) it implements — the notes are the authority for *why*,
the code for *how*. Grep the workbook for the section documenting this code
(`grep -n -E '\\(sub)?section' workbook.tex`) and read it. Also skim `brief.tex` and the
`CLAUDE.md` conventions/status.

**3. Trace the data flow.** Identify: inputs (data files loaded, upstream codes), the ordered
transformation steps (which function feeds which), and outputs (files written, symbols exported,
downstream consumers). This is the spine of the doc — get the arrows right.

**4. Write `Pipeline/<name>.md`** (or, for a big multi-stage code, a nested folder
`Pipeline/<name>/` with a `README.md` index + one file per stage — do this when a single flow is too
large for one file). Use this skeleton:

```markdown
# `<code>` — one-line role

- Code: path/to/<file> (+ any mirror). Dev/driver scripts: …
- Notes: §… (labels …) in workbook.tex / the paper. Produces / consumes: …

## Purpose
2–4 sentences: what it computes and why it exists in the project.

## Pipeline
​```
   input ──step──► intermediate ──step──► output      (ASCII data-flow; the load-bearing part)
​```

## Key symbols (cell → role)
| Symbol | Cell | Role |    ← for notebooks, cite the cell index; for scripts, the function/line
|---|---|---|

## Gotchas / guardrails
Bullet the non-obvious traps, each pointing at the authority (a workbook label, a memory slug, a
paper equation) rather than re-deriving it.

## Inputs / outputs
- In: … (files, upstream codes)   ·   Out: … (files, symbols, downstream consumers)
```

## House rules (match the rest of `Pipeline/`)
- **Plain-Unicode math** (α, ε₀, ω, τ, ⇒, →, ½). No LaTeX — that lives only in `.tex`.
- Use markdown links `[text](path)` for file references, relative to the repo root.
- Cite `workbook.tex` labels / paper equations and `CLAUDE.md` memory slugs rather than
  re-deriving; the pipeline is a **map**, not a re-derivation. Keep it dense and skimmable (tables +
  one data-flow diagram).
- For notebooks, cell numbers are the **0-based cell index** (and, if you keep a `.wb`/`.nb` pair,
  the two mirror each other).
- Do NOT paste large blocks of code or generated numeric output into the doc — name and point. They
  rot; the code is the source of truth.
- If the code is a self-contained *copy* of another code's layer (e.g. a satellite notebook that
  copies the main notebook's algebra), say so and name the source — that coupling is what
  `/check-pipeline` watches for silent divergence.

## After writing
- Add a row to the table in `Pipeline/README.md` (and, for a nested stage, the folder's `README.md`).
- Mention the new file to the user; suggest running `/check-pipeline <file>` to confirm it matches,
  and a `pipeline-auditor` pass to hunt for bugs/optimizations before you rely on it.
