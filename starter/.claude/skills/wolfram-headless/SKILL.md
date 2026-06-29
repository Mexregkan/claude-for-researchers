---
name: wolfram-headless
description: Run heavy Wolfram Language (wolframscript) computations from Claude Code reliably, and diagnose the misleading "The product exited because of a license error". Use whenever invoking wolframscript on a non-trivial computation, when a wolframscript job dies with a "license error" despite a valid license, or when Wolfram numerics give silently wrong results in headless runs.
---

# wolfram-headless — reliable headless Wolfram in Claude Code

Hard-won rules for running `wolframscript` from Claude Code's Bash tool. Two findings dominate:
(1) **"The product exited because of a license error" is almost never a license problem** — it is a
kernel **crash** (usually a memory spike) mis-reported; and (2) **literal Greek Unicode in `.wls`
files silently corrupts symbols** under wolframscript. Both cost real time; this skill encodes the fix.

## RULE 1 — ASCII escapes in `.wls`, NEVER literal Greek (silent-corruption bug)

`wolframscript` reads `.wls` files under a non-UTF-8 encoding, so a literal `ω` (U+03C9) becomes a
**different, dead symbol** (mojibake `Ï‰`), with **no error**. `ω3 =!= \[Omega]3`; any `===`/pattern
test against the real symbol silently fails and results are wrong. Verified: a function keyed on the
real `\[Omega]3` falls through / returns garbage when fed the literal-`ω` symbol.

- In every `.wls`, write `\[Omega] \[Alpha] \[CapitalLambda] \[CapitalDelta] \[Pi] \[Epsilon] \[Tau] \[Mu] \[Xi]`,
  never the literal characters. `Pi`, `I`, `Infinity`, and ASCII names (`Delta`, `Esq`, `tau`) are fine.
- The notebook/desktop kernel (Mathematica FE / Wolfbook in VS Code) handles literal Greek fine — this
  is **headless-`.wls`-only**. So copying notebook code into a `.wls` introduces the bug.
- Quick converter (run before any heavy job): replace the Greek chars with their `\[...]` escapes.
  A one-liner is in `scripts/greek2esc.py` next to this skill.
- Audit a file: `LC_ALL=C grep -nP '[^\x00-\x7F]' file.wls` — anything in CODE (not comments) is a hazard.

## RULE 2 — "license error" is a mis-reported crash; diagnose, don't believe it

When a heavy `wolframscript` job prints `The product exited because of a license error`:

1. **Confirm the license is fine** (it almost always is):
   `wolframscript -code 'Print[{$LicenseType,DateString[$LicenseExpirationDate],$MaxLicenseProcesses}]'`
   A valid, unexpired license + `$MaxLicenseProcesses=Infinity` means **this is NOT a license issue.**
2. **It is a crash** — the kernel hit a resource wall (almost always a **memory spike** from a huge
   symbolic intermediate) and wolframscript reports any abnormal kernel exit as a "license error."
   Ruled out in practice as causes: the Bash sandbox (disabling it does NOT help), `ulimit` (address
   space is unlimited), encoding, wall-clock time, and the license itself.
3. **Localize it.** Instrument the computation statement-by-statement with memory markers; the last
   marker before the exit is the culprit. Template:
   ```
   mb := ToString[Round[MemoryInUse[]/1024^2]]<>"MB";
   Print["[stmt] ", expr, "  mem=", mb, " t=", Round[AbsoluteTime[]]]; (* before each heavy line *)
   ```
4. **Fix the spike** (in order of preference):
   - **Shrink the symbolic input first.** The usual cause is keeping too many symbolic unknowns. If
     lower-stage results are already solved, **substitute them in before the heavy step** so the
     expression collapses (e.g. a product of two length-N symbolic lists is N²; substituting known
     values can drop N by orders of magnitude). This is the single highest-leverage fix.
   - **Chunk huge products / Expands** so the full intermediate is never materialized
     (`Total[Table[Total[op[{a[[i]]}, b]], {i, Length[a]}]]` instead of `Total[op[a, b]]`) — but note
     an N² operation is still N² *operations*, so this only helps memory, not time.
   - **Run hygiene:** put `$HistoryLength = 0;` at the top (stops `Out[]` retaining giant results);
     `ClearSystemCache[]`/`Share[]` between heavy steps.
   - **Last resort: run it in the desktop / Wolfbook kernel** (Mathematica FE), which has more headroom
     and different limits, then `DumpSave` the result for headless reuse. If the same code builds in
     the FE kernel but not headless, the headless wall is the cause — don't keep fighting wolframscript.

## RULE 3 — long jobs: write results to a file, don't trust stdout/MCP

Heavy jobs exceed MCP/transport timeouts. Always `Put[result, "/tmp/job_result.m"]` (or `DumpSave`)
at the end and poll the file, rather than relying on the returned stdout. Run with Bash
`run_in_background: true` and a Monitor that greps for `license error|<your done marker>|ABORT`.

## RULE 4 — read kernel errors: undefined-symbol/structure errors are STOP-and-fix, not noise

A human running cells interactively fixes an undefined-symbol error the instant they see it. Do the
same — never skim past a kernel message as "benign noise." **One undefined symbol silently
invalidates everything downstream.**

- **Treat these as STOP-and-fix** (an undefined symbol, a cell-order forward-reference, or a typo —
  NOT a warning to ignore):
  - `ReplaceAll::reps` ("X is neither a list of replacement rules …") — `X` is **undefined or the
    wrong type**; a stray `/.` then poisons that symbol's value and propagates downstream.
  - `Set::shape` (`{a,b}=…` shapes differ) — the RHS didn't return the expected list/structure.
  - `Part::partd`, `Set::write` / `… is Protected`, and anything reading "… is not defined".
  - `Syntax::sntxi` ("Incomplete expression") on a cell you just ran — a real split/syntax issue.

  Forward-references (a symbol defined LATER in the file than the cell that uses it) are normal in
  working notebooks; a single top-to-bottom pass then breaks. Fix: define/run the missing symbol
  first, then re-run the dependent cells (a second pass).

- **Verify state by EVALUATING, not by reading displayed output.** Confirm a definition took with
  `ValueQ[sym]`, `Head[sym]`, or `FreeQ[sym, ReplaceAll]` — and pick a check that *survives*
  evaluation (`FreeQ[_, ReplaceAll]`, `Head[x] === Plus`); a test like `FreeQ[_, foo]` is bogus if
  `foo[]` evaluates away. **If you drive the kernel through the Wolfbook MCP rather than headless,
  the displayed cell output is CACHED and can be stale** — `runCell` / `getNotebookContext` may
  re-show an old error, or hide a fresh one behind clean-looking output. Always confirm by
  evaluating, never by reading the cell display.

- **Sanity-sweep after any multi-cell setup, before trusting a build.** Evaluate one health check:
  e.g. `Select[{<your key symbols>}, ! FreeQ[#, ReplaceAll] &]` must return `{}`, and
  `ValueQ /@ {<your data lists>}` must be all `True`. If anything is dirty, hunt the undefined symbol
  BEFORE suspecting a real mathematical obstruction.

## Checklist before launching a heavy wolframscript job
- [ ] `.wls` is pure ASCII in code (`grep -nP '[^\x00-\x7F]'` clean, or comments only).
- [ ] `$HistoryLength = 0;` at the top.
- [ ] Known/solved sub-results substituted in before the heavy step (shrink symbolic size).
- [ ] Result written to a file with `Put`/`DumpSave`.
- [ ] Run in background + Monitor for `license error` and a done-marker.
- [ ] If it dies with "license error": confirm `$LicenseType` is valid, then treat as a memory crash
      and localize/shrink — or build it in the desktop kernel.
- [ ] Judge success by EVALUATING key symbols (`ValueQ`/`Head`/`FreeQ`), not by reading output; treat
      any undefined-symbol/structure error (`ReplaceAll::reps`, `Set::shape`, …) as stop-and-fix.

## See also
- `hooks/wolfram-license-notice.sh` (companion hook) — auto-flags the "license error" so the next
  person doesn't misdiagnose it as a licensing problem.
