---
name: apply-pipeline
description: The write-side inverse of /check-pipeline and the pipeline-auditor — read a Pipeline/ doc (and/or an audit report) and EDIT the code accordingly: apply an optimization the pipeline describes, correct code the pipeline (backed by your authoritative notes) shows is wrong, or bring the code in line with the documented behavior. Use when the user wants the code changed based on the pipeline. High-stakes: bakes in live-editor editing, mirror sync, ground-truth protection, and control-gating. Proposes a diff and gets approval before any risky edit.
---

# /apply-pipeline — turn a pipeline (or audit) into code edits

This closes the loop with the other pipeline tools:

| tool | direction | writes? |
|---|---|---|
| `/write-pipeline` | code → new doc | doc |
| `/check-pipeline` | code vs doc → drift report | doc (on approval) |
| `pipeline-auditor` (agent) | code via doc → bug/opt report | nothing (read-only) |
| **`/apply-pipeline`** | **doc/report → code edits** | **code** (with guards) |

Use it when the user wants the **code** changed on the basis of the pipeline: implement an
optimization the pipeline names, correct code the pipeline (backed by your authoritative notes)
shows is wrong, or reconcile code to documented behavior.

## Source-of-truth rule (READ FIRST — it decides whether you should edit code at all)

In a research project the **code and the committed data are usually ground truth**; the pipeline is
a *map of intent*. So when code and pipeline disagree, the usual fix is to change the **doc**
(`/check-pipeline`), NOT the code. Only edit code when one of these holds:
1. The user explicitly asks for the code change ("apply this optimization", "make the code do X").
2. The pipeline — **and the authoritative notes it cites** (`workbook.tex` / the paper) — together
   show the code is genuinely wrong (a real bug), and the user has confirmed they want it fixed.
Otherwise, STOP and recommend `/check-pipeline` instead. Never "fix" code to match a doc that is
itself the thing that's stale.

## Method

**1. Read the inputs.** The pipeline doc, the notes section(s) it cites (grep `workbook.tex` for the
labels — the authority for *why*), and, if you're acting on an audit, that report. Dump the code if
it's a notebook: `python3 .claude/skills/write-pipeline/dump_code.py "$SCRATCH" "<code>"`.

**2. Pin the exact change.** State precisely what will change, in which cells/functions, and *why*
(cite the pipeline line + notes label). Confirm the change preserves the documented behavior (for an
optimization: identical output) or corrects it (for a bug: cite the correct form).

**3. Classify risk and gate.**
- **LOW** (apply, then validate): comments/dead-code, a pure refactor or optimization that provably
  gives *identical* output (e.g. replacing a `Do`+append loop with a vectorized build, hoisting an
  invariant, memoizing a pure function).
- **HIGH** (PREVIEW a diff + get explicit approval FIRST): anything touching the core math, a
  normalization/truncation convention (it changes what cached data *means*), or definitions other
  code depends on. **Never** overwrite committed results / cached numeric tables / solved outputs —
  those are the user's ground truth (see `CLAUDE.md` "AI-generated outputs"); regenerating data
  needs an explicit instruction.

**4. Apply with the right mechanism.**
- If the target notebook is **open in a live-kernel editor** (e.g. a `.wb` in VS Code via the
  Wolfbook MCP): edit it **through that editor's tools**, NOT the `Write` tool — a blind `Write`
  won't reload into the open editor and you'll fight a stale buffer. If it's closed, `Edit`/`Write`
  is fine.
- After any edit to one half of a mirrored pair (e.g. `.wb` ↔ `.nb`), propagate to the other and
  verify parsed-code equality. Keeping mirrors in sync is non-negotiable.
- Respect the code's line/format constraints (e.g. keep each statement on one physical line if the
  runner splits on newlines).

**5. Validate — do not trust the edit blind.**
- Re-run the edited cell(s)/function in the live kernel or interpreter, and **read + act on any
  error banner** (an undefined symbol, a shape/structure mismatch = STOP and fix).
- **Gate on a control**: after a change that could affect a result, re-run a known-good control case
  and confirm it still passes. If a control breaks, REVERT (a kernel checkpoint/restore, or a saved
  intermediate, makes this cheap) — the edit was wrong.
- For an "identical-output" optimization, assert equality on a sample before/after (`old - new === 0`
  on a few entries) before declaring done.

**6. Reconcile the doc + report.** If the edit changed cell numbers, symbol names, or documented
structure, update the pipeline `.md` (or run `/check-pipeline --fix`). Report: what changed, why,
the validation result (control passed / sample identical), and anything deferred.

## What this skill will NOT do without an explicit, specific instruction
- Regenerate or overwrite any committed result / cached numeric table / solved output.
- Change a mathematical result, or a convention that redefines what cached data means.
- Edit the authoritative notes (`workbook.tex` / Overleaf — those have their own skills).
- Push or commit (commit/push only when the user asks).
For any of those, surface the proposal and stop.
