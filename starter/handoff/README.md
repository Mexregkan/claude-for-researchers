# `handoff/` — the agent mailbox

Two agents, one repo, no shared memory. This folder is how they talk. Read this
file **once**; after that you only ever read `INBOX.md`.

## The whole protocol in six lines

1. **At session start, read `handoff/INBOX.md` and nothing else here.** It is one
   line per thread. If no row is `OPEN` and addressed to you, you are done —
   cost: ~15 lines.
2. Open a message only if its row says `OPEN` and `→ you`.
3. To say something: **write the body to a file first**, then
   `bash handoff/hx.sh new <to> "<subject>" -b <bodyfile>` (or
   `reply <id> -b <bodyfile>`). The script writes the message *and* the
   `INBOX.md` row. Never hand-edit the index. Add `-t <thread-slug>` to join an
   existing thread under a different subject.
   **A body is mandatory** — `hx.sh` refuses to create a body-less message, and
   unknown or extra arguments are a hard error rather than being ignored. Both
   rules exist because a body file passed as a bare extra argument was once
   silently dropped, and the message went out as a blank template.
   `--stub` explicitly opts into an empty template to fill in by hand.
   **Run `bash handoff/hx.sh lint` before committing** — it fails on unfilled
   placeholders, on a body under 6 content lines, and over the 100-line cap.
   Wire it into your Stop hook too, so a stub left behind is caught at session end.
4. **Never edit another agent's message.** Reply with `hx.sh reply <id>`; the
   script keeps the thread slug. (Editing in place is ambiguous — is it a
   correction, a reply, or agreement? — and the other side may never notice.)
5. When a thread is settled: `bash handoff/hx.sh close <id|slug>`. It moves every
   message of that thread to `archive/` and clears their rows from the index.
6. **100 lines max per message.** Detail still goes in the workbook /
   `CHANGELOG.md` — the message carries the verdict, its gates *including what
   they do not cover*, and a pointer, never a derivation. The cap exists to stop
   a message becoming a write-up, not to force compression of substance: if the
   gates and their limitations need the room, take it. (This started at 40 and
   was raised twice, in real use, after rounds of genuine content had to be
   squeezed to fit. Tune it in `MAXLINES` at the top of `hx.sh`.)

## Who is speaking: the identity carries the model

`claude` and `codex` name the *CLI*, not the thing that did the reasoning, and a
year from now the model is what a reader needs in order to weigh a claim. So
every `FROM:`/`TO:` is written:

```
FROM: claude (Opus 5)
TO:   codex (ChatGPT Sol 5.6)
```

The **first word is the routing key** — `hx.sh mine claude`, replies, filenames
and archiving all match on it — and the parenthesised model is for humans.
`hx.sh` expands the key automatically, so you still type `hx.sh new codex "…"`.
Both model strings live in **one place**, the two variables at the top of
`hx.sh`; when you switch model, edit them there (or override per run with
`HX_CLAUDE_MODEL` / `HX_CODEX_MODEL`) and never hand-type an identity into a
message. Filenames stay keyed (`…-claude-to-codex-…`) so they remain short and
greppable.

If you adopt this on a mailbox that already has messages, rewriting the old
`FROM:`/`TO:` headers and `INBOX.md` rows in one pass is fine — that is a schema
migration of the *headers*, touching no claim, verdict or gate, and it is the one
exception to "never edit the other agent's message". Say so in a message, and let
git hold the before/after.

## What a message must contain

The stub gives you the shape: front matter, then four sections. Three parts are
load-bearing:

- **`VERDICT:`** (front matter) — one of `CONFIRMED` / `CORRECTED` / `REFUTED` /
  `FYI` / `ASK`. Put the answer in the first line, not the last. If your body
  file does not start with a `VERDICT:` line, `hx.sh` prepends a placeholder —
  which `lint` then fails on, so a missing verdict cannot slip through.
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
| `hx.sh` | `list` / `mine` / `new` / `reply` / `thread` / `close` / `lint` — so nobody has to recall the format |

Message id = `YYYY-MM-DD-NN`; filename = `<id>-<from>-to-<to>-<slug>.md`.

**The `THREAD:` front-matter field is what defines a thread — never the filename.**
To see one, run `bash handoff/hx.sh thread <slug>`, not `ls msgs/ | grep <slug>`:
a filename match also catches every *other* thread whose slug happens to end in
the same text (`z11` would drag in `delta-z11`), and `close` acting on that match
would archive an unrelated live thread.

Paths you pass to `-b` are resolved against the directory you ran `hx.sh` *from*,
not against `handoff/`, so `-b body.md` works from the repo root.
