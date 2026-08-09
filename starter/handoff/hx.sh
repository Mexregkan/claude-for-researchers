#!/bin/bash
# handoff/hx.sh -- the Claude <-> Codex mailbox helper.
# Usage:
#   bash handoff/hx.sh list                     open threads (default)
#   bash handoff/hx.sh mine <agent>             open threads addressed to <agent>
#   bash handoff/hx.sh new <to> "<subj>" -b <bodyfile> [-t thread]
#   bash handoff/hx.sh reply <id> ["<subj>"] -b <bodyfile>
#   bash handoff/hx.sh thread <slug>            list one thread
#   bash handoff/hx.sh close <id|slug>          archive a thread, mark CLOSED
#   bash handoff/hx.sh lint                     FAIL on unfilled/oversized messages
# A BODY IS MANDATORY. -b <file> supplies it; --stub explicitly opts into an
# empty template you must fill in by hand (lint will fail until you do).
# Unknown or extra arguments are a hard error -- never silently ignored.
# Portable: bash 3.2 (macOS), no GNU-only flags.

set -u
# Resolve the script path BEFORE cd'ing: usage() reads its own header, and with
# a relative $0 (the normal "bash handoff/hx.sh ...") that read fails silently
# after the cd, so the help text could never print.
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
# Remember where the CALLER was. We cd into handoff/ below, so a relative path
# the user typed (notably -b body.md, written from the repo root) would
# otherwise be looked up inside handoff/ -- failing confusingly, or worse,
# silently picking up a same-named file that happens to live there.
ORIGIN_PWD="$PWD"
cd "$(dirname "$0")"
INBOX="INBOX.md"
TODAY="$(date +%Y-%m-%d)"
MAXLINES=100

usage() { sed -n '2,14p' "$SELF" | sed 's/^# \{0,1\}//'; exit 1; }
die() { echo "hx: $*" >&2; exit 1; }
# a caller-supplied path, resolved against the caller's directory (see ORIGIN_PWD)
resolve_path() { case "$1" in /*) echo "$1" ;; *) echo "$ORIGIN_PWD/$1" ;; esac; }

# --- identities: agent key + the MODEL behind it -----------------------------
# "claude" and "codex" are the CLI, not the model, and the model is what a
# reader needs in order to weigh a claim a year from now. So every FROM/TO is
# written as "<key> (<model>)".  The KEY (first word) is what routing matches
# on; the parenthesised model is for humans. Change a model in ONE place here.
CLAUDE_MODEL="${HX_CLAUDE_MODEL:-Opus 5}"
CODEX_MODEL="${HX_CODEX_MODEL:-ChatGPT Sol 5.6}"

identity_of() {
  case "$1" in
    claude) echo "claude ($CLAUDE_MODEL)" ;;
    codex)  echo "codex ($CODEX_MODEL)" ;;
    *)      echo "$1" ;;
  esac
}
# first word of an identity -> the routing key ("claude (Opus 5)" -> "claude")
agent_key() { echo "$1" | awk '{print $1}'; }

# --- who am I talking to / as ------------------------------------------------
# If the caller does not say, guess from the environment: Claude Code sets
# CLAUDECODE=1. Otherwise assume codex. Override with HX_FROM=<name>.
whoami_agent() {
  if [ -n "${HX_FROM:-}" ]; then agent_key "$HX_FROM"
  elif [ -n "${CLAUDECODE:-}" ]; then echo "claude"
  else echo "codex"; fi
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
    # every field from the front matter, never from the filename -- the two can
    # legitimately diverge, and trusting the filename is what broke `close`.
    id=$(field "$f" ID); from=$(field "$f" FROM); to=$(field "$f" TO)
    st=$(field "$f" STATUS); vd=$(field "$f" VERDICT); sub=$(field "$f" SUBJECT)
    printf '  %s  %-26s -> %-26s  %-9s %-10s %s\n' "$id" "$from" "$to" "$st" "$vd" "$sub"
  done
}

cmd_mine() {
  who=$(agent_key "${1:-$(whoami_agent)}")
  echo "== open threads addressed to '$(identity_of "$who")' =="
  hit=0
  for f in msgs/*.md; do
    [ -e "$f" ] || continue
    to=$(agent_key "$(grep -m1 '^TO:' "$f" | sed 's/^TO: *//')")
    st=$(grep -m1 '^STATUS:' "$f" | sed 's/^STATUS: *//')
    if [ "$to" = "$who" ] && [ "$st" = "OPEN" ]; then
      echo "  $f"; hit=1
    fi
  done
  [ "$hit" = 0 ] && echo "  (none -- nothing needs your attention)"
  return 0
}

write_head() {  # $1=path $2=id $3=from-key $4=to-key $5=subject $6=thread-slug
  cat > "$1" <<EOF
ID: $2
FROM: $(identity_of "$3")
TO: $(identity_of "$4")
DATE: $TODAY
SUBJECT: $5
THREAD: $6
STATUS: OPEN
EOF
}

stub_body() {  # $1=path -- appended after the header
  cat >> "$1" <<'EOF'
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

# Append a body file. If it starts with "VERDICT:" it is used verbatim; else a
# VERDICT placeholder is prepended so lint catches a missing verdict.
append_body() {  # $1=path $2=bodyfile
  [ -f "$2" ] || die "body file not found: $2"
  [ -s "$2" ] || die "body file is empty: $2"
  grep -q '^VERDICT:' "$2" || printf 'VERDICT: <CONFIRMED|CORRECTED|REFUTED|FYI|ASK>\n\n' >> "$1"
  cat "$2" >> "$1"
}

# --- lint: the backstop. A message that is still a template, or over the line
# --- cap, is a FAILURE. Run it before committing and from the Stop hook.
#
# Placeholders are matched as EXACT FIXED STRINGS from the template above, not
# by a "starts with '<'" heuristic: real message bodies are full of bra-ket
# notation like <e1|M|v> and of "<=", and a crude rule flags those as stubs.
# (It did, on three good messages, the first time this was written.)
PLACEHOLDERS='VERDICT: <CONFIRMED|CORRECTED|REFUTED|FYI|ASK>
<one or two sentences -- the answer first, not the build-up>
<what you checked, AND what the check does NOT cover.
 A gate whose scope is unstated is not evidence -- see README.>
<files you changed; "none" if none>
<the specific action, or "nothing -- FYI">'

cmd_lint() {
  bad=0; n=0
  for f in msgs/*.md; do
    [ -e "$f" ] || continue
    n=$((n + 1))
    ph=$(printf '%s\n' "$PLACEHOLDERS" | grep -F -x -f - "$f" 2>/dev/null | wc -l | tr -d ' ')
    ln=$(wc -l < "$f" | tr -d ' ')
    # Body = non-blank lines that are not front matter. Do NOT anchor on the
    # STATUS: line: older messages predate that field, and anchoring on it
    # reported a perfectly good 53-line message as having a 0-line body.
    bl=$(awk '!/^[A-Z][A-Z]*: / && NF {n++} END{print n+0}' "$f")
    if [ "${ph:-0}" -gt 0 ]; then
      echo "FAIL $f -- $ph unfilled template placeholder line(s); this message is a STUB"; bad=1
    fi
    if [ "$bl" -lt 6 ]; then
      echo "FAIL $f -- body is only $bl content line(s); that is not a message"; bad=1
    fi
    if [ "$ln" -gt "$MAXLINES" ]; then
      echo "FAIL $f -- $ln lines, cap is $MAXLINES"; bad=1
    fi
  done
  if [ "$bad" = 0 ]; then
    echo "hx lint: $n open message(s), all filled in and within the $MAXLINES-line cap."
  else
    echo ""
    echo "An unfilled message is worse than no message: the other agent opens a blank"
    echo "template and the thread stalls. Fill it in, then re-run 'hx.sh lint'."
    exit 1
  fi
}

add_row() {  # $1=id $2=from-key $3=to-key $4=subject -- insert ABOVE the HX:ROWS marker
  row=$(printf '| %s | %s -> %s | OPEN | %s |' "$1" "$(identity_of "$2")" "$(identity_of "$3")" "$4")
  tmp=$(mktemp)
  # write BACK into INBOX.md rather than mv-ing the temp file over it: mktemp
  # creates mode 600, and a mv would silently make the index owner-only.
  awk -v r="$row" '/^<!-- HX:ROWS/ { print r } { print }' "$INBOX" > "$tmp" \
    && cat "$tmp" > "$INBOX"
  rm -f "$tmp"
}

# Shared option parser for new/reply. Sets BODY, THREADOPT, STUB and leaves the
# remaining positional arguments in POSN1/POSN2. ANY unrecognised argument is
# fatal -- silently dropping one is exactly how an empty template got sent.
BODY=""; THREADOPT=""; STUB=0; POSN1=""; POSN2=""
parse_opts() {
  np=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -b|--body)   [ $# -ge 2 ] || die "$1 needs a file"; BODY="$2"; shift 2 ;;
      -t|--thread) [ $# -ge 2 ] || die "$1 needs a slug"; THREADOPT="$2"; shift 2 ;;
      --stub)      STUB=1; shift ;;
      -*)          die "unknown option '$1'" ;;
      *)
        np=$((np + 1))
        case "$np" in
          1) POSN1="$1" ;;
          2) POSN2="$1" ;;
          *) die "unexpected extra argument '$1'. A body file goes after -b, not as a bare argument." ;;
        esac
        shift ;;
    esac
  done
}

# Validate BEFORE anything is created: an aborted run must leave no half-made
# message and no INBOX row behind.
require_body() {  # $1 = the subcommand name, for the message
  if [ -n "$BODY" ]; then
    typed="$BODY"; BODY=$(resolve_path "$BODY")   # relative to where YOU ran hx.sh
    [ -f "$BODY" ] || die "body file not found: $typed  (nothing was created)"
    [ -s "$BODY" ] || die "body file is empty: $typed  (nothing was created)"
    return 0
  fi
  [ "$STUB" = 1 ] && return 0
  die "no body. Write the message body to a file and pass it with -b <file>:
      bash handoff/hx.sh $1 ... -b /path/to/body.md
  A body is MANDATORY. If you really want an empty template to fill in by hand,
  pass --stub explicitly -- but 'hx.sh lint' will FAIL until you fill it in."
}

finish_msg() {  # $1=path
  if [ "$STUB" = 1 ] && [ -z "$BODY" ]; then
    stub_body "$1"
    echo "  !! STUB written. It is NOT sendable: fill it in, then run 'bash handoff/hx.sh lint'."
  else
    append_body "$1" "$BODY"
    lc=$(wc -l < "$1" | tr -d ' ')
    echo "  body from $BODY -- $lc lines (cap $MAXLINES)"
    [ "$lc" -gt "$MAXLINES" ] && echo "  !! OVER THE CAP by $((lc - MAXLINES)) lines. Trim it; 'hx.sh lint' will fail."
  fi
  return 0
}

cmd_new() {
  parse_opts "$@"
  to=$(agent_key "$POSN1"); sub="$POSN2"
  { [ -z "$to" ] || [ -z "$sub" ]; } && usage
  require_body new
  from=$(whoami_agent); id=$(next_id)
  # thread slug: explicit -t wins, else derived from the subject. The filename
  # is built from the THREAD slug so the two can never disagree.
  if [ -n "$THREADOPT" ]; then slug=$(slugify "$THREADOPT"); else slug=$(slugify "$sub"); fi
  f="msgs/${id}-${from}-to-${to}-${slug}.md"
  write_head "$f" "$id" "$from" "$to" "$sub" "$slug"
  finish_msg "$f"
  add_row "$id" "$from" "$to" "$sub"
  echo "created $f"
}

cmd_reply() {
  parse_opts "$@"
  rid="$POSN1"; sub="$POSN2"
  [ -z "$rid" ] && usage
  src=$(find_msg "$rid")
  [ -z "$src" ] && die "no open message with id $rid"
  require_body reply
  from=$(whoami_agent)
  to=$(agent_key "$(field "$src" FROM)")
  slug=$(field "$src" THREAD)
  [ -z "$sub" ] && sub="re: $(field "$src" SUBJECT)"
  id=$(next_id)
  f="msgs/${id}-${from}-to-${to}-${slug}.md"
  write_head "$f" "$id" "$from" "$to" "$sub" "$slug"
  finish_msg "$f"
  add_row "$id" "$from" "$to" "$sub"
  echo "created $f   (thread: $slug)"
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
    printf '  %s  %-26s -> %-26s  %s\n' "$(field "$g" ID)" "$(field "$g" FROM)" \
      "$(field "$g" TO)" "$(field "$g" SUBJECT)"
  done
}

case "${1:-list}" in
  list)  cmd_list ;;
  mine)  shift; cmd_mine "${1:-}" ;;
  new)   shift; cmd_new "$@" ;;
  reply) shift; cmd_reply "$@" ;;
  thread) shift; cmd_thread "${1:-}" ;;
  close) shift; cmd_close "${1:-}" ;;
  lint)  cmd_lint ;;
  *)     usage ;;
esac
