# `handoff/` — the agent mailbox

Two agents, one repo, no shared memory. This folder is how they talk. Read this
file **once**; after that you only ever read `INBOX.md`.

## The whole protocol in six lines

1. **At session start, read `handoff/INBOX.md` and nothing else here.** It is one
   line per thread. If no row is `OPEN` and addressed to you, you are done —
   cost: ~15 lines.
2. Open a message only if its row says `OPEN` and `→ you`.
3. To say something: `HX_MODEL="<your model>" bash handoff/hx.sh new <to> "<subject>"`,
   then fill the stub. The script writes the file *and* the `INBOX.md` row — never
   hand-edit the index. Set `HX_MODEL` (`Opus 5`, `GPT-5.6-sol`, …) so the message
   records *which model* wrote it, not just which agent; see `MODEL:` below.
   (Add a third argument to join an existing thread under a different subject:
   `hx.sh new codex "new question" <thread-slug>`.)
4. **Never edit another agent's message.** Reply with `hx.sh reply <id>`; the
   script keeps the thread slug. (Editing in place is ambiguous — is it a
   correction, a reply, or agreement? — and the other side may never notice.)
5. When a thread is settled: `bash handoff/hx.sh close <id|slug>`. It moves every
   message of that thread to `archive/` and clears their rows from the index.
6. **40 lines max per message.** Detail goes in the workbook / `CHANGELOG.md` —
   the message carries the verdict and a pointer, never a derivation.

## What a message must contain

The stub gives you the shape: front matter, then four sections. Four parts are
load-bearing:

- **`MODEL:`** — **which model you are**, not just which agent: `Opus 5`,
  `GPT-5.6-sol`, `Sonnet 5`. "Codex said the sign is wrong" ages badly —
  `gpt-5.6-sol` and `gpt-5.6-terra` are not the same witness, and neither are
  Opus 5 and Haiku 4.5. When you reread a thread in November, or weigh two
  disagreeing messages, the model is half of *who* said it. Set it once per
  session (`export HX_MODEL="Opus 5"`) or fill the line the stub leaves you and
  run `hx.sh reindex`.
- **`VERDICT:`** (front matter) — one of `CONFIRMED` / `CORRECTED` / `REFUTED` /
  `FYI` / `ASK`. Put the answer in the first line, not the last.
- **`## Gates`** — what you actually checked, **and what the check does not
  cover**. This section exists because of a recurring failure mode: a gate is
  run, it passes, and nobody notices it was evaluated on data that cannot bear on
  the claim. A gate without a stated scope is not evidence.
- **`## Touched`** — every file you changed. The other agent uses this to know
  what to re-read and, more importantly, what *not* to.

## Traffic rules (these have bitten us)

- **One writer at a time.** Commit before handing over; git is the handover.
  If you are about to edit a file the other agent may hold, say so in a message
  first and wait for the reply.
- **Corrections replace, never append** — in the workbook *and* here. If a message
  of yours turns out wrong, send a new message that says so; do not silently
  rewrite history.
- A claim that contradicts a committed result needs a re-derivation, not an
  assertion. `reality-check` / `cross-validate` exist for this.
- Scripts referenced in a message must already be committed and runnable from a
  clean checkout — relative paths only, no absolute paths to your home directory.

## Files

| path | what |
|---|---|
| `INBOX.md` | the index — the only file read every session |
| `msgs/` | open threads |
| `archive/` | closed threads (kept: they are the project's decision record) |
| `hx.sh` | `list` / `mine` / `new` / `reply` / `thread` / `close` / `reindex` — so nobody has to recall the format |

`reindex` rebuilds every open `INBOX.md` row from the messages themselves. Run it
after filling in a `MODEL:` by hand, or any time the index and the messages
disagree — the messages win. It leaves the closed-threads table alone.

Message id = `YYYY-MM-DD-NN`; filename = `<id>-<from>-to-<to>-<slug>.md`.

**The `THREAD:` front-matter field is what defines a thread — never the filename.**
To see one, run `bash handoff/hx.sh thread <slug>`, not `ls msgs/ | grep <slug>`:
a filename match also catches every *other* thread whose slug happens to end in
the same text (`z11` would drag in `delta-z11`), and `close` acting on that match
would archive an unrelated live thread.
