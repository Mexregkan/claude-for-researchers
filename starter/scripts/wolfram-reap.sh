#!/usr/bin/env bash
# wolfram-reap.sh — kill headless Wolfram batch runs that have PROVABLY FINISHED
#                   but never exited.
#
# THE PATHOLOGY. A `wolframscript -file job.wls` writes its results, its counters and its
# done-line — and then keeps running at 100% of a core, indefinitely. Nothing in the log
# looks wrong; the mathematics is over and correct. The process simply never comes down.
# One measured instance burned 40.7 CPU-hours after its work finished, and was noticed
# only because the laptop was hot.
#
# Two things it also breaks, both silent:
#   (i)  a runner script that blocks on `wolframscript` never reaches its own gate block,
#        so THE RUNNER'S VERDICT IS NEVER PRINTED — you read the raw log instead and
#        assume the runner agreed with you;
#   (ii) the process gets reparented to init/launchd, so it survives the terminal, the
#        session and the agent that started it, and is invisible to any per-session check.
#
# ── THE SAFETY RULE, and why this is safe by construction ────────────────────────────
#
#   A process is reaped ONLY if its log proves the script reached its end: a completion
#   marker the script itself printed AFTER all its work. A computation still working has
#   no such marker, so it is untouchable no matter how long it has run or how much CPU it
#   is using.
#
#   ⚠ ELAPSED TIME AND CPU LOAD ARE NEVER USED AS EVIDENCE. Legitimate research runs are
#   silent for hours; a staleness rule would kill live work, which is the one outcome
#   worse than a wasted core. If you remember one thing from this script, remember that.
#
#   Failure mode is SAFE: if your scripts print no completion marker, this reaps nothing.
#
# ── WHAT YOU MUST SET ────────────────────────────────────────────────────────────────
#
# By default this looks for a terminal line containing "done" (or "DONE") that names the
# script. If your scripts print something more specific — a gate counter, a summary line —
# add it, because a marker you print only after every check has run is stronger evidence:
#
#   export WOLFRAM_REAP_DONE_RE='^ *PASSES = [0-9]+'      # e.g. a gate counter
#
# Set it in your shell profile, or edit DEFAULT_DONE_RE below.
#
# ── USAGE ────────────────────────────────────────────────────────────────────────────
#
#   wolfram-reap.sh              # dry run: report only, change nothing
#   wolfram-reap.sh --apply      # actually kill what is provably finished
#   wolfram-reap.sh --quiet      # for hooks/schedulers: print ONLY when something is reaped
#
# Install it on your PATH (e.g. ~/.local/bin/wolfram-reap) and wire it up two ways —
# see the toolkit README, "Long runs leave things behind":
#   * a Stop hook, so it runs when an agent finishes a turn;
#   * a scheduled job every ~30 min, for runs left going after you close the session.
#
# THE REAL FIX IS UPSTREAM: end your .wls scripts with `Quit[]` after the done-line, and
# check that the runner's gate block actually printed. A done-line in the log is not
# evidence that the runner returned. This script is the safety net, not the cure.

set -uo pipefail

DEFAULT_DONE_RE=''            # optional extra marker; see WOLFRAM_REAP_DONE_RE above
DONE_RE="${WOLFRAM_REAP_DONE_RE:-$DEFAULT_DONE_RE}"

APPLY=0; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,50p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

# In --quiet mode (hooks, schedulers) the commentary is buffered and printed ONLY if
# something was actually reaped: killing a process must never be silent, but a scan that
# finds nothing must never be noise.
BUF=""
say()   { if [ "$QUIET" = 1 ]; then BUF="$BUF$*\n"; else printf '%s\n' "$*"; fi; }
flush() { [ -n "$BUF" ] && printf '%b' "$BUF"; BUF=""; }

# Never touch these, even if one somehow reaches the candidate list: interactive kernels,
# the front end, editor language servers, MCP/agent kernels, and WSTP subkernels. Killing
# one of those destroys unsaved work belonging to you or to another agent.
PROTECTED='LSPServer|MathematicaServer|AgentTools|StartMCPServer|-wstp|-linkconnect|-linkname|WolframNB|Wolfram\.app/Contents/MacOS/Wolfram( |$)|Mathematica\.app'

# completed <log> <base> — does the log PROVE the script ran to the end?
completed() {
  local log="$1" base="$2"
  [ -f "$log" ] || return 1
  # (a) a user-supplied marker, printed after all work
  if [ -n "$DONE_RE" ] && grep -qE "$DONE_RE" "$log"; then return 0; fi
  # (b) a terminal done-line naming the script (last 5 non-blank lines only, so a "done"
  #     appearing early in a long log cannot be mistaken for the end)
  local pat; pat=$(printf '%s' "$base" | sed 's/[-_]/[-_]/g')
  grep -v '^[[:space:]]*$' "$log" | tail -5 | grep -qiE "done.*$pat|$pat.*done" && return 0
  return 1
}

reaped=0; left=0; found=0

while IFS= read -r line; do
  [ -n "$line" ] || continue
  pid=$( printf '%s' "$line" | awk '{print $1}')
  ppid=$(printf '%s' "$line" | awk '{print $2}')
  pcpu=$(printf '%s' "$line" | awk '{print $3}')
  et=$(  printf '%s' "$line" | awk '{print $4}')
  cmd=$( printf '%s' "$line" | cut -d' ' -f5-)

  printf '%s' "$cmd" | grep -qE "$PROTECTED" && continue
  printf '%s' "$cmd" | grep -qE 'wolframscript .*-file' || continue    # batch jobs only
  found=$((found+1))

  script=$(printf '%s' "$cmd" | sed -nE 's/.*-file[[:space:]]+([^[:space:]]+).*/\1/p')
  script=${script%\"}; script=${script#\"}          # tolerate a quoted path
  script=${script%\'}; script=${script#\'}
  base=$(basename "$script" .wls)
  cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)
  log="${cwd:-.}/$base.log"

  if completed "$log" "$base"; then
    say "  FINISHED-BUT-ALIVE  pid=$pid  cpu=${pcpu}%  elapsed=$et"
    say "      script : $base"
    say "      proof  : $log says the run reached its end"
    if [ "$APPLY" = 1 ]; then
      kill -TERM "$pid" 2>/dev/null
      for _ in 1 2 3 4 5; do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
      if kill -0 "$pid" 2>/dev/null; then kill -KILL "$pid" 2>/dev/null; say "      -> SIGKILL"
      else say "      -> terminated"; fi
      # the runner that was blocked waiting on it, now childless and orphaned
      if [ -n "$ppid" ] && [ "$ppid" != "1" ]; then
        pcmd=$(ps -p "$ppid" -o command= 2>/dev/null)
        if printf '%s' "$pcmd" | grep -qE 'bash .*run_.*\.sh' && [ -z "$(pgrep -P "$ppid" 2>/dev/null)" ]; then
          kill -TERM "$ppid" 2>/dev/null; say "      -> also stopped its runner (pid $ppid)"
        fi
      fi
    else
      say "      -> WOULD REAP (re-run with --apply)"
    fi
    reaped=$((reaped+1))
  else
    left=$((left+1))
    say "  STILL COMPUTING     pid=$pid  cpu=${pcpu}%  elapsed=$et  ($base) — LEFT ALONE"
    say "      no completion marker in $log, so it may still be working"
  fi
done < <(ps -axo pid,ppid,%cpu,etime,command 2>/dev/null | grep -i 'wolframscript' | grep -v grep)

# Quiet and nothing reaped -> say nothing at all.
if [ "$QUIET" = 1 ] && [ "$reaped" = 0 ]; then exit 0; fi

say ""
if [ "$APPLY" = 1 ]; then
  say "wolfram-reap: $reaped reaped, $left left running (of $found batch jobs).  [$(date '+%Y-%m-%d %H:%M')]"
else
  say "wolfram-reap: $reaped reapable, $left still computing (of $found batch jobs). --apply to act."
fi
flush
exit 0
