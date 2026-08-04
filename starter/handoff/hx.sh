#!/bin/bash
# handoff/hx.sh -- the Claude <-> Codex mailbox helper.
# Usage:
#   bash handoff/hx.sh list                    open threads (default)
#   bash handoff/hx.sh mine <agent>            open threads addressed to <agent>
#   bash handoff/hx.sh new <to> "<subject>" [thread]   message stub + index row
#   bash handoff/hx.sh reply <id> ["<subject>"]        reply in the same thread
#   bash handoff/hx.sh thread <slug>                   list one thread
#   bash handoff/hx.sh close <id|slug>                 archive a thread, mark CLOSED
#   bash handoff/hx.sh reindex                         rebuild INBOX rows from front matter
#
# Say WHICH MODEL you are, not just which agent: HX_MODEL="Opus 5" hx.sh new ...
# ("codex said X" ages badly -- gpt-5.6-sol and gpt-5.6-terra are not the same
# witness, and neither are Opus 5 and Haiku 4.5.) Unset => the stub carries a
# placeholder for you to fill, and the index row shows "?" until you reindex.
# Portable: bash 3.2 (macOS), no GNU-only flags.

set -u
# Resolve our own path BEFORE cd-ing: $0 may be relative ("handoff/hx.sh"), and
# after the cd a relative $0 no longer points at this file -- which used to break
# the usage text for exactly the invocation the README documents.
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
cd "$(dirname "$0")"
INBOX="INBOX.md"
TODAY="$(date +%Y-%m-%d)"

usage() { sed -n '2,16p' "$SELF" | sed 's/^# \{0,1\}//'; exit 1; }

# --- who am I talking to / as ------------------------------------------------
# If the caller does not say, guess from the environment: Claude Code sets
# CLAUDECODE=1. Otherwise assume codex. Override with HX_FROM=<name>.
whoami_agent() {
  if [ -n "${HX_FROM:-}" ]; then echo "$HX_FROM"
  elif [ -n "${CLAUDECODE:-}" ]; then echo "claude"
  else echo "codex"; fi
}

# --- which MODEL am I? --------------------------------------------------------
# Neither CLI exports its model name, so this cannot be sniffed: either set
# HX_MODEL, or fill the MODEL: line the stub leaves you. The agent knows what it
# is running; nothing else in the repo does.
PLACEHOLDER_MODEL='<your model, e.g. Opus 5 / GPT-5.6-sol -- fill this in>'
whoami_model() {
  if [ -n "${HX_MODEL:-}" ]; then echo "$HX_MODEL"; else echo "$PLACEHOLDER_MODEL"; fi
}
# what a MODEL: value looks like in a one-line index row ("?" while unfilled)
model_label() {
  case "${1:-}" in ""|"<"*) echo "?" ;; *) echo "$1" ;; esac
}

next_id() {
  n=$(ls msgs archive 2>/dev/null | grep -c "^${TODAY}-" || true)
  printf '%s-%02d' "$TODAY" $((n + 1))
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//' | cut -c1-40 \
    | sed -e 's/-$//'
}

find_msg() { ls msgs/"$1"-*.md 2>/dev/null | head -1; }

# front-matter field reader -- the front matter is the source of truth,
# never the filename (they can legitimately diverge when a thread is renamed).
field() { grep -m1 "^$2:" "$1" | sed "s/^$2: *//"; }

# every message in msgs/ whose THREAD field equals $1
thread_files() {
  for g in msgs/*.md; do
    [ -e "$g" ] || continue
    [ "$(field "$g" THREAD)" = "$1" ] && echo "$g"
  done
  return 0
}

cmd_list() {
  echo "== open threads (handoff/msgs) =="
  if [ -z "$(ls msgs/*.md 2>/dev/null)" ]; then echo "  (none -- inbox clear)"; return; fi
  for f in msgs/*.md; do
    # read every field from the front matter -- never from the filename
    id=$(field "$f" ID); from=$(field "$f" FROM); to=$(field "$f" TO)
    st=$(field "$f" STATUS); vd=$(field "$f" VERDICT); sub=$(field "$f" SUBJECT)
    md=$(model_label "$(field "$f" MODEL)")
    printf '  %s  %-22s -> %-6s  %-9s %-10s %s\n' \
      "$id" "$from ($md)" "$to" "$st" "$vd" "$sub"
  done
}

cmd_mine() {
  who="${1:-$(whoami_agent)}"
  echo "== open threads addressed to '$who' =="
  hit=0
  for f in msgs/*.md; do
    [ -e "$f" ] || continue
    to=$(grep -m1 '^TO:' "$f" | sed 's/^TO: *//')
    st=$(grep -m1 '^STATUS:' "$f" | sed 's/^STATUS: *//')
    if [ "$to" = "$who" ] && [ "$st" = "OPEN" ]; then
      echo "  $f"; hit=1
    fi
  done
  [ "$hit" = 0 ] && echo "  (none -- nothing needs your attention)"
  return 0
}

write_stub() {  # $1=path $2=id $3=from $4=to $5=subject $6=thread-slug $7=model
  cat > "$1" <<EOF
ID: $2
FROM: $3
MODEL: $7
TO: $4
DATE: $TODAY
SUBJECT: $5
THREAD: $6
STATUS: OPEN
VERDICT: <CONFIRMED|CORRECTED|REFUTED|FYI|ASK>

## Claim
<one or two sentences -- the answer first, not the build-up>

## Gates
<what you checked, AND what the check does NOT cover.
 A gate whose scope is unstated is not evidence -- see README.>

## Touched
<files you changed; "none" if none>

## Needs from you
<the specific action, or "nothing -- FYI">
EOF
}

add_row() {  # $1=id $2=from $3=model $4=to $5=subject -- insert ABOVE the HX:ROWS marker
  row=$(printf '| %s | %s (%s) -> %s | OPEN | %s |' "$1" "$2" "$(model_label "$3")" "$4" "$5")
  tmp=$(mktemp)
  # write BACK into INBOX.md rather than mv-ing the temp file over it: mktemp
  # creates mode 600, and a mv would silently make the index owner-only.
  awk -v r="$row" '/^<!-- HX:ROWS/ { print r } { print }' "$INBOX" > "$tmp" \
    && cat "$tmp" > "$INBOX"
  rm -f "$tmp"
}

cmd_new() {
  to="${1:-}"; sub="${2:-}"; th="${3:-}"
  [ -z "$to" ] || [ -z "$sub" ] && usage
  from=$(whoami_agent); id=$(next_id)
  # thread slug: explicit 3rd arg wins, else derived from the subject. The
  # filename is built from the THREAD slug so the two can never disagree.
  if [ -n "$th" ]; then slug=$(slugify "$th"); else slug=$(slugify "$sub"); fi
  md=$(whoami_model)
  f="msgs/${id}-${from}-to-${to}-${slug}.md"
  write_stub "$f" "$id" "$from" "$to" "$sub" "$slug" "$md"
  add_row "$id" "$from" "$md" "$to" "$sub"
  echo "created $f"
  echo "  -> fill it in (40 lines max), then commit. INBOX.md row added."
  warn_model
}

# nag once, at the point of writing, where it is cheap to fix
warn_model() {
  [ -n "${HX_MODEL:-}" ] && return 0
  echo "  !! MODEL: is a placeholder -- say which model you are (e.g. Opus 5,"
  echo "     GPT-5.6-sol), then run 'bash handoff/hx.sh reindex' to fix the row."
  return 0
}

cmd_reply() {
  rid="${1:-}"; sub="${2:-}"
  [ -z "$rid" ] && usage
  src=$(find_msg "$rid")
  [ -z "$src" ] && { echo "no open message with id $rid"; exit 1; }
  from=$(whoami_agent)
  to=$(field "$src" FROM)
  slug=$(field "$src" THREAD)
  [ -z "$sub" ] && sub="re: $(field "$src" SUBJECT)"
  id=$(next_id); md=$(whoami_model)
  f="msgs/${id}-${from}-to-${to}-${slug}.md"
  write_stub "$f" "$id" "$from" "$to" "$sub" "$slug" "$md"
  add_row "$id" "$from" "$md" "$to" "$sub"
  echo "created $f   (thread: $slug)"
  warn_model
}

cmd_close() {
  key="${1:-}"; [ -z "$key" ] && usage
  # accept either a message id or a thread slug
  f=$(find_msg "$key")
  if [ -n "$f" ]; then slug=$(field "$f" THREAD); else slug="$key"; fi
  files=$(thread_files "$slug")
  [ -z "$files" ] && { echo "no open messages in thread '$slug'"; exit 1; }
  n=0
  for g in $files; do
    tid=$(field "$g" ID)
    sed -i '' 's/^STATUS: .*/STATUS: CLOSED/' "$g" 2>/dev/null || sed -i 's/^STATUS: .*/STATUS: CLOSED/' "$g"
    git mv "$g" archive/ 2>/dev/null || mv "$g" archive/
    # drop this message's row using its ID field, not a parsed filename
    tmp=$(mktemp); grep -v "^| ${tid} " "$INBOX" > "$tmp" && cat "$tmp" > "$INBOX"
    rm -f "$tmp"
    n=$((n + 1))
  done
  echo "closed thread '$slug' ($n message(s) archived); all its INBOX rows removed."
  echo "  Now add a one-line outcome to the 'Closed threads' table in INBOX.md."
}

cmd_thread() {
  slug="${1:-}"; [ -z "$slug" ] && usage
  echo "== thread '$slug' =="
  files=$(thread_files "$slug")
  [ -z "$files" ] && { echo "  (no open messages; check archive/)"; return 0; }
  for g in $files; do
    printf '  %s  %-22s -> %-6s  %s\n' "$(field "$g" ID)" \
      "$(field "$g" FROM) ($(model_label "$(field "$g" MODEL)"))" \
      "$(field "$g" TO)" "$(field "$g" SUBJECT)"
  done
}

# Rebuild every open row from the messages themselves. Run it after filling in a
# MODEL: by hand, or any time you suspect the index and the messages disagree --
# the messages win, always.
cmd_reindex() {
  tmp=$(mktemp)
  grep -v '^| [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9] ' "$INBOX" > "$tmp" \
    && cat "$tmp" > "$INBOX"
  rm -f "$tmp"
  n=0
  for g in msgs/*.md; do
    [ -e "$g" ] || continue
    add_row "$(field "$g" ID)" "$(field "$g" FROM)" "$(field "$g" MODEL)" \
            "$(field "$g" TO)" "$(field "$g" SUBJECT)"
    n=$((n + 1))
  done
  echo "reindexed: $n open message(s); INBOX rows rebuilt from front matter."
}

case "${1:-list}" in
  list)  cmd_list ;;
  mine)  shift; cmd_mine "${1:-}" ;;
  new)   shift; cmd_new "${1:-}" "${2:-}" "${3:-}" ;;
  reply) shift; cmd_reply "${1:-}" "${2:-}" ;;
  thread) shift; cmd_thread "${1:-}" ;;
  reindex) cmd_reindex ;;
  close) shift; cmd_close "${1:-}" ;;
  *)     usage ;;
esac
