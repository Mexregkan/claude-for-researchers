---
name: wolfbook
description: Playbook for the Wolfbook MCP tools — driving the LIVE Wolfram kernel and a .wb/.nb notebook in VS Code from Claude Code (read/search/edit/run cells, evaluate expressions, checkpoint/restore kernel state, step-debug, look up symbols, find paclets, search INSPIRE/arXiv papers). Use whenever working through the Wolfbook MCP (mcp__wolfbook__*) instead of headless wolframscript: pick the right tool, avoid the multi-statement reparse and runCell bridge bugs, and use kernel checkpoints for safe rollbacks. Complements the wolfram-headless skill (which covers headless .wls runs).
---

# wolfbook — driving the live Wolfram kernel + notebook via MCP

The `mcp__wolfbook__*` tools talk to a **running** Wolfram kernel inside a VS Code window, editing
and evaluating a live `.wb`/`.nb` notebook. This is the opposite end from `wolfram-headless`
(one-shot `wolframscript`): here state persists, cells have stable IDs, and you can
checkpoint/restore.

**Requires** the [Wolfbook](https://wolfbook.app/) extension with the MCP enabled
(`"wolfbook.mcpEnabled": true`); without it the `mcp__wolfbook__*` tools are not available — use
`wolfram-headless` for `.wls` runs instead. Tool schemas are deferred — fetch them with
`ToolSearch "select:mcp__wolfbook__<name>"` before first use.

## Decision: MCP live kernel vs headless wolframscript

- **Live kernel (MCP)** — interactive work on the project notebook: read/edit/run cells, probe
  state, small-to-medium evaluations, debugging, building up definitions incrementally. State is
  preserved between calls; `kernelControl` gives real checkpoint/restore.
- **Headless (`wolframscript`, see `wolfram-headless`)** — heavy batch jobs (a big symbolic solve)
  that would block or OOM the interactive kernel, or that you want to run in the background and poll
  a result file. The live kernel in VS Code *contends for the license seat* with headless jobs —
  close/idle the Wolfbook window before a long headless run, or target a worker client.
- Both report a kernel crash as **"The product exited because of a license error"** — it is almost
  never licensing (see `wolfram-headless` RULE 2). On the MCP side use `wolfbook_kernelCrashLog`
  (`source:"debug"`/`"crash"`) to get the real stack/cause.

## Tool map (right tool for the job)

**Orient before touching anything**
- `wolfbook_list_clients` — list VS Code windows, their open notebooks, primary/worker role.
  `wolfbook_setTarget {client_id, notebook}` — pin a default so you stop passing them every call
  (set it once at session start and omit `notebook` from subsequent calls).
- `wolfbook_getNotebookContext action:"read"` (or `brief:true` / `action:"summary"`) — full or
  one-line-per-cell view. **Always read first**; cell *numbers shift* after structural edits, so
  grab the stable **CellId** and use that. (Its outputs are a CACHED snapshot — see "Read kernel
  errors" below.)
- `wolfbook_searchCells {query, regex}` — locate a symbol/def/error in a long notebook without
  reading it whole; returns CellId + whether the hit was in source or output.
- `wolfbook_getKernelState {pattern}` — list defined `Global`*` symbols (values / DownValue counts)
  **before editing**, to avoid clobbering an existing definition (watch for name-collision hazards;
  record known ones in your CLAUDE.md).
- `wolfbook_getCellOutput {cellId}` — read a cell's existing (stored) output without re-running it.

**Evaluate / run**
- `wolfbook_evaluateExpression {expression, multiLine, outputForm, timeoutSeconds}` — eval WL in the
  live kernel. ⚠ **Multi-statement pitfall:** several newline-separated subexpressions WITHOUT
  semicolons are parsed as `Times[...]`, not sequential statements. Either put `;` between
  statements **or** set `multiLine:true` (each complete statement eval'd separately, `;` suppresses
  its output). This is the safe way to run multi-statement code that `runCell` would mis-split.
  `outputForm:"TeXForm"` for LaTeX, `"Short"` to preview a huge result, `"MatrixForm"`/`"TableForm"`
  for structure.
- `wolfbook_runCell {cellId | startCell,endCell}` — re-run EXISTING cell source (no `code` param).
  ⚠ It splits a cell at top-level newlines, so a single statement that spans a **soft-wrapped line**
  can be torn in two (classically: a factor silently dropped, a definition turned into a product).
  Keep cells **one physical line per statement** (the `/nb-to-wolfbook` skill enforces this); prefer
  `evaluateExpression` for anything multi-line. Range mode runs a block (`stopOnError`,
  `errorsOnly`). It re-executes and surfaces a `⚠ Kernel messages` section — read it (see below).
- `wolfbook_validateSyntax {cellId | startCell,endCell}` — kernel `SyntaxQ` (offline bracket-match
  fallback). Run on an edited cell before executing.

**Edit the notebook**
- `wolfbook_editCell` — replace cell source (single or **batch** `cells:[{cellId,content}]`; batch
  evaluates by default — catches errors immediately). Pass real newlines, not literal `\n`.
- `wolfbook_insertCells` — add code/markdown cells (single or contiguous block); evaluates by
  default. Use `afterCellId`, not a number.
- `wolfbook_deleteCell` / `wolfbook_restoreDeletedCells` — delete (logged) and undo.
  `wolfbook_moveCell` — reorder, or copy/move a cell **between** open notebooks (handy for promoting
  a `generated/` cell into the main notebook — but for `.wb`↔`.nb` mirroring use the `/sync-wb-nb`
  skill, which verifies box-equality).
- After any `.wb` edit, run `/sync-wb-nb` to mirror into the `.nb` (standing rule if you keep a
  paired `.nb`).

**Kernel lifecycle — use checkpoints instead of hand-rolled .mx**
- `wolfbook_kernelControl action:"checkpoint" tag:"..."` saves all `Global`` defs to an `.mx`;
  `action:"restore" [path]` does `ClearAll` + `Get`. This is the *live-kernel* equivalent of the
  manual `DumpSave`/`Get["/tmp/...mx"]` dance — use it for safe rollback points **before a risky
  refactor or a long rebuild**, and to recover after an abort. `action:"abort"` stops a hung
  evaluation without nuking state; `action:"restart"` is the destructive last resort. (For *headless*
  jobs there is no `kernelControl` — keep using `DumpSave`/`Put` to a file, per `wolfram-headless`.)
- `wolfbook_debugCell` — step-through debugger (analyze → start → stepOver/Into/Out → continue),
  breakpoints, watch variables, inline timings. Reach for it on a complex cell that returns garbage
  rather than peppering it with `Print`.

**Lookup / discovery**
- `wolfbook_lookupSymbol {symbol, fetchWeb}` — usage message + signature + options for a built-in OR
  user symbol; `fetchWeb:true` pulls the full reference page (use for e.g. `NDSolve` Method details).
- `wolfbook_findPackage {query}` — search Paclet Server + GitHub; returns the exact
  `PacletInstall[...]` command (then run it via `evaluateExpression` with `timeoutSeconds>=120` — do
  not guess install syntax).
- `wolfbook_paperSearch` — INSPIRE-HEP (arXiv fallback): `search` (title/author/abstract/ID),
  `bibtex`, `bibitem`, `references`, `citations`. For HEP/physics work INSPIRE is the canonical
  source, so this is a good **citation-verification** path and gives ready `\bibitem`/BibTeX (pair
  with `/verify-citation`).
- `wolfbook_fileOps` (read/write/list) and `wolfbook_runTerminal` — file + shell on the notebook's
  machine. From Claude Code you usually already have Bash/Read/Write; these matter when targeting a
  *remote* client. `wolfbook_latex` (latexmk build) exists, but for `.tex` prefer the
  `/latex-compile` skill — it forces a real `pdflatex` pass and reads warnings from stdout, dodging
  latexmk's stale-log trap.

## Common gotchas
- `NotebookDirectory[]` fails under Wolfbook/headless — use an explicit absolute path.
- Greek literals are fine in the **live** kernel/notebook but corrupt in headless `.wls`
  (`wolfram-headless` RULE 1) — don't copy notebook Greek into a `.wls` without escaping.
- Add project-specific gotchas (known symbol collisions, required sanity checks before trusting
  numbers, memory references for recurring bugs) to your project's CLAUDE.md. Claude reads them
  at session start and applies them throughout.

## Read kernel errors — they are signal, not noise
A human running cells interactively fixes an undefined-symbol error the instant they see it. Do the
same — one undefined symbol silently invalidates everything downstream. (Full write-up:
`docs/wolfbook-kernel-errors.md`.)
- **Treat these as STOP-AND-FIX** (an undefined symbol / cell-order forward-reference / typo, NOT a
  benign warning): `ReplaceAll::reps` ("X is neither a list of replacement rules") — a stray `/.`
  then poisons the symbol and propagates downstream; `Set::shape`; `Part::partd`;
  `Set::write`/`Protected`; any "not defined". Forward-references (a symbol defined LATER than the
  cell that uses it) are normal in working notebooks — one top-to-bottom pass breaks it; fix = define
  it first, then re-run the dependent cell (a 2nd pass).
- **`runCell` surfaces messages; `getNotebookContext` is a cached snapshot.** (Verified against the
  v2.7.14 source.) `runCell` re-executes and prints a dedicated `⚠ Kernel messages` section (with a
  `Syntax::` flag) — READ and act on it, don't judge from the result line. `getNotebookContext`
  re-shows each cell's STORED output and does NOT re-evaluate, so never read its outputs as a fresh
  result. **Confirm state by EVALUATING:** `Head[sym]`, `ValueQ[sym]`, `FreeQ[sym, ReplaceAll]` —
  pick a check that survives evaluation (`FreeQ[_,ReplaceAll]`, `Head===Plus`); `FreeQ[_,foo]` is
  bogus because `foo[]` evaluates away.
- **Sanity-sweep after any multi-cell setup, before trusting a build:**
  `Select[{<your key symbols>}, ! FreeQ[#, ReplaceAll] &]` must be `{}`, and
  `ValueQ /@ {<your data lists>}` all `True`.

## Quick start
1. `wolfbook_list_clients` → `wolfbook_setTarget` your project notebook.
2. `wolfbook_getNotebookContext brief:true` to map cells; `searchCells` to find the target; grab CellIds.
3. `getKernelState` before editing; `kernelControl checkpoint` before anything risky.
4. Edit with `editCell`/`insertCells`; `validateSyntax`; run with `evaluateExpression`
   (`multiLine` for multi-statement) or `runCell`.
5. `/sync-wb-nb` to mirror `.wb`→`.nb` (if paired); checkpoint the good state.
