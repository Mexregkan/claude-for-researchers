# Wolfbook MCP: kernel errors and stale cell output

**Who needs this:** anyone driving a live Wolfram kernel through the Wolfbook MCP from Claude
Code. This is the single most expensive Wolfbook trap we have hit — hours lost to misdiagnosis —
but it turned out to be about **how output is read and acted on**, *not* a bug in Wolfbook. We
read the extension source (v2.7.14) to be sure; see "Is there a code patch?" at the end.

## The trap

A forward-reference makes a broken build look fine. In a working notebook, definitions and
solutions are often placed *after* the cells that use them. A single top-to-bottom pass then runs
a cell against an **undefined symbol**, and Wolfram does not stop — it emits a message and keeps
going with a broken value:

- `ReplaceAll::reps` ("`X` is neither a list of replacement rules …") — `X` is undefined or the
  wrong type; a stray `/.` then **poisons that symbol's value and propagates** to everything built
  on it.
- `Set::shape`, `Part::partd`, `Set::write` / `… is Protected`, any "`… is not defined`".
- `Syntax::sntxi` ("Incomplete expression") on a cell you just ran.

A human running cells fixes this the instant they see the red message. The failure mode is
**skimming past the message** as "a warning" and then debugging the *math* for hours when the real
cause is an undefined symbol three cells up.

## Two output sources — only one is "fresh"

The fix hinges on knowing which MCP tool gives a fresh result and which gives a snapshot:

- **`runCell` re-executes and returns FRESH output.** In current Wolfbook (v2.7.x) it aborts any
  running eval, re-runs the cell, waits for the kernel to go idle, then reads the *updated* output —
  and it **surfaces kernel messages in a dedicated `⚠ Kernel messages (N):` section** (with a
  special flag for `Syntax::`). So the messages are **not** hidden; the job is to **read that
  section and act on it**, not to judge success from the result line alone.
- **`getNotebookContext` returns a CACHED snapshot.** It reads each cell's *stored* output and does
  **not** re-evaluate (correctly — it is a context-mapping tool, not an evaluator). Its outputs
  reflect the last time each cell ran, which may be stale. **Never treat a `getNotebookContext`
  output as a fresh result** — to know a cell's current value, re-run it (`runCell`) or evaluate.

## What to do (the discipline that actually fixes it)

The toolkit ships this so Claude follows it by default:

- **Treat a kernel message as STOP-and-fix, not noise.** Read `runCell`'s `⚠ Kernel messages`
  section. On an undefined symbol, define/run it first, then re-run the dependent cells (a 2nd pass).
- **Confirm state by EVALUATING.** `ValueQ[sym]`, `Head[sym]`, `FreeQ[sym, ReplaceAll]` — pick a
  check that *survives* evaluation (`FreeQ[_, ReplaceAll]`, `Head[x] === Plus`); `FreeQ[_, foo]` is
  bogus if `foo[]` evaluates away.
- **Sanity-sweep after multi-cell setup:** `Select[{<key symbols>}, ! FreeQ[#, ReplaceAll] &]` must
  be `{}`, and `ValueQ /@ {<data lists>}` all `True`.

This is the [`wolfram-headless`](../starter/.claude/skills/wolfram-headless/SKILL.md) skill's RULE 4
— install the skill and Claude applies it whether it runs Wolfram headless or through the MCP.

## Is there a code patch (like the splitter fix)?

**No — and we verified why.** We read the Wolfbook v2.7.14 source (`out/extension/tools/index.js`,
`RunCellTool`; `GetNotebookContextTool`): `runCell` already (a) re-executes and reads fresh output,
and (b) separates kernel messages into a `⚠ Kernel messages` section; `getNotebookContext` reads
stored outputs *by design*. So there is **nothing to patch** in the MCP for this — unlike the
comment-split bug, which has a real source fix
([`scripts/patch-wolfbook-splitter.py`](../scripts/patch-wolfbook-splitter.py),
[`wolfbook-comment-split-fix.md`](wolfbook-comment-split-fix.md)). Our lost hours were behavioral:
not reading the messages `runCell` surfaced, and reading a `getNotebookContext` snapshot as if it
were a fresh evaluation. The fix is the discipline above, not a code change.
