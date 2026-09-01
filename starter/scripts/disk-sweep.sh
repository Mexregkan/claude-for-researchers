#!/usr/bin/env bash
# disk-sweep.sh — reclaim disk from regenerable caches and run artifacts.
#
# WHY A RESEARCH PROJECT NEEDS THIS. Symbolic computation generates enormous intermediate
# files, and the ones that matter look exactly like the ones that don't: a 2 GB `.m` proof
# object you must keep sits next to a 2 GB `.m` scratch dump you must not. Deleting by
# extension, size or age will eventually delete a result. So this script does not decide
# what is precious — it asks git.
#
# ── THE SAFETY CONTRACT ───────────────────────────────────────────────────────────────
#
#   1. DRY RUN BY DEFAULT. Nothing is deleted without --apply.
#   2. Inside a git repo it only ever considers files git itself calls disposable:
#          git ls-files --others --ignored --exclude-standard
#      (untracked AND ignored). A TRACKED FILE CAN NEVER BE SELECTED, so anything you
#      committed is structurally safe — not safe by a rule someone remembered to write,
#      safe because it cannot reach the candidate list.
#   3. Research data is REPORTED, never deleted. See the `dupes` section, which only ever
#      prints and tells you how to confirm before you act yourself.
#
#   The corollary is the thing to internalise: **`.gitignore` is your delete list.** If a
#   heavy generated file is precious, commit it or un-ignore it. If it is disposable, make
#   sure it IS ignored. That one file then drives both git and this script, and the two can
#   never disagree.
#
# ── SETUP: point it at your projects ─────────────────────────────────────────────────
#
# Edit the PROJECTS array below (or set DISK_SWEEP_PROJECTS to a colon-separated list).
# List each git repo separately, including nested ones — a nested repo is invisible to its
# parent's `git ls-files`, so an unlisted nested repo is simply never swept.
#
# ── USAGE ────────────────────────────────────────────────────────────────────────────
#
#   disk-sweep.sh                                  # dry run: show what would go
#   disk-sweep.sh --apply                          # delete it
#   disk-sweep.sh --days 30 --only run-logs        # one section, older than 30 days
#   disk-sweep.sh --only dupes                     # report big duplicates, delete nothing
#
# To run it weekly, see the toolkit README, "Long runs leave things behind" — and rotate
# the log, or your cleanup tool becomes a disk-growth source of its own.

set -uo pipefail

# ── FILL THIS IN: the git repos to sweep (absolute paths; list nested repos separately) ──
PROJECTS=(
  "$HOME/path/to/your-project"
  # "$HOME/path/to/your-project/nested-repo"
)
# Override without editing the file: DISK_SWEEP_PROJECTS="/a:/b" disk-sweep.sh
if [ -n "${DISK_SWEEP_PROJECTS:-}" ]; then
  IFS=':' read -ra PROJECTS <<< "$DISK_SWEEP_PROJECTS"
fi
# Where the `dupes` report looks for big files.
DUPES_ROOT="${DISK_SWEEP_DUPES_ROOT:-$HOME}"

APPLY=0
DAYS=14
declare -a ONLY=()

usage() {
  cat <<'EOF'
disk-sweep.sh [--apply] [--days N] [--only sect,sect]

  --apply       actually delete (default: dry run, prints what it would do)
  --days N      age threshold for logs/temp files (default 14)
  --only LIST   run only these sections (comma-separated)

Sections:
  latex-aux         gitignored LaTeX aux files (.aux .log .out .toc .bbl .blg .synctex.gz)
  run-logs          gitignored *.log run artifacts older than --days
  engine-scratch    gitignored generated data (*.mx *.wdx *.npy *.npz) older than --days
  wolfram-docs      Mathematica doc paclets for NON-current versions        [macOS]
  wolfram-temp      stale .paclet downloads in Paclets/Temporary            [macOS]
  wolfram-chatbook  Chatbook vector DBs                    [opt-in: only when named]
  dupes             REPORT ONLY: large duplicate-sized files (never deletes)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --days)  DAYS="${2:?--days needs a number}"; shift 2 ;;
    --only)  IFS=',' read -ra ONLY <<< "${2:?--only needs a list}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

OPT_IN="wolfram-chatbook"     # sections that run only when explicitly named

want() {
  local s="$1"
  if [ ${#ONLY[@]} -gt 0 ]; then
    for o in "${ONLY[@]}"; do [ "$o" = "$s" ] && return 0; done
    return 1
  fi
  [[ " $OPT_IN " == *" $s "* ]] && return 1
  return 0
}

TOTAL=0
human()   { awk -v b="$1" 'BEGIN{split("B KB MB GB TB",u," ");i=1;while(b>=1024&&i<5){b/=1024;i++}printf "%.1f %s",b,u[i]}'; }
size_of() { [ -e "$1" ] && du -sk "$1" 2>/dev/null | cut -f1 | awk '{print $1*1024}' || echo 0; }
section() { printf "\n== %s ==\n" "$1"; }

remove() {
  local p="$1" label="${2:-}" sz
  [ -e "$p" ] || return 0
  sz=$(size_of "$p")
  TOTAL=$((TOTAL + sz))
  if [ "$APPLY" = 1 ]; then
    rm -rf -- "$p" && printf "  deleted  %10s  %s %s\n" "$(human "$sz")" "$p" "$label"
  else
    printf "  would rm %10s  %s %s\n" "$(human "$sz")" "$p" "$label"
  fi
}

# sweep_repo <repo> <glob> [find-args...] — ONLY files git calls disposable.
# Sets SWEPT to the number of files acted on (a count, not an exit status: a return value
# above 255 would wrap, and these globs can match thousands of files).
SWEPT=0
sweep_repo() {
  local repo="$1" glob="$2"; shift 2
  SWEPT=0
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || return 0
  while IFS= read -r -d '' rel; do
    local f="$repo/$rel"
    [ -f "$f" ] || continue
    if [ $# -gt 0 ] && ! find "$f" "$@" -print -quit 2>/dev/null | grep -q .; then
      continue
    fi
    remove "$f"; SWEPT=$((SWEPT+1))
  done < <(git -C "$repo" ls-files -z --others --ignored --exclude-standard -- "$glob" 2>/dev/null)
}

# sweep_all <days-filter:0|1> <glob>... — sets HIT=1 if anything was acted on.
# NOT called in a command substitution: that would run it in a subshell, where both the
# "would rm" lines and the running byte TOTAL are silently lost.
HIT=0
sweep_all() {
  local mt=$1; shift
  HIT=0
  for repo in "${PROJECTS[@]}"; do
    [ -d "$repo" ] || continue
    for g in "$@"; do
      if [ "$mt" = 1 ]; then sweep_repo "$repo" "$g" -mtime "+$DAYS"; else sweep_repo "$repo" "$g"; fi
      [ "$SWEPT" -gt 0 ] && HIT=1
    done
  done
}

if want latex-aux; then
  section "latex-aux — gitignored LaTeX aux files (regenerated by recompiling)"
  sweep_all 0 '*.aux' '*.out' '*.toc' '*.bbl' '*.blg' '*.synctex.gz'
  [ "$HIT" = 0 ] && echo "  nothing to remove"
fi

if want run-logs; then
  section "run-logs — gitignored *.log run artifacts older than ${DAYS}d"
  sweep_all 1 '*.log'
  [ "$HIT" = 0 ] && echo "  nothing older than ${DAYS}d"
fi

if want engine-scratch; then
  section "engine-scratch — gitignored generated data older than ${DAYS}d"
  echo "  (only files your .gitignore already marks disposable — commit anything precious)"
  sweep_all 1 '*.mx' '*.wdx' '*.npy' '*.npz'
  [ "$HIT" = 0 ] && echo "  nothing older than ${DAYS}d"
fi

if want wolfram-docs; then
  section "wolfram-docs — doc paclets for non-current Mathematica versions"
  REPO="$HOME/Library/Wolfram/Paclets/Repository"
  CUR=$(defaults read /Applications/Wolfram.app/Contents/Info.plist \
          CFBundleShortVersionString 2>/dev/null | cut -d. -f1,2)
  if [ -z "$CUR" ]; then echo "  SKIP: could not read the installed Wolfram version (macOS only)"
  elif [ ! -d "$REPO" ]; then echo "  SKIP: no paclet repository"
  else
    echo "  installed version: $CUR — keeping its docs, removing older"
    found=0
    for d in "$REPO"/SystemDocsUpdate*-*; do
      [ -d "$d" ] || continue
      v=$(basename "$d" | sed 's/.*-//' | cut -d. -f1,2)
      [ "$v" != "$CUR" ] && { remove "$d" "(v$v)"; found=1; }
    done
    [ "$found" = 0 ] && echo "  nothing stale"
  fi
fi

if want wolfram-temp; then
  section "wolfram-temp — stale .paclet downloads"
  TMPD="$HOME/Library/Wolfram/Paclets/Temporary"
  if [ -d "$TMPD" ]; then
    n=0
    while IFS= read -r f; do remove "$f"; n=$((n+1)); done \
      < <(find "$TMPD" -type f -name '*.paclet' -mtime "+$DAYS" 2>/dev/null)
    [ "$n" = 0 ] && echo "  nothing older than ${DAYS}d"
  else echo "  SKIP: no Temporary dir"; fi
fi

if want wolfram-chatbook; then
  section "wolfram-chatbook — Chatbook vector databases (regenerated on demand)"
  remove "$HOME/Library/Wolfram/Objects/Chatbook/VectorDatabases"
fi

if want dupes; then
  section "dupes — REPORT ONLY (nothing here is ever deleted)"
  echo "  scanning $DUPES_ROOT for files >1GB with an identical-size twin..."
  find "$DUPES_ROOT" -type f -size +1G 2>/dev/null \
    | while IFS= read -r f; do printf "%s\t%s\n" "$(wc -c < "$f" | tr -d ' ')" "$f"; done \
    | sort -rn | awk -F'\t' '
        { if ($1 == prev) { if (!shown[$1]++) print "\n  size " $1 ":\n    " prevf; print "    " $2 }
          prev=$1; prevf=$2 }
        END { if (!NR) print "  none" }'
  echo
  echo "  Identical size is only a HINT — never evidence. Confirm before acting:"
  echo "    cmp <a> <b> && echo IDENTICAL"
fi

printf "\nTotal: %s" "$(human "$TOTAL")"
if [ "$APPLY" = 1 ]; then echo " reclaimed."; else echo " reclaimable — re-run with --apply to delete."; fi
