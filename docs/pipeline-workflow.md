# The pipeline workflow: keep Claude fluent in your own code

**Who needs this:** anyone whose project has grown a few large, gnarly code artifacts —
a 400 KB Mathematica notebook, a numerics engine, a solver — that Claude (and you) can no
longer hold in context or read top-to-bottom. This workflow gives every such code a short,
living "pipeline" document that Claude reads *first*, keeps in lockstep with the code, and
audits for bugs and slowness. It is model-agnostic and not tied to any field; the examples
happen to be Wolfram notebooks, but the pattern works for any language.

This note is written from actually building it on a months-long research project. It covers
the idea, the four tools + one hook that implement it, and how to set it up in your own
project.

## When to adopt it (you can't decide at setup — and don't have to)

The workflow only pays off *above a threshold*: for a 40-line script it is pure overhead. But
you set a project up at the *start*, before you know whether it will ever grow a code that big.
So don't gate it on a "will this be a big project?" decision — you can't answer that on day one.

Instead it is **trigger-driven**. Install the tooling for any project that has code (it is inert
until invoked — a skill costs nothing until you type `/write-pipeline`, an agent nothing until
you spawn it, and the guard hook stays silent until a `Pipeline/` doc exists). Then adopt the
workflow at the natural moment: **when a code becomes the file you dread opening** — too big to
hold in context or read top-to-bottom — run `/write-pipeline` on it. Nothing to predict, nothing
to configure up front; the machinery is already there and activates itself the moment you need it.

---

## The problem

A big code file is a wall. Claude opening `giant-notebook.nb` (300+ cells) burns context and
still misses the structure; you re-explain the same data flow every session; and when the
code changes, nobody updates the mental model. The usual "just read the file" fails on the
exact files that matter most.

The fix is not more reading — it is a **map**. One markdown file per major code that says, in
two pages: what it computes, how the data flows through it stage by stage, which symbol lives
in which cell, the non-obvious traps, and what it consumes and produces. Claude reads the map
before the code and arrives oriented. You maintain the map, not a re-explanation.

But a map that drifts out of date is worse than none. So the workflow has to keep the map and
the code honest with each other, automatically.

---

## The idea in three invariants

1. **Every main code has a pipeline doc.** When a notebook/engine/script becomes load-bearing,
   it gets a `Pipeline/<name>.md`. Coverage is checkable, so "we forgot to document the new
   solver" is a caught error, not a silent gap.
2. **An agent keeps each pipeline healthy and optimized.** A read-only sub-agent reads the
   pipeline *and* the code together and hunts for real bugs (sign/normalization slips,
   convention violations, off-by-ones) and concrete optimizations (recomputation, missing
   memoization, complexity blow-ups). You run it before relying on a code, after a big change,
   and periodically.
3. **Code and pipeline move together.** Edit the code → check the doc for drift and fix the
   doc (the *code* is ground truth). Edit the doc → reconcile the code to the doc (with
   approval). A hook nudges the right direction on every edit so neither is forgotten.

Lifecycle:

```
   new code ──/write-pipeline──► pipeline doc
                                    │
                          pipeline-auditor (health + optimization)
                                    │
   edit code ──/check-pipeline──► fix the doc   (code is ground truth)
   edit doc  ──/apply-pipeline──► fix the code  (doc drives, with guards)
```

---

## What a pipeline doc looks like

Keep it dense and skimmable — a map, not a re-derivation. The house format that worked:

- **Purpose** — 2–4 sentences: what it computes and why it exists.
- **Pipeline** — one ASCII data-flow diagram of the load-bearing path
  (`input ──step──► intermediate ──step──► output`).
- **Key symbols** — a table `| symbol | cell | role |` (cite the cell/line so it is clickable
  and checkable).
- **Gotchas / guardrails** — the non-obvious traps, each pointing at the authority (a workbook
  section, a memory, a paper equation) rather than re-deriving it.
- **Inputs / outputs** — the files it loads/writes and the upstream/downstream codes.

If one code is too big for a single map (our main notebook is 327 cells), give it a **nested
folder** with a `README.md` index plus one file per stage. A reader lands on the index, sees
the stage list and the whole data flow, and dives into just the stage they need.

Two rules that keep the docs trustworthy:
- **The code is ground truth.** When the doc and code disagree, the doc is (usually) what is
  wrong. The doc is a *map of intent*, not a second source of truth for results.
- **Point, don't paste.** Cite section labels, cell numbers, and memory slugs; never paste
  large code blocks or numeric results into the map — they rot.

---

## The four tools + one hook

| Tool | Type | Direction | Job |
|---|---|---|---|
| `write-pipeline` | skill | code → doc | Write/refresh a pipeline doc for *any* code. Ships a helper that renders a notebook (`.wb`/`.nb`/`.ipynb` JSON) to a readable outline + full-text dump so it (and you) can actually read the thing. |
| `check-pipeline` | skill | code vs doc | Drift detection: every symbol, cell number, data file, and I/O claim in the doc is verified against the current code. Reports BROKEN (symbol/file gone) vs STALE (cell numbers shifted). Fixes the *doc* only, on approval. |
| `pipeline-auditor` | sub-agent | code via doc | Read-only review: reads doc + code, hunts bugs + optimizations, ranks by confidence, and clears already-known non-bugs so it does not cry wolf. Returns a structured report; it never edits. |
| `apply-pipeline` | skill | doc → code | The write-side inverse: apply an optimization the doc names, or correct code the doc (backed by your authoritative notes) shows is wrong. Guardrailed: previews a diff, protects ground-truth data, and re-runs a control before declaring success. |
| `pipeline-guard` | hook | on every edit | PostToolUse nudge: after you edit a main code, it tells Claude to run `check-pipeline` (+ an auditor pass); after you edit a pipeline doc, it tells Claude to run `apply-pipeline`. Nudge-only, never blocks; quiet on scratch files. |

Why these splits matter:
- **Read vs write are separated on purpose.** `check-pipeline` and `pipeline-auditor` are
  read-only — safe to run anytime. `apply-pipeline` is the only one that touches code, and it
  is the one with the approval + control-gating guards. You never accidentally rewrite a
  notebook while "just checking."
- **The auditor is an agent, the rest are skills.** An audit is an open-ended search — ideal
  for an isolated sub-agent you spawn and whose *conclusion* you keep (not its file dumps).
  Editing code needs the live editing tools and human-in-the-loop approval that only the main
  session has, so `apply-pipeline` is a skill, not an agent.

### The guardrails that make `apply-pipeline` safe

Editing a research codebase from a doc is the risky part. The guards that matter:
- **Source-of-truth rule.** Default to fixing the *doc*, not the code. Only edit code when the
  user asks for it, or when the doc *and* your authoritative notes together prove the code
  wrong. Never "fix" code to match a doc that is itself the stale thing.
- **Never overwrite ground-truth data** (cached numeric tables, solved results). Regenerating
  data needs an explicit instruction.
- **Control-gating.** After any change that could affect a result, re-run a known-good control
  case and confirm it still passes; if it breaks, revert. (A kernel checkpoint/restore, or a
  saved `.mx`, makes this cheap.)
- **Edit through the live tool, then sync mirrors.** If a notebook is open in an editor-backed
  live kernel (e.g. the Wolfbook MCP), edit it *through that*, not by overwriting the file, or
  you fight a stale buffer. Keep any `.wb`/`.nb` mirror in sync.

---

## How the auditor pays off (a real example)

On the first run, the auditor found — and we verified — two things worth the whole setup:
- A **doc error**: our pipeline claimed a zero-absorption fix "must live in the build cell,"
  but the notebook actually handles it *globally* one cell earlier. The code was fine; the
  *map* was wrong. We fixed the map.
- A **real convention bug**: a fast generator omitted a `Min[…, cutoff]` truncation cap that
  the reference implementation applies, so on half-integer terms the two engines summed
  different ranges. It was below the precision floor of the cached data (so nothing was
  corrupted), but it was a genuine inconsistency we would not have found by reading either file
  alone — it only shows up when you hold the doc's "these are the same" claim against both
  implementations.

That is the point: the auditor reads the *claim* in the map and tests it against the code.
Neither the map nor the code, read alone, surfaces that class of bug.

---

## Setting it up in your project

1. **Make a `Pipeline/` folder** and write one doc per major code with `write-pipeline` (or by
   hand, using the format above). Start with the biggest, most-opaque file — that is where the
   payoff is largest.
2. **Add the guard hook** so edits nudge the right tool. It is a short PostToolUse shell script
   matched on `Write|Edit|NotebookEdit` that reads the edited path and prints a one-line
   reminder (run `check-pipeline` on a code edit, `apply-pipeline` on a doc edit). It only
   emits `additionalContext`; it never blocks. Keep it scoped to your *main* codes + `Pipeline/`
   so it stays quiet on scratch scripts.
3. **Add a coverage check** — a tiny script that lists your main codes and flags any without a
   pipeline doc — so invariant (1) is verifiable. Run it whenever you add a code.
4. **Write the workflow into your `CLAUDE.md`** as a standing rule (the three invariants + the
   lifecycle + "read `Pipeline/README.md` before opening any large code"). The hook enforces the
   mechanics; the `CLAUDE.md` section makes every session *follow the intent*, including for the
   parts a hook cannot catch (e.g. edits made through a live-kernel MCP do not trigger a
   file-edit hook — the written rule covers those).
5. **Register the sub-agent** (a markdown file under `.claude/agents/` with `name`,
   `description`, and read-only `tools`). New agent types are picked up on the next session, so
   define it once and it is available thereafter; in the session you create it, just spawn a
   general-purpose agent with the same instructions.

The skills and agent are straightforward to port: each is a `SKILL.md` (or agent `.md`) whose
body is the method above plus your project's specific guardrails. Generalize the physics-specific
bits (control cases, ground-truth files, the live-kernel editing rule) to your own project's
equivalents.

---

## Honest caveats

- **A hook cannot see MCP/live-kernel edits.** File-edit hooks fire on `Write`/`Edit`, not on a
  notebook edited through a live-kernel MCP. Rely on the written `CLAUDE.md` rule for those, not
  the hook.
- **A newly-defined sub-agent type is not live mid-session.** It becomes selectable next session.
  In the session you author it, run the same prompt via a general-purpose agent.
- **The auditor reports; it does not fix.** That separation is deliberate — you (or
  `apply-pipeline`, with approval) decide what to act on. Do not wire the auditor to auto-edit.
- **Docs drift is normal and cheap.** Cell numbers shift when you insert a cell; that is a STALE
  finding, a one-line fix, not an alarm. Treat a *missing symbol* or a *contradicted claim* as
  the real signal.
- **This is overhead that pays off above a threshold.** For a 40-line script it is not worth it.
  For the files you dread opening, the map earns its keep every session.
