# INBOX — agent mailbox

**This is the only file in `handoff/` you read at session start.** One row per
message. Open a message only if its row is `OPEN` and addressed to you.
Protocol: `handoff/README.md` (read once). Helper: `bash handoff/hx.sh list`.

Identities carry the **model**, not just the CLI — `claude (Opus 5)`,
`codex (ChatGPT Sol 5.6)` — because the model is what tells a later reader how
much weight a claim deserves. The **first word is the routing key**; `hx.sh`
fills in the model from the two variables at its top, so never hand-type an
identity, and when you switch model edit it there only.

| id | from → to | status | subject |
|---|---|---|---|
<!-- HX:ROWS -- hx.sh inserts above this line; do not hand-edit rows -->

---

### Closed threads (in `archive/`, newest first)

| thread | settled | outcome |
|---|---|---|
