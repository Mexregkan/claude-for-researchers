# [Project Name] — research changelog (detailed status log)

<!--
WHAT THIS IS
  The dated, per-result log of the project: what landed, when, where it is written
  up, which script produced it, which data file holds the output, and what is still
  open. It is the project's long-term memory of RESULTS — the counterpart to
  next-session-prompts.md, which is the memory of SESSIONS.

WHY IT IS SEPARATE FROM CLAUDE.md
  CLAUDE.md is re-read at the start of every session, so every line in it is a
  recurring cost. A dated log of everything you have ever done does not belong
  there. CLAUDE.md keeps a lean "## Current status" SNAPSHOT — per branch, the
  headline DONE results and the current OPEN frontier, no dates. The exhaustive
  detail lives here and is read ON DEMAND.
    Rule of thumb: if a status line has a date in it, it belongs in this file.

WHY IT EARNS ITS KEEP EVEN THOUGH IT IS NEVER LOADED INTO CONTEXT
  This file is an INDEX into the project. One grep — for a symbol, a method, a
  script, a file name — returns the section label, the script, and the data file
  for every result that touched it. That is a few hundred tokens instead of
  loading a 100-page workbook, and it is the difference between "we did this in
  March, here is the script" and quietly redoing it.
    So write rows so that grep works: put the searchable names IN the row.

WHEN TO START ONE
  Not on day one. Start it when the DONE log in next-session-prompts.md, or the
  status section of CLAUDE.md, has grown past a screenful or two — and start it by
  MOVING that content here, not by opening an empty file. Until then the DONE log
  is enough.

HOW TO KEEP IT
  - One row per result. Append; do not rewrite history.
  - Record FALSIFIED and ABANDONED attempts too, with the reason. These are the
    highest-value rows in the file: they are what stops you, a collaborator, or
    Claude from re-running a route that has already been ruled out.
  - When a branch's DONE/OPEN *frontier* moves, refresh the snapshot in CLAUDE.md.
    That two-way rule is what keeps the snapshot and this file from diverging.
  - Group by theme; chronological within a theme.
  - Re-condense periodically. The snapshot in CLAUDE.md re-bloats: dated entries
    creep back in. When they do, move them here.
-->

**Conventions** — for you and for Claude:

- One row per result. **Append**, never rewrite. Group by theme, chronological within a theme.
- Every row carries, at minimum:
  **date** · **where it is written up** (`workbook.tex` § label) · **the script that
  produced it** · **the data file that holds the output** · **the honest residue**
  (what this did *not* settle).
- Status vocabulary: `DONE` · `IN PROGRESS` · `OPEN` · `FALSIFIED` · `SUPERSEDED` · `MOVED OUT`.
- Close each substantial row with **Docs synced:** — which other documents were
  updated (brief.tex, bigPicture.tex, the strategy map, the CLAUDE.md snapshot).
  If that line is missing, the doc set has probably drifted.
- When a branch's DONE/OPEN frontier moves, refresh `CLAUDE.md` § Current status.

---

## [Branch / theme A]

| Item | Status |
|------|--------|
| [Result in a few words — the claim, not the activity] | **DONE** (YYYY-MM-DD, `workbook.tex` §sec:label, compiles clean N pp; script `numerics/script_name.py` (+ log); data `data/output.json`). [What was actually established, stated precisely enough to be checkable — the formula, the bound, the digits of agreement, the range of parameters covered.] **Method:** [one line — how, so it can be repeated]. **Honest residue:** [what is still assumed, unchecked, or only verified in a special case]. Docs synced: brief.tex §[label], CLAUDE.md snapshot. |
| [A route that did not work] | **FALSIFIED** (YYYY-MM-DD, script `numerics/other_script.py`, notes in `workbook.tex` §sec:label). [What was tried and the concrete way it failed — the counterexample, the order at which it broke, the digits that disagreed.] **Why it matters:** [what this rules out, so the route is not re-attempted]. **What survives:** [the weaker statement that is still viable, if any]. |
| [A result later replaced] | **SUPERSEDED** (YYYY-MM-DD by the row above; original derivation kept in `workbook.tex` §sec:oldlabel). [One line: what was wrong or incomplete about it.] |
| [The current frontier of this branch] | **OPEN** — [what is missing, and the most promising next move; point at the strategy map if there is one]. |

---

## [Branch / theme B]

| Item | Status |
|------|--------|
| [...] | **IN PROGRESS** (started YYYY-MM-DD, `workbook.tex` §sec:label). [What exists so far; what the next step is]. |
| [...] | **MOVED OUT** (YYYY-MM-DD) — [this work now lives in another project/repo; where, and why]. |

<!--
A worked row, for shape (yours will be in your own notation):

| Interior residue formula R_sigma | **DONE** (2026-06-04, workbook.tex §sec:numStrategy:ansatzCheck; script
  numerics/residue_general.py; data numerics/out/residues_n1.json). Formula validated at three
  integer tuples (4,2,2,2), (5,2,2,3), (6,2,2,4) — ratio (numerical residue)/(formula) = 1.0003,
  well inside the 0.1% target. **Method:** direct contour extraction at 60-digit precision,
  cross-checked against the symmetry prediction. **Honest residue:** only the n_-=1 representative
  is checked directly; the other 15 hyperplanes are claimed by symmetry, not verified.
  Docs synced: brief.tex §residues, CLAUDE.md snapshot. |

Note what the row makes greppable: the symbol, the script, the data file, the section label,
AND the limitation. A future session that greps "residue" gets all five in one line.
-->
