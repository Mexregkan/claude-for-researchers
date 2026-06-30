# Wolfbook MCP: kernel errors and stale cell output

**Who needs this:** anyone driving a live Wolfram kernel through the Wolfbook MCP from Claude
Code (running/editing `.wb`/`.nb` cells), as opposed to headless `wolframscript`. This is the
single most expensive Wolfbook trap we have hit — it cost *hours* of misdiagnosis — so it is
worth knowing even though the fix today is mostly a working discipline, not a one-line patch.

## The trap

Two things combine to make a broken build look fine:

1. **The displayed cell output can be stale.** The MCP tools that show a cell (`runCell`,
   `getNotebookContext`) re-display the cell's **last-rendered (cached) output**. So after you
   re-run a cell, a *fresh* kernel error can sit hidden behind clean-looking old output, and a
   *stale* error can persist on screen after you have already fixed the cause. Judging "did that
   work?" by what the cell *shows* is therefore unreliable.

2. **A single kernel message invalidates everything downstream — and is easy to skim past.** In
   a working notebook, definitions and solutions are often placed *after* the cells that use them
   (a forward-reference). One top-to-bottom pass then runs a cell against an **undefined symbol**,
   and Wolfram does not stop — it emits a message and keeps going with a broken value:

   - `ReplaceAll::reps` ("`X` is neither a list of replacement rules …") — `X` is undefined or the
     wrong type; a stray `/.` then **poisons that symbol's value and propagates** to everything
     built on it.
   - `Set::shape`, `Part::partd`, `Set::write` / `… is Protected`, any "`… is not defined`".
   - `Syntax::sntxi` ("Incomplete expression") on a cell you just ran.

   A human running cells interactively fixes this the instant they see the red message. An
   automated agent (or a tired human) skims past it as "a warning" and then spends hours
   debugging the *math* when the real cause is an undefined symbol three cells up.

## What to do today (the mitigation that actually works)

The reliable fix is a discipline, and the toolkit ships it so Claude follows it by default:

- **Treat those messages as STOP-and-fix, not noise.** When one appears, define/run the missing
  symbol first, then re-run the dependent cells (a second pass) — or run the solution cells before
  the build.
- **Confirm state by EVALUATING, never by reading the cell display.** After a setup cell, evaluate
  `ValueQ[sym]`, `Head[sym]`, or `FreeQ[sym, ReplaceAll]` — and pick a check that *survives*
  evaluation (`FreeQ[_, ReplaceAll]`, `Head[x] === Plus`); a test like `FreeQ[_, foo]` is bogus if
  `foo[]` evaluates away.
- **Sanity-sweep after any multi-cell setup**, before trusting the build:
  `Select[{<your key symbols>}, ! FreeQ[#, ReplaceAll] &]` must be `{}`, and
  `ValueQ /@ {<your data lists>}` must be all `True`.

This is encoded as a rule in the [`wolfram-headless`](../starter/.claude/skills/wolfram-headless/SKILL.md)
skill ("read and act on kernel errors"), so if you install that skill, Claude applies it whether it
runs Wolfram headless or through the MCP. You do not need to do anything beyond having the skill.

## Is there a code patch (like the splitter fix)?

**Not yet — and we will not pretend there is.** Unlike the comment-split bug, which has a verified
one-line source fix you can apply with
[`scripts/patch-wolfbook-splitter.py`](../scripts/patch-wolfbook-splitter.py) (see
[`wolfbook-comment-split-fix.md`](wolfbook-comment-split-fix.md)), the stale-output / message-surfacing
behaviour has **not** been pinned down in the Wolfbook source. A candidate improvement — have the MCP
return the *fresh* evaluation result and surface kernel `Symbol::tag` messages in a dedicated field —
is staged for a possible upstream contribution, but until it is verified there is no drop-in patch.
So **for now the fix is behavioral** (the discipline above), not a code change.

If you want to help: confirming whether `runCell` returns fresh vs cached output in the extension
source (`out/extension/…`) is the missing piece that would turn the candidate into a real patch.
