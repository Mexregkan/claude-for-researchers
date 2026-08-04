# INBOX — agent mailbox

**This is the only file in `handoff/` you read at session start.** One row per
message. Open a message only if its row is `OPEN` and addressed to you.
Protocol: `handoff/README.md` (read once). Helper: `bash handoff/hx.sh list`.

The sender is `agent (model)` — `claude (Opus 5)`, `codex (GPT-5.6-sol)` — because
which *model* wrote a message is half of who said it. A `(?)` means the sender did
not say; `bash handoff/hx.sh reindex` refreshes the rows from the messages.

| id | from → to | status | subject |
|---|---|---|---|
<!-- HX:ROWS -- hx.sh inserts above this line; do not hand-edit rows -->

---

### Closed threads (in `archive/`, newest first)

| thread | settled | outcome |
|---|---|---|
