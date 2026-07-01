# Pipeline — how the codes fit together

This folder documents **the pipeline of every main code** in the project: what each
notebook / script consumes, the sequence of transformations it applies, and what it
produces. Read the relevant pipeline file here **before** opening the code itself — the
main codes are large and multi-pass, and these files are the map.

> **When to add a pipeline doc.** Only for a *load-bearing* code that has grown too big
> to hold in context or read top-to-bottom — the file you dread opening. A short script
> does not need one. When a code crosses that threshold, run `/write-pipeline <file>` and
> add a row to the table below. (Delete this whole `Pipeline/` folder if the project has
> no such codes.)

For the *why* behind every step, the authority is your working notes (`workbook.tex`; grep
its `\label`s — each pipeline file cites the sections it implements) and `brief.tex` (short
reference). `CLAUDE.md` holds the conventions and the running status.

---

## The codes and their pipeline files

<!-- Add one row per main code as you write its pipeline. -->

| Code | Role | Pipeline file |
|---|---|---|
| _e.g._ `numerics/main.wb` | one-line role | [`main/`](main/README.md) (nested if large) |
| _e.g._ `numerics/engine.m` | one-line role | [`engine.md`](engine.md) |

---

## House rules (match these across every pipeline file)

- **Plain-Unicode math** (α, ε₀, ω, τ, ⇒, →, ½). No LaTeX — that lives only in `.tex`.
- Markdown links `[text](path)` for file references, relative to the repo root.
- **Point, don't paste.** Cite `workbook.tex` labels / paper equations and `CLAUDE.md`
  memory slugs; never paste large code blocks or generated numeric output — they rot.
- **The code is ground truth.** A pipeline file is a *map of intent*; when it and the code
  disagree, the doc is (usually) what's wrong — fix it with `/check-pipeline`.
- For notebooks, cell numbers are the **0-based cell index**; keep any `.wb`/`.nb` mirror
  in sync.
