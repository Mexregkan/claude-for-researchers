# Changelog

Notable, user-facing changes to this toolkit. This is a curated list of the
updates worth knowing about — not every commit (see the git history for that).
Useful for deciding whether to re-copy anything from `starter/` into a project
you set up from an earlier version.

Versioning is primarily calendar-based (`vYYYY.MM`): this is a guide and a copy-in
starter pack, not a linked library, so there is no API to break — the calendar tag
answers "how current is my copy?". Alongside it each release also carries a semantic
version (`MAJOR.MINOR.PATCH`): **PATCH** for a fix or clarification, **MINOR** for a new
skill/tool/guide section, **MAJOR** only if an update would break an existing setup (force
a re-copy to keep working). So the SemVer answers the other question — "how much changed,
and did anything break?" Nothing has forced a major bump yet, so we are still on `1.x`.

## v2026.07 · v1.7.0 — 2026-07-22 (update)

### Added
- **The research changelog — a per-result log, and a template for it.** The previous release
  said the dated log should live outside `CLAUDE.md`, and left it there. This one says what
  that file actually looks like, because the format turns out to matter. A **research
  changelog** (`CHANGELOG.md` at your project root — not a software release log) is a table
  with **one row per result**, grouped by branch, where every row carries the same five things:
  the **date**, the **`workbook.tex` section label** where it is written up, the **script**
  that produced it, the **data file** holding the output, and the **honest residue** — what the
  result did *not* settle. Substantial rows close with a `Docs synced:` line naming the other
  documents you updated, which is how you notice the doc set drifting.

  Two points the guide now makes explicitly. **`FALSIFIED` rows are the most valuable rows in
  the file** — the route that broke at order four, recorded with *how* it broke, is what stops
  you or Claude from re-running it six weeks later. And the file **earns its keep precisely
  because it is never loaded into context**: it is a greppable index into the project, so one
  `grep` for a symbol returns its section, its script, and its data file for a few hundred
  tokens instead of opening a hundred-page workbook. Write rows so grep works.

  New template: [`starter/CHANGELOG.md`](starter/CHANGELOG.md) (heavily commented, with a
  worked row). New README subsection, "The research changelog: one row per result", under
  *Status vs. changelog*; the DONE-log section now explains when to graduate from one to the
  other. `scripts/bootstrap.sh` offers the template behind the existing "large / multi-branch
  project?" question, alongside `bigPicture.tex` and `strategy-map.md`.

### Clarified
- **DONE log vs. research changelog.** They are different artifacts and the guide now says so:
  the DONE log in `next-session-prompts.md` is *chronological, per session* ("what did I finish
  on Tuesday"); the research changelog is *an index, per result* ("everything we know about
  this formula, with its script and its limitation"). Start with the DONE log; graduate when
  you catch yourself scrolling it to answer "did we already check this?".
- **The status snapshot re-bloats — expect to re-condense.** Dated entries creep back into
  `CLAUDE.md`'s status section over months; the fix is the same move each time, and
  [`starter/CLAUDE.md`](starter/CLAUDE.md) now carries the rule inline ("if a status line has a
  date in it, it belongs in the dated log") together with the two-way discipline: append to the
  dated log when a result *lands*, refresh the snapshot when a branch's DONE/OPEN *frontier*
  moves.

### Action needed if you set up a project before this release
- **Nothing required — additive and optional.** Copy
  [`starter/CHANGELOG.md`](starter/CHANGELOG.md) into your project when your DONE log or
  `CLAUDE.md` status section outgrows a screenful (start it by *moving* that content in, not as
  an empty file). Re-copying the comment block in `starter/CLAUDE.md` § Current status is
  cosmetic.

---

## v2026.07 · v1.6.0 — 2026-07-11 (update)

### Added
- **Scaling the workflow to large, multi-branch projects.** A flat `CLAUDE.md` plus one
  workbook is the right starter, but it stops scaling once a project grows several
  sub-projects deep. A batch of new (additive) guidance covers the structures that let it
  keep scaling without bloating the always-loaded context:
  - **Nested (per-directory) `CLAUDE.md` files** — pushed down next to the branch they
    describe, loaded on demand (Part II, "CLAUDE.md").
  - **Status vs. changelog split** — keep `CLAUDE.md`'s status a lean per-branch *snapshot*;
    move the dated log elsewhere ("if a line has a date, it's a changelog").
  - **Built-in memory** — one-fact-per-file, typed (`user`/`feedback`/`project`/`reference`),
    indexed by `MEMORY.md`; what to keep re-teaching Claude vs. what belongs in `CLAUDE.md`.
  - **Strategy maps** — the research *route plan* (named, ordered strategies + falsified
    detours + an honesty ledger), distinct from the immediate task queue.
  - **A three-tier overview → brief → workbook stack** — a short, equation-light
    `bigPicture.tex` read *first*, with a proven/open status ledger.
  - **Crash-course appendices** that make the workbook self-teaching.
  - **The per-branch kit** — each active branch gets its own CLAUDE.md + queue + strategy
    map + overview (Part III, "Group projects").
  - **A trust ledger** (make epistemic status explicit) and a **trap log** (the tool
    failures that produce wrong answers, not errors) — both in Part IV.
  - **Consistency invariants** — a structural cross-check stronger than re-running (Numerics).
  - **KaTeX-safe previews** and **convention hygiene** to stop `CLAUDE.md` drift.
- **Two new optional starter templates:** [`starter/bigPicture.tex`](starter/bigPicture.tex)
  (the overview document, with ready-made proven/open ledger boxes) and
  [`starter/strategy-map.md`](starter/strategy-map.md) (the route-plan template). Both are for
  *big* projects; the bootstrap offers them behind a "large / multi-branch project?" question
  (declined by default) — or copy them by hand when a project reaches that scale.

### Clarified
- **"Strategy map" vs. "pipeline workflow."** These are different tools and the guide now says
  so explicitly: a **strategy map** plans the *research* (proofs, analysis, write-ups); a
  **pipeline** doc (Part III) maps a large *code*. A big project may want both.
- **Cross-references are token economy, made explicit.** The "structuring workbook.tex" guidance
  (README + `starter/CLAUDE.md`) now spells out *why* to label everything and cross-reference
  liberally: every line Claude reads to *find* something is context spent, so dense `\label`s +
  a deep hierarchy let it pull exactly what it needs with cheap targeted reads instead of
  scanning pages.

### Action needed if you set up a project before this release
- **Nothing required — it is all additive and optional.** For a large, multi-branch project,
  copy [`starter/bigPicture.tex`](starter/bigPicture.tex) and
  [`starter/strategy-map.md`](starter/strategy-map.md) when you reach that scale; the rest is
  guidance you can adopt piecemeal. Nothing breaks if you skip all of it.

---

## v2026.07 · v1.5.0 — 2026-07-01 (update)

### Added
- **The pipeline workflow — give every big code a short living map Claude reads first.**
  Some projects grow a large, hard-to-read code artifact (a many-cell notebook, a numerics
  engine, a solver) that neither you nor Claude can hold in context. The pipeline workflow
  gives each such code one short `Pipeline/` doc — what it computes, how the data flows, which
  symbol lives where, the traps — that Claude reads *before* the source. It graduates a set of
  tools proven on a real months-long project: three skills (`/write-pipeline` code→doc,
  `/check-pipeline` drift detection that fixes the doc, `/apply-pipeline` the guarded write-side
  that edits code from the doc), a read-only **`pipeline-auditor`** sub-agent (the first agent in
  the starter — it reads doc + code together and hunts real bugs and optimizations, reports
  never edits), and two shell helpers (`pipeline-guard.sh`, `pipeline-coverage.sh`). Full
  rationale and setup: [`docs/pipeline-workflow.md`](docs/pipeline-workflow.md); a new README
  section ("The pipeline workflow") introduces it.

  **Adopt-at-trigger, not at-setup.** You can't know on day one whether a project will get big,
  so nothing here asks you to predict that. The skills and agent are inert until you invoke them,
  and `pipeline-guard` **self-quiets until a `Pipeline/` doc actually exists** — so the bootstrap
  installs the whole workflow for *any* project with code, and it simply sits dormant until the
  trigger: when a code becomes the file you dread opening, run `/write-pipeline` on it. It is not
  worth the overhead for a 40-line script.

### Action needed if you set up a project before this release
- **Optional — only if you have (or grow) a large, hard-to-read code.** To get the workflow,
  copy `starter/.claude/skills/{write,check,apply}-pipeline/`,
  `starter/.claude/agents/pipeline-auditor.md`,
  `starter/.claude/hooks/pipeline-{guard,coverage}.sh`, and `starter/Pipeline/README.md` into
  your project, and add the "Pipeline workflow" section from `starter/CLAUDE.md` to your own
  `CLAUDE.md`. To get the edit-time nudge, enable the `pipeline-guard` PostToolUse block
  documented in `starter/.claude/settings.json` (it stays silent until your first pipeline doc
  exists, so enabling it early is harmless). Nothing breaks if you skip all of this.

---

## v2026.06 · v1.4.0 — 2026-06-30 (update)

### Added
- **`wolfbook` skill — a playbook for driving the live Wolfram kernel via the Wolfbook MCP.**
  Complements `wolfram-headless` (one-shot `wolframscript`): when you run a *live* kernel + `.wb`/`.nb`
  notebook through the `mcp__wolfbook__*` tools, this skill picks the right tool for each job (orient →
  evaluate → edit → checkpoint → look up), flags the multi-statement / `runCell` line-splitting
  pitfalls, uses kernel checkpoints for safe rollback, and reads kernel errors as stop-and-fix.
  **Conditional** — install only if you use the Wolfbook MCP (`wolfbook.mcpEnabled` on);
  `scripts/bootstrap.sh` adds it for Mathematica projects. Every technical claim was verified against
  the v2.7.14 extension source before publishing (that audit is what caught that `runCell` actually
  returns fresh output and surfaces messages — see the 2026-06-29 note).

---

## v2026.06 · v1.3.0 — 2026-06-29 (update)

### Added
- **distill — a token filter for research command output (now referenced in the guide).**
  distill is a separate, optional companion tool (its own public repo:
  [github.com/Mexregkan/distill](https://github.com/Mexregkan/distill)) that filters the
  long, noisy output of research commands — `pdflatex`, `wolframscript`, Python numerics —
  before Claude reads it, while writing the complete raw output to a file so nothing is
  lost. It keeps errors, warnings, results, and Wolfram kernel messages, **never alters
  numbers**, and removes ~90% of a typical LaTeX compile; a regression suite plus sampled
  audits back the savings claim. See the new "distill" section in the README. It is *not* a
  drop-in starter file — install it from its own repo — and its Python filter is still
  experimental.

### Clarified
- **Added a formal `LICENSE` file (MIT).** The README already stated the toolkit is MIT, but
  there was no `LICENSE` file — so GitHub didn't register the license and the grant was only
  prose. The repo now ships the actual MIT license text covering the scripts, skills, and
  starter package. No change to terms; it just makes the existing MIT promise legally real.

### Changed
- **`wolfram-headless` now encodes "read and act on kernel errors."** A hard-won lesson from real
  work: a Wolfram kernel error — an undefined symbol (`ReplaceAll::reps`), a structure mismatch
  (`Set::shape`), a forward-reference to a symbol defined in a later cell — is a *stop-and-fix*
  signal, not benign noise; one undefined symbol silently invalidates everything downstream. The
  skill's new RULE 4 says to treat these as stop-and-fix, to **verify state by evaluating**
  (`ValueQ`/`Head`/`FreeQ`) rather than trusting displayed output: `runCell` surfaces messages in a
  `⚠ Kernel messages` section (read them) and `getNotebookContext` is a cached snapshot (don't read
  it as fresh) — so confirm by evaluating; and run a sanity-sweep after multi-cell setup. The README
  Wolfbook section gained a short note on the same discipline, with a dedicated write-up,
  [`docs/wolfbook-kernel-errors.md`](docs/wolfbook-kernel-errors.md) — the most expensive Wolfbook
  trap we hit. We verified against the v2.7.14 extension source that this is **not** a Wolfbook bug
  (`runCell` already returns fresh output and surfaces messages), so the fix is *behavioral* (the
  skill), not a code patch. **Re-copy `starter/.claude/skills/wolfram-headless/` to pick it up.**

---

## v2026.06 · v1.2.0 — 2026-06-22 (update)

### Added
- **Guide: "Group projects — shared vs personal configuration."** A new README section for
  teams sharing one repo: which Claude Code config to **commit** (`CLAUDE.md`,
  `.claude/settings.json`, `.claude/skills/`, `.claude/hooks/`, `.mcp.json`) and which to keep
  **personal** (`.claude/settings.local.json`, `CLAUDE.local.md`, and everything under
  `~/.claude/`). Covers settings/memory precedence, the fact that a committed hook runs on every
  collaborator's machine (keep them portable; ship setup-dependent ones off), and not putting
  secrets or personal paths in shared files. The starter `.gitignore` now ignores
  `.claude/settings.local.json` and `CLAUDE.local.md` so personal config can't be committed by
  accident.

### Changed
- **`nb-to-wolfbook` now de-rectangles private-font operators (PUA → ASCII).** Mathematica
  stores `==`, `->`, `:>` and the constants `I`, `E` as characters in the Unicode Private Use
  Area. The kernel parses them exactly like the ASCII forms and Mathematica's own font draws
  them correctly, but a code font without those glyphs (VS Code's default, most monospace
  fonts) renders each as an **empty rectangle** — so a cell like `If[w == 1, …]` showed up as
  `If[w ▯ 1, …]`. Nothing was broken, but it was confusing to read. Conversion and `--fix-wb`
  now normalize these to ASCII automatically (string-literal-aware — text inside `"..."` is
  left alone — and word-boundary-safe for the letter constants). New `--puafix` CLI does only
  this de-rectangling on an existing `.wb` with the smallest possible diff, and `--check` now
  also reports any rectangle-rendering PUA characters left in code cells. **Re-copy
  `starter/.claude/skills/nb-to-wolfbook/` to pick this up.**
- **Wolfram output now wraps instead of forcing a sideways scroll.** `notebook.output.wordWrap`
  (already shipped) only wraps *text* output; a Wolfram result renders by default as a single
  fixed-width *image* that can only scroll horizontally, so wide results still ran off the right
  edge. The starter settings and `scripts/apply-notebook-ux.py` now also set
  `wolfbook.notebook.rendering.outputFormat` to `"InputForm"`, which renders results as wrapping
  plain text that follows the notebook width and one theme colour. (Trade-off: linear text loses
  the 2-D typeset layout — set a notebook back to `"Image"` if you prefer that there. The key is
  Wolfbook-specific and harmless to non-Wolfbook notebooks.) See
  [`docs/wolfbook-notebook-ux.md`](docs/wolfbook-notebook-ux.md).

### Clarified
- **"Global skills" guide section corrected and expanded.** Its examples used the flat
  `latex-compile.md` form, which contradicts the folder rule the guide states earlier — a global
  skill is `~/.claude/skills/<name>/SKILL.md`, same as a project skill, or it silently fails to
  register. Fixed those (and the `/pdf` install example), and added the gotcha for skills that
  ship helper scripts (rewrite the in-`SKILL.md` path to `~/.claude/skills/...` for a global
  copy) plus which toolkit skills make good global candidates (the structure-agnostic tools) vs
  which stay project-local (`sync-brief`, `overleaf-sync`).

### Action needed if you set up a project before this release
- **To get output wrapping, re-copy `starter/.vscode/settings.json`** (or add the one line
  `"wolfbook.notebook.rendering.outputFormat": "InputForm"`), or re-run
  `python3 scripts/apply-notebook-ux.py`. Optional — nothing breaks without it; wide Wolfram
  output just keeps scrolling sideways until you do. Reload the VS Code window afterwards.
- **Re-copy `starter/.gitignore`** (or add the two lines `.claude/settings.local.json` and
  `CLAUDE.local.md`) so your personal Claude Code config stays out of a shared repo. Optional and
  harmless if you work solo.

---

## v2026.06 · v1.1.0 — 2026-06-20 (update)

### Added
- **Notebook word wrap + Mathematica-style section folding for VS Code.** Two quality-of-life
  fixes for working in `.wb` (and any) notebooks: long cell lines now *wrap* instead of
  scrolling sideways, and you can *collapse a whole section* the way you double-click a section
  bracket in Mathematica. Neither patches the Wolfbook extension — both configure VS Code
  itself, so they survive extension updates. The non-obvious part the new guide explains:
  wrapping notebook *cells only* (without also wrapping your `.tex`/`.py`/`.md` files) needs
  `notebook.editorOptionsCustomizations` — the plain `editor.wordWrap` wraps every file, and the
  language-scoped `"[wolfram]"` form doesn't reach cells at all. Word wrap now ships on by
  default in the starter (`starter/.vscode/settings.json`); the new
  `scripts/apply-notebook-ux.py` installer also adds the section-folding keybindings
  (`Ctrl+Alt+[`/`]`, mac `⌥⌘[`/`]`), works across VS Code / Cursor / VSCodium / Windsurf, and
  is idempotent with `--dry-run`/`--revert`. Both bootstrap routes install it for
  Mathematica/notebook projects (a manual copy of all of `starter/` still gets it regardless).
  See [`docs/wolfbook-notebook-ux.md`](docs/wolfbook-notebook-ux.md).

### Action needed if you set up a project before this release
- **To get word wrap as a tracked default, re-copy `starter/.gitignore` (or just add the two
  lines).** Its `.vscode/` rule is now `.vscode/*` + `!.vscode/settings.json`, so the shared
  word-wrap `settings.json` is tracked while personal VS Code state stays ignored. Then copy
  `starter/.vscode/settings.json` into your project's `.vscode/`, or run
  `curl -fsSL https://raw.githubusercontent.com/Mexregkan/claude-for-researchers/main/scripts/apply-notebook-ux.py | python3 -`
  (which also installs the section-folding keybindings). This is optional — nothing breaks
  without it; you just won't get word wrap until you do one of these.

---

## v2026.06 · v1.0.1 — 2026-06-18 (update)

### Fixed
- **`verify-citation`, `reality-check`, `cross-validate` were missing their YAML frontmatter.**
  Without the `---\nname: ...\ndescription: ...\n---` block, Claude Code silently does not
  register these as slash commands — `/verify-citation` would not appear in the `/` menu and
  could not be invoked. Re-copy all three `SKILL.md` files from `starter/.claude/skills/`.

### Changed
- **`cross-validate` example generalised.** The Step 1 worked example used an Eisenstein series
  claim that was specific to one project. Replaced with a universally recognisable Gaussian
  integral example so the format is clear to any researcher.

---

## v2026.06 · v1.0.0 — 2026-06-13

First tagged release of the current structure. Everything below landed this month.

### Action needed if you set up a project before this release
- **Skills must use the folder format `skills/<name>/SKILL.md`.** A flat
  `skills/<name>.md` file is silently *not* registered as a slash command. If your
  skills are flat files, move each `<name>.md` to `<name>/SKILL.md`.
- The skills below were rewritten. If you copied earlier versions, re-copy them
  from `starter/.claude/skills/` to get the fixes.
- **Re-copy `nb-to-wolfbook` and `sync-wb-nb`** (see the `nb-to-wolfbook` entry under
  Fixed): an earlier copy can *silently drop a factor* from a display-wrapped
  definition during `.nb` → `.wb` conversion. Re-copy both skill folders from
  `starter/.claude/skills/`; if you installed `sync-wb-nb` globally, also replace
  `~/.claude/skills/sync-wb-nb/`. Then run
  `python3 .claude/skills/nb-to-wolfbook/wl_normalize.py --check <your.wb>` on existing
  notebooks — the gap was latent, so a notebook converted earlier may already be wrong.
- **Re-copy `latex-compile`** (see Changed): an earlier copy missed broken `\ref`/`\cite`
  warnings, so a compile could report clean while the PDF printed `??`/`[?]`. Re-copy
  `latex-compile` from `starter/.claude/skills/` (and replace `~/.claude/skills/latex-compile/`
  if you installed it globally), then recompile and confirm the broken-ref gate is clean.

### Added
- **Adaptive bootstrapping.** Both setup routes now install *by relevance* instead
  of installing everything: the README bootstrap prompt selects skills from your
  project description, and a new interactive `scripts/bootstrap.sh` asks a few
  questions and installs only what applies. The workbook / brief /
  next-session-prompts trio plus CLAUDE.md is the universal core; everything else
  is conditional.
- **Global skills** (`~/.claude/skills/`) documented — install a skill once and use
  it in every project; bootstrapping checks there before making a local copy.
- **Overleaf-via-git workflow** and the `overleaf-sync` skill, for collaborating on
  a shared Overleaf project from its git remote.
- **AI-output staging**: `numerics/generated/` and `figures/generated/` folders for
  Claude-produced outputs pending your review.
- **Wolfbook splitter fix**: `scripts/patch-wolfbook-splitter.py` patches a sharp edge in
  Wolfbook's cell evaluator — a `(* ... *)` comment right after an operator (`x :=(*note*)`
  with the RHS on the next line) hid the operator from the line-splitter, tearing one
  statement into two broken inputs (`Syntax::sntxi` + a bogus orphan evaluation). Idempotent,
  backs up, `--revert`able. Both bootstrap routes surface a zero-clone one-line installer
  (`curl … | python3 -`) for Mathematica projects. See
  [`docs/wolfbook-comment-split-fix.md`](docs/wolfbook-comment-split-fix.md).
- **Context-monitoring note** in the session-length section: the read-only `/context`
  (what's filling the window) and `/usage` (where tokens/cost go) commands, plus a rule
  of thumb — glance at ~50%, act by ~70%, don't wait for auto-compaction, and for
  research prefer a fresh session seeded from your documents over repeated (lossy)
  compaction.
- **`wolfram-headless` skill** for reliable heavy headless `wolframscript`. It encodes
  two hard-won lessons: (1) `The product exited because of a license error` is almost
  always a mis-reported kernel **crash** (a memory spike), not a licensing problem — so
  it shows how to confirm the licence then shrink the computation; and (2) literal Greek
  in a `.wls` file **silently corrupts symbols** under `wolframscript`'s non-UTF-8 read,
  so always use ASCII escapes (`\[Omega]` …). Ships `scripts/greek2esc.py` (convert a
  file in one pass) and an opt-in `hooks/wolfram-license-notice.sh` that auto-flags the
  misleading error. `scripts/bootstrap.sh` installs it for Mathematica/wolframscript
  projects (and now fetches every skill's helper scripts, not just the SKILL.md).

### Changed
- **`latex-compile`** rewritten: compiles with `pdflatex` and captures stdout
  (avoiding the `latexmk` stale-log trap), greps with `-a` (pdflatex embeds binary
  bytes that silently defeat plain grep), uses correct severity thresholds, and
  reformats rather than rewords when fixing overfull boxes.
- **`latex-compile` now catches broken `\ref`/`\cite`.** The issue grep matched only
  capital `Undefined` (the fatal *control sequence* error) and so missed the lowercase
  broken-reference/citation *warnings* (`Reference 'x' … undefined`, `Citation 'x' …
  undefined`) — meaning a dead `\ref` could ship as `??` and a dead `\cite` as `[?]`
  while the run reported clean. The pattern is now `[Uu]ndefined`, plus key-mismatch
  diagnosis (used vs. defined keys) and a **mandatory broken-ref gate** that must report
  zero undefined refs/cites before the skill claims success.
- **`sync-wb-nb`** gained a `regenerate` mode that rebuilds a whole `.nb` from its
  `.wb` with proper syntax colouring and section headings — for new or
  fully-rewritten notebooks, alongside the existing cell-by-cell sync.
- **`nb-to-wolfbook`** rewritten to make every converted cell *bridge-safe*: each
  statement goes on one physical line, so the tool that runs cells from VS Code
  cannot silently mis-evaluate a statement that was wrapped across several lines.
  The line-boundary detector handles the tricky Wolfram cases — postfix `&`
  (`Function`) ends a statement while `&&` continues it, `/;` (`Condition`) and `/.`
  continue, `2.` (a number) ends, and backslash-continued long numbers/strings
  (e.g. high-precision values, `*^-76` exponents) re-join with no inserted space.
  Ships helper scripts (`nb2wb.py`, `nb2wb_extract.wls`, `wl_normalize.py`).
- **Permissions model** in `starter/.claude/settings.json`: allow routine commands,
  *ask* before anything dangerous (including `sudo`/`mkfs`/`fdisk`/`shred`), block
  nothing outright — so Claude never stalls but always pauses before a risky action.
- Templates consolidated into `starter/` (the old `examples/` folder was retired);
  the `sync-condensed` skill was renamed `sync-brief`.
- The **dual-remote mirror hook is now opt-in** (off by default). It was a silent
  trap before — see Fixed.

### Fixed
- **`nb-to-wolfbook` could silently drop a factor from a display-wrapped definition.**
  The bridge-safety detector decided line breaks by how a line *ended*. A wide
  definition that the Mathematica front end *display-wrapped* onto an indented next
  line ends in a complete value (e.g. `…)`), so the detector mistook the wrap for a
  statement boundary, split the definition, and silently dropped the trailing factor —
  no error, a wrong definition. `wl_normalize` now also treats a newline followed by a
  *continuation indent* as a wrap (genuine statement breaks start at column 0), and
  ships a hazard checker — `wl_normalize.py --check <file.wb>` (exit 1 on any
  definition split across a top-level newline), run automatically by `nb2wb.py` and by
  `sync-wb-nb regenerate` before it overwrites a `.nb`.
- **Silent dual-remote mirror hook.** The starter's `settings.json` shipped an
  *active* `PostToolUse` hook running `scripts/git-push-both.sh`, but the starter
  didn't include that script — so a copied project appeared to mirror pushes to a
  second remote (e.g. institution GitLab) while silently doing nothing. The hook now
  ships **off** (empty `PostToolUse`), the `git-push-both.sh` template is included
  under `starter/scripts/`, and both bootstrap routes enable it only if you say you
  use two remotes, with the exact block to paste documented in `settings.json`.

### Clarified
- The opening of the guide now states its scope explicitly: this is a workspace and
  workflow toolkit to make *your* research faster, not a system for getting Claude
  to conduct research autonomously.
