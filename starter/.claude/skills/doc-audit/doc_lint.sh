#!/usr/bin/env bash
# doc_lint.sh — mechanical tells that a DOCUMENT claims more than it supports, points at
# files that no longer exist, or breaks the project's record discipline.
#
# Usage:  bash .claude/skills/doc-audit/doc_lint.sh <file.tex|file.md> [--root <dir>]
#         LINTMAX=80 bash ... doc_lint.sh <file>      # lines listed per section (default 40)
#         DOC_LINT_DIRS="src tests" bash ... doc_lint.sh <file>   # extra pointer search roots
#
# HEURISTIC PRE-FILTER, not a verdict.  It cannot read mathematics.  It surfaces the cheap
# shapes that ship wrong statements in research records (see BUGS.md § C, § F, § I), so the
# corresponding passages get READ before any verdict is written.  A clean run means "no
# cheap tell fired", NEVER "the document is sound".  The claim ledger in SKILL.md is the
# actual evaluation.
#
# What it reports (sections):
#   [0]  parse sanity — type detected, label universe, counts.  READ THIS FIRST.
#   [1]  dangling \ref / \eqref / \cref keys, unknown \cite keys, duplicate \label keys,
#        dead relative markdown links
#   [2]  strength words ("proved", "all orders", "canonical", ...) in prose that is not
#        inside a theorem-like environment and not typed in the same paragraph with one of
#        the eight claim statuses in CLAUDE.md
#   [3]  advocacy / hand-wave phrases ("it is easy to see", "not merely", "one finds", ...)
#   [4]  count leads ("38/38 checks", "0 errors") offered as evidence
#   [5]  file pointers that do not resolve (stale script/log paths after a move)
#   [6]  unfinished markers (TODO, ???, \todo, fill-in placeholders)
#   [7]  append-style retraction phrases (corrections must REPLACE in place)
#   [8]  relative dates ("yesterday", "last week") that must be absolute in a record
#   [9]  handoff structure (VERDICT / THIS ROUND / ## Gates / ## Touched / scope clause /
#        line cap read from handoff/hx.sh) — handoff messages only
#   [10] type-specific structure (status ledger / next task / stop rule; \section; abstract)
#
# EXIT STATUS.  Findings never change it: this is advisory and must never become a build
# gate on its own verdict.  A failure to parse is not a finding, it is the tool not doing
# its job, and that does exit nonzero:
#   0  parsed a non-empty document (whatever the findings)
#   2  file missing / unreadable / usage error
#   3  VACUOUS — the file is empty or has no content lines; nothing was audited
#
# Portable: bash 3.2 (macOS) + perl 5, no GNU-only flags.

set -uo pipefail

# ---- Where evidence lives (FILL IN ONCE) ------------------------------------------------
# A pointer such as `numerics/foo.py` is resolved against the project root first, then the
# document's own directory, then each directory below (relative to the root).  Add the
# folders your documents cite scripts, logs and data from; delete the ones you do not have.
SEARCH_DIRS="numerics scripts code data logs docs figures publications handoff handoff/msgs handoff/archive"
SEARCH_DIRS="${DOC_LINT_DIRS:-$SEARCH_DIRS}"
# -----------------------------------------------------------------------------------------

f=""; root=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) shift; root="${1:-}";;
    -h|--help) sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'; exit 2;;
    *) if [ -z "$f" ]; then f="$1"; else echo "doc_lint: unexpected argument '$1'" >&2; exit 2; fi;;
  esac
  shift
done

if [ -z "$f" ] || [ ! -f "$f" ]; then
  echo "usage: bash doc_lint.sh <file.tex|file.md> [--root <project-root>]" >&2
  exit 2
fi

# Project root: explicit flag, else the git toplevel of the file's directory, else cwd.
if [ -z "$root" ]; then
  root=$(cd "$(dirname "$f")" && git rev-parse --show-toplevel 2>/dev/null || pwd)
fi
root=$(cd "$root" && pwd)
fabs=$(cd "$(dirname "$f")" && pwd)/$(basename "$f")

# Line cap for handoff messages, read from the mailbox helper so the two never drift.
maxlines=160
if [ -f "$root/handoff/hx.sh" ]; then
  m=$(grep -E '^MAXLINES=' "$root/handoff/hx.sh" | head -1 | sed 's/^MAXLINES=//' | tr -d ' ')
  case "$m" in ''|*[!0-9]*) ;; *) maxlines="$m";; esac
fi

# Basename index of the repository, built once, used by [5] to distinguish "moved" from
# "gone".  Excludes git internals; nested repositories are included on purpose (documents
# legitimately point into a submodule or a sibling clone).
idx=$(mktemp "${TMPDIR:-/tmp}/doclint.XXXXXX")
trap 'rm -f "$idx"' EXIT
( cd "$root" && find . -type d -name .git -prune -o -type f -print 2>/dev/null | sed 's|^\./||' ) > "$idx"

LINTMAX="${LINTMAX:-40}"

perl - "$fabs" "$root" "$maxlines" "$idx" "$LINTMAX" "$SEARCH_DIRS" <<'PERL'
use strict; use warnings;
use File::Basename qw(dirname basename);

my ($file, $root, $maxlines, $idxfile, $cap, $searchdirs) = @ARGV;
my @searchdirs = grep { length } split /\s+/, $searchdirs;

# ------------------------------------------------------------------ helpers
sub slurp { my $p = shift; open my $h, '<', $p or return (); my @l = <$h>; close $h; chomp @l; return @l; }
sub rel   { my $p = shift; my $r = $p; $r =~ s/^\Q$root\E\/?//; return $r; }
sub strip_tex_comment { my $l = shift; $l =~ s/(?<!\\)%.*$//; return $l; }
sub say_line { my ($ln, $txt) = @_; $txt =~ s/\s+/ /g; $txt = substr($txt, 0, 150); printf("  L%-6s %s\n", $ln, $txt); }
sub listing {   # print up to $cap entries of [ln, text]; the rest as a count
  my @rows = @_;
  my $n = scalar @rows;
  for my $i (0 .. $n - 1) {
    if ($i >= $cap) { printf("  ... and %d more (raise LINTMAX to list them)\n", $n - $cap); last; }
    say_line(@{$rows[$i]});
  }
}

my @idxall = slurp($idxfile);   # repository file index, built by the bash wrapper
my @lines = slurp($file);
my $nlines = scalar @lines;
my $ncontent = scalar grep { /\S/ } @lines;
my $relfile = rel($file);
my $is_tex = ($file =~ /\.tex$/i) ? 1 : 0;
my $is_md  = ($file =~ /\.md$/i)  ? 1 : 0;
my $text   = join("\n", @lines);
my $bname  = basename($file);

# ------------------------------------------------------------------ type detection
# Ordered most specific first.  brief/workbook/bigPicture are matched by NAME before the
# generic "a .tex with \documentclass and \title is a paper" rule, because they have both.
my $type = 'other';
if    ($relfile =~ m{(^|/)handoff/} || ($text =~ /^VERDICT:/m && $text =~ /^FROM:/m)) { $type = 'handoff'; }
elsif ($bname =~ /^(?:CLAUDE|AGENTS)\.md$/i)          { $type = 'agent-guide'; }
elsif ($bname =~ /^strategy-map/i || $relfile =~ m{(^|/)docs/pipelines/}
       || ($is_md && $text =~ /^#+\s.*\b(?:dashboard|strategy\s+map|route\s+map)\b/mi)) { $type = 'strategy-map'; }
elsif ($bname =~ /^bigPicture/i || $relfile =~ m{(^|/)docs/big-pictures/}) { $type = 'big-picture'; }
elsif ($bname =~ /^brief/i)                            { $type = 'brief'; }
elsif ($bname =~ /^workbook/i || $relfile =~ m{(^|/)docs/workbooks/}) {
  $type = ($text =~ /\\documentclass/) ? 'workbook-master' : 'workbook-section'; }
elsif ($relfile =~ m{(^|/)sections/} && $is_tex)       { $type = 'workbook-section'; }
elsif ($relfile =~ m{(^|/)publications/} || $bname =~ /^paper/i
       || ($is_tex && $text =~ /\\documentclass/ && $text =~ /\\title\{/)) { $type = 'paper'; }
elsif ($is_md)  { $type = 'markdown'; }
elsif ($is_tex) { $type = 'tex'; }

# ------------------------------------------------------------------ [0] parse sanity
print "=== doc_lint: $relfile\n";
print "    type detected     : $type\n";
printf("    lines / content   : %d / %d\n", $nlines, $ncontent);

if ($ncontent == 0) {
  print "\n";
  print "    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
  print "    !!!  EMPTY DOCUMENT -- THIS LINT IS VACUOUS. IT AUDITED NOTHING.       !!!\n";
  print "    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
  print "    Every 'none' below would be the ABSENCE OF INPUT, not the absence of a problem.\n";
  print "=== SUMMARY: NOTHING PARSED -- VACUOUS RUN, NOT A CLEAN ONE.\n";
  exit 3;
}

# ---- label universe (tex only): the master's full \input closure when we can find it
my @universe = ($file);
my $master = '';
my $universe_note = 'this file only';
if ($is_tex) {
  if ($text =~ /\\documentclass/) { $master = $file; $universe_note = 'this file is a master; its \\input closure'; }
  else {
    my $base = basename($file); $base =~ s/\.tex$//;
    my $dir = dirname($file);
    OUTER: for my $up (1 .. 4) {
      my $d = $dir; for (1 .. $up) { $d = dirname($d); }
      last if length($d) < length($root);
      opendir(my $dh, $d) or next;
      for my $cand (sort grep { /\.tex$/ } readdir($dh)) {
        my $p = "$d/$cand";
        my @c = slurp($p);
        my $t = join("\n", @c);
        next unless $t =~ /\\documentclass/;
        if ($t =~ /\\(?:input|include)\{[^}]*\b\Q$base\E(?:\.tex)?\}/) { $master = $p; $universe_note = 'master ' . rel($p) . ' and its \\input closure'; last OUTER; }
      }
      closedir $dh;
    }
    if (!$master) {
      # fallback: siblings in the same directory, so cross-section refs still resolve
      opendir(my $dh, $dir);
      @universe = map { "$dir/$_" } sort grep { /\.tex$/ } readdir($dh);
      closedir $dh;
      $universe_note = 'no master found; siblings in ' . rel($dir);
    }
  }
  if ($master) {
    my %seen; my @queue = ($master); @universe = ();
    while (@queue) {
      my $p = shift @queue;
      next if $seen{$p}++;
      push @universe, $p;
      my $mdir = dirname($master); my $pdir = dirname($p);
      for my $l (slurp($p)) {
        $l = strip_tex_comment($l);
        while ($l =~ /\\(?:input|include)\{([^}]+)\}/g) {
          my $t = $1; $t .= '.tex' unless $t =~ /\.tex$/;
          my $hit = '';
          for my $try ("$mdir/$t", "$pdir/$t", dirname($mdir) . "/$t") { if (-f $try) { $hit = $try; last; } }
          if (!$hit) {   # fallback: suffix match against the repository index (odd layouts, moved masters)
            for my $e (@idxall) { if ($e =~ m{(?:^|/)\Q$t\E$}) { $hit = "$root/$e"; last; } }
          }
          push @queue, $hit if $hit;
        }
      }
    }
  }
}

my (%labels, %bibkeys);
if ($is_tex) {
  for my $p (@universe) {
    my $ln = 0;
    for my $l (slurp($p)) {
      $ln++;
      $l = strip_tex_comment($l);
      while ($l =~ /\\label\{([^}]+)\}/g) { push @{$labels{$1}}, rel($p) . ":$ln"; }
      while ($l =~ /\\bibitem(?:\[[^\]]*\])?\{([^}]+)\}/g) { $bibkeys{$1} = 1; }
      while ($l =~ /\\(?:bibliography|addbibresource)\{([^}]+)\}/g) {
        for my $b (split /,/, $1) {
          $b =~ s/^\s+|\s+$//g; $b .= '.bib' unless $b =~ /\.bib$/;
          for my $try (dirname($p) . "/$b", ($master ? dirname($master) . "/$b" : ())) {
            next unless -f $try;
            for my $bl (slurp($try)) { if ($bl =~ /^\s*@\w+\s*\{\s*([^,\s]+)\s*,/) { $bibkeys{$1} = 1; } }
          }
        }
      }
    }
  }
}

print "    label universe    : $universe_note (" . scalar(@universe) . " file(s))\n" if $is_tex;
if ($is_tex) {
  my $tl = 0; my $tr = 0; my $tc = 0;
  for my $l (@lines) { my $s = strip_tex_comment($l);
    $tl += () = $s =~ /\\label\{/g;
    $tr += () = $s =~ /\\(?:ref|eqref|cref|Cref|autoref|pageref|nameref)\*?\{/g;
    $tc += () = $s =~ /\\cite[a-zA-Z]*\*?(?:\[[^\]]*\])*\{/g; }
  printf("    labels/refs/cites : %d / %d / %d in this file; %d labels, %d bib keys in universe\n", $tl, $tr, $tc, scalar(keys %labels), scalar(keys %bibkeys));
}
print "    handoff line cap  : $maxlines (from handoff/hx.sh)\n" if $type eq 'handoff';
print "\n";

# ------------------------------------------------------------------ [1] cross-references
print "--- [1] DANGLING CROSS-REFERENCES (a reference to nothing is a claim to nothing)\n";
my @bad1;
if ($is_tex) {
  my $ln = 0;
  for my $l (@lines) {
    $ln++;
    my $s = strip_tex_comment($l);
    while ($s =~ /\\(?:ref|eqref|cref|Cref|autoref|pageref|nameref)\*?\{([^}]+)\}/g) {
      for my $k (split /,/, $1) { $k =~ s/^\s+|\s+$//g; next if $k eq ''; push @bad1, [$ln, "\\ref{$k} -> no \\label in universe"] unless exists $labels{$k}; }
    }
    while ($s =~ /\\cite[a-zA-Z]*\*?(?:\[[^\]]*\])*\{([^}]+)\}/g) {
      for my $k (split /,/, $1) { $k =~ s/^\s+|\s+$//g; next if $k eq ''; push @bad1, [$ln, "\\cite{$k} -> no \\bibitem or .bib entry in universe"] unless exists $bibkeys{$k}; }
    }
  }
  for my $k (sort keys %labels) {
    my @w = @{$labels{$k}};
    push @bad1, [$w[0] =~ /:(\d+)$/ ? $1 : '?', "duplicate \\label{$k} at " . join(', ', @w)] if @w > 1 && grep { index($_, $relfile . ':') == 0 } @w;
  }
}
if ($is_md) {
  my $ln = 0; my $fdir = dirname($file);
  for my $l (@lines) {
    $ln++;
    while ($l =~ /\]\(([^)\s#]+)(?:#[^)]*)?\)/g) {
      my $t = $1; next if $t =~ m{^[a-z]+://} || $t =~ /^mailto:/;
      next unless $t =~ m{^[\w./-]+$} && $t =~ m{[/.]};   # path-like only: inline math like [z](M(z)) is not a link
      my $ok = 0; for my $try ("$fdir/$t", "$root/$t") { $ok = 1 if -e $try; }
      push @bad1, [$ln, "dead relative link ($t)"] unless $ok;
    }
  }
}
if (@bad1) { listing(@bad1); print "    ^ a dangling \\ref compiles to '??' and a stale link sends the reader nowhere;\n      both are usually the trace of a moved or deleted statement. Find where it went.\n"; }
else { print "    none\n"; }
print "\n";

# ------------------------------------------------------------------ [2] untyped strength
print "--- [2] STRENGTH WORDS OUTSIDE A TYPED STATEMENT (CLAUDE.md § Research-claim discipline)\n";
my $strength = qr/\b(?:proved|proves|proven|all[- ]orders?|for\s+every\s+[a-zA-Z]\b|for\s+all\s+[a-zA-Z]\b|every\s+order|canonical(?:ly)?|dissolves?|establish(?:es|ed)|unconditional(?:ly)?|rigorous(?:ly)?|now\s+closed|closes\s+the|discharged|is\s+a\s+theorem|no\s+assumption\s+remains)\b/i;
my $typetag  = qr/\\le\s*\d|\\leq\s*\d|<=\s*\d|≤\s*\d|up\s+to\s+(?:order|weight|depth|degree|n\s*=)|through\s+(?:order|weight|degree)|numerically\s+(?:verified|checked|confirmed)|\b(?:definition|exact\s+identity|proved\s+theorem|conditional\s+theorem|conditional\s+on|conjecture|finite\s+verification|finite\s+check|numerical\s+evidence|obstruction|does\s+not\s+(?:establish|prove|supply)|not\s+(?:a\s+)?(?:proof|theorem)|retracted|refuted)\b/i;
my $envre    = qr/\\(begin|end)\{(theorem|proposition|lemma|corollary|definition|conjecture|remark|claim|question|verbatim|lstlisting)\*?\}/;
my @bad2; my $typed = 0; my $depth = 0; my $incode = 0;
my @para_start = (1);   # paragraph boundaries for the typed-in-paragraph test
{ my $ln = 0; for my $l (@lines) { $ln++; push @para_start, $ln + 1 if $l !~ /\S/; } }
sub para_of { my $ln = shift; my $s = 1; for my $p (@para_start) { last if $p > $ln; $s = $p; } my $e = $nlines; for my $p (@para_start) { if ($p > $ln) { $e = $p - 1; last; } } return ($s, $e); }
{
  my $ln = 0;
  for my $l (@lines) {
    $ln++;
    if ($is_md) { $incode = !$incode if $l =~ /^\s*```/; next if $incode; }
    while ($l =~ /$envre/g) { $depth += ($1 eq 'begin') ? 1 : -1; }
    my $s = $is_tex ? strip_tex_comment($l) : $l;
    next unless $s =~ $strength;
    next if $depth > 0;                              # inside a theorem-like or verbatim env
    my ($ps, $pe) = para_of($ln);
    my $para = join(' ', @lines[$ps - 1 .. $pe - 1]);
    if ($para =~ $typetag) { $typed++; next; }
    push @bad2, [$ln, $s];
  }
}
printf("    %d strength line(s) typed in their paragraph; %d untyped:\n", $typed, scalar(@bad2));
if (@bad2) { listing(@bad2); print "    ^ each needs one of: definition / exact identity / proved theorem / conditional\n      theorem / conjecture / finite verification / numerical evidence / obstruction —\n      in the same paragraph, or the word must go. A finite check is never 'proved'.\n"; }
else { print "    none\n"; }
print "\n";

# ------------------------------------------------------------------ [3] advocacy
print "--- [3] ADVOCACY AND HAND-WAVE (a sentence defending a step is where the step is missing)\n";
my $adv = qr/it\s+is\s+easy\s+to\s+see|easy\s+to\s+see|\bclearly\b|\bobviously\b|\btrivially\b|one\s+finds|a\s+short\s+computation|straightforward(?:ly)?|\bas\s+usual\b|it\s+can\s+be\s+shown|one\s+can\s+show|well[- ]known|not\s+merely|\bgenuinely\b|not\s+a\s+tautology|rather\s+than\s+assumed|reproduc\w+\s+rather\s+than|the\s+control\s+is\s+what|it\s+is\s+immediate|\bevidently\b|it\s+is\s+obvious/i;
my @bad3; { my $ln = 0; $incode = 0; for my $l (@lines) { $ln++; if ($is_md) { $incode = !$incode if $l =~ /^\s*```/; next if $incode; } my $s = $is_tex ? strip_tex_comment($l) : $l; push @bad3, [$ln, $s] if $s =~ $adv; } }
if (@bad3) { listing(@bad3); print "    ^ open the step. Either the middle steps get written (workbooks are pedagogical)\n      or the defense is deleted and the claim stated at its supported strength.\n"; }
else { print "    none\n"; }
print "\n";

# ------------------------------------------------------------------ [4] count leads
print "--- [4] COUNT LEADS (a count is a control, not evidence for the claim; BUGS.md § C)\n";
# The bare N/N form needs guards, or every LaTeX fraction with equal parts trips it:
# `T^2/2`, `x^{4}/4` and `\frac{2}{2}` are arithmetic, not a pass count.  A count lead is
# preceded by whitespace or start-of-line and is not part of a larger token.
my @bad4; { my $ln = 0; for my $l (@lines) { $ln++; my $s = $is_tex ? strip_tex_comment($l) : $l;
  push @bad4, [$ln, $s] if $s =~ /\b(\d+)\s*\/\s*(\d+)\b\s*(?:gates?|checks?|tests?|cases?|PASS|passed|controls?|certificates?)/i
                        || $s =~ /(?:^|(?<=[\s(\[]))(\d+)\s*\/\s*\1(?!\.?\d)(?![\/^])/
                        || $s =~ /\b0\s+(?:errors?|warnings?|failures?|kernel\s+messages?|aborts?)\b/i; } }
if (@bad4) { listing(@bad4); print "    ^ fine as a status line; not fine as the reason a statement is true. The ledger\n      must say WHICH checks bear on the claim and which were vacuous.\n"; }
else { print "    none\n"; }
print "\n";

# ------------------------------------------------------------------ [5] file pointers
print "--- [5] FILE POINTERS THAT DO NOT RESOLVE (stale paths after a move are silent)\n";
my %bybase; for my $p (@idxall) { push @{$bybase{basename($p)}}, $p; }
my $fdir = dirname($file);
my @bad5; my %seenptr;
{
  my $ln = 0;
  for my $l (@lines) {
    $ln++;
    my $s = $is_tex ? strip_tex_comment($l) : $l;
    $s =~ s/\\_/_/g; $s =~ s/\\(?:texttt|path|url|verb)\{/{/g;
    while ($s =~ /(?<![\w\/.-])((?:[A-Za-z0-9_.-]+\/)*[A-Za-z0-9_.-]*[A-Za-z0-9_-]\.(?:wls|m|nb|wb|sh|py|jl|jsonl?|R|c|cpp|f90|tex|md|log|txt|toml|csv|dat|bib|pdf))\b/g) {
      my $t = $1;
      next if $t =~ /[*{}<>]/ || $t =~ m{://} || $t =~ /^\.+$/;
      next if $t =~ /^(?:e|i|cf|vs|et|al|resp|eq|fig|sec|ref|no|approx|rel|abs)\.[a-z]$/i;   # i.e., e.g. style tokens
      next if length($t) < 4;
      next if $seenptr{$t}++;
      my $found = 0;
      for my $try ("$root/$t", "$fdir/$t", ($master ? dirname($master) . "/$t" : ()),
                   map { "$root/$_/$t" } @searchdirs) {
        if (-e $try) { $found = 1; last; }
      }
      next if $found;
      my $b = basename($t);
      if (exists $bybase{$b}) {
        my @w = @{$bybase{$b}}; my $show = join(', ', @w[0 .. ($#w > 2 ? 2 : $#w)]) . ($#w > 2 ? sprintf(' (+%d)', $#w - 2) : '');
        push @bad5, [$ln, "$t -> not at that path; basename exists at: $show"];
      } else {
        push @bad5, [$ln, "$t -> NOT FOUND anywhere under the root"];
      }
    }
  }
}
printf("    %d distinct pointer(s) scanned; %d unresolved:\n", scalar(keys %seenptr), scalar(@bad5));
if (@bad5) { listing(@bad5); print "    ^ 'basename exists at' = the path is stale (moved); 'NOT FOUND' = the evidence the\n      document cites is not in the repository. Either way the claim it supports is\n      currently unsupported from this document.\n"; }
else { print "    none\n"; }
print "\n";

# ------------------------------------------------------------------ [6] markers
print "--- [6] UNFINISHED MARKERS\n";
my @bad6; { my $ln = 0; for my $l (@lines) { $ln++; push @bad6, [$ln, $l] if $l =~ /\bTODO\b|\bFIXME\b|\bXXX\b|\\todo\{|\?\?\?|\bTBD\b|<<<|\(fill in|\[fill in|\bTK\b/; } }
if (@bad6) { listing(@bad6); } else { print "    none\n"; }
print "\n";

# ------------------------------------------------------------------ [7] retraction shape
print "--- [7] APPEND-STYLE RETRACTION PHRASES (corrections REPLACE the false text)\n";
my @bad7; { my $ln = 0; for my $l (@lines) { $ln++; my $s = $is_tex ? strip_tex_comment($l) : $l;
  push @bad7, [$ln, $s] if $s =~ /\bretract(?:ed|s|ion)?\b|contrary\s+to\s+(?:the|what)\s+(?:above|earlier|previous)|the\s+earlier\s+claim|\berratum\b|^\s*correction:|\bsuperseded\b|\bwithdrawn\b|no\s+longer\s+(?:holds|true|valid)|we\s+(?:now\s+)?(?:realise|realize)\s+that/i; } }
if (@bad7) { listing(@bad7);
  if ($type eq 'strategy-map' || $type eq 'handoff') { print "    ^ legitimate in a retraction ledger or a handoff; check that the SOURCE statement\n      being retracted was also replaced in its workbook section, not left standing.\n"; }
  else { print "    ^ in a workbook or paper the false statement must be gone, not contradicted later:\n      a later reader may open only the earlier page.\n"; } }
else { print "    none\n"; }
print "\n";

# ------------------------------------------------------------------ [8] relative dates
print "--- [8] RELATIVE DATES (a record needs absolute dates)\n";
my @bad8; { my $ln = 0; for my $l (@lines) { $ln++; my $s = $is_tex ? strip_tex_comment($l) : $l; $s =~ s/\\today//g;
  push @bad8, [$ln, $s] if $s =~ /\b(?:yesterday|last\s+(?:week|night|session)|this\s+(?:morning|afternoon|evening)|tonight|tomorrow|next\s+(?:week|session)|earlier\s+today|later\s+today)\b/i; } }
if (@bad8) { listing(@bad8); } else { print "    none\n"; }
print "\n";

# ------------------------------------------------------------------ [9] handoff structure
my @bad9;
if ($type eq 'handoff') {
  print "--- [9] HANDOFF STRUCTURE (handoff/README.md: the verdict grades only the previous exchange)\n";
  my ($verd) = $text =~ /^VERDICT:\s*(\S+)/m;
  if (!defined $verd) { push @bad9, ['-', 'no VERDICT: line']; }
  elsif ($verd !~ /^(?:CONFIRMED|CORRECTED|REFUTED|FYI|ASK)\b/) { push @bad9, ['-', "VERDICT value '$verd' is not one of CONFIRMED/CORRECTED/REFUTED/FYI/ASK"]; }
  push @bad9, ['-', 'no THIS ROUND line (the new round needs its own typed status, separate from the verdict)'] unless $text =~ /^THIS ROUND\b/m;
  push @bad9, ['-', 'no "## Gates" section (what was checked AND what it does not cover)'] unless $text =~ /^##\s*Gates|^GATES?\b/m;
  push @bad9, ['-', 'no "## Touched" section (every file changed)'] unless $text =~ /^##\s*Touched|^TOUCHED\b|^RECORDS\b/m;
  push @bad9, ['-', 'no scope clause: nothing matching "does not establish / not cover / does NOT" anywhere'] unless $text =~ /does\s+not\s+(?:establish|cover|prove|supply|settle)|not\s+cover|does\s+NOT|NOT\s+(?:establish|proved|a\s+proof|cover)/i;
  push @bad9, ['-', sprintf('%d lines, cap is %d', $nlines, $maxlines)] if $nlines > $maxlines;
  if ($text =~ /^VERDICT:.*\b(?:ROUND\s+\d+\s+DELIVERS|DELIVERS|this\s+round\s+(?:proves|establishes))/mi) { push @bad9, ['-', 'VERDICT line carries the NEW round\'s claim — an acceptance token laundering an unaudited headline']; }
  if (@bad9) { listing(@bad9); } else { print "    all structural fields present; line count within cap\n"; }
  print "\n";
}

# ------------------------------------------------------------------ [10] type structure
print "--- [10] TYPE-SPECIFIC STRUCTURE\n";
my @bad10;
if ($type eq 'strategy-map') {
  push @bad10, ['-', 'no status / honesty ledger heading (what is EXACTLY proven)'] unless $text =~ /^#+.*\b(?:ledger|status|dashboard)\b/mi;
  push @bad10, ['-', 'no "next task" / "next action" text'] unless $text =~ /next\s+(?:task|action|step)/i;
  push @bad10, ['-', 'no "stop rule" / kill-criterion text (a route with no stop rule cannot fail)'] unless $text =~ /stop\s+(?:rule|criterion)|kill\s+criterion|abandon\s+if/i;
} elsif ($type eq 'big-picture') {
  push @bad10, ['-', 'no established/proven ledger word'] unless $text =~ /\b(?:established|proven|proved)\b/i;
  push @bad10, ['-', 'no "open" ledger word'] unless $text =~ /\bopen\b/i;
  my $neq = () = $text =~ /\\begin\{(?:equation|align|gather|multline)\*?\}/g;
  push @bad10, ['-', "$neq displayed equations — a big picture is equation-light; check they are all load-bearing"] if $neq > 40;
} elsif ($type eq 'workbook-section') {
  push @bad10, ['-', 'file does not start with a \\section or \\input (workbook sections are top-level)'] unless $text =~ /\A(?:\s*%[^\n]*\n)*\s*\\(?:section|input)\b/;
} elsif ($type eq 'paper') {
  push @bad10, ['-', 'no abstract'] unless $text =~ /\\begin\{abstract\}|\\abstract\{/;
  push @bad10, ['-', 'no \\title'] unless $text =~ /\\title\{/;
} elsif ($type eq 'agent-guide') {
  push @bad10, ['-', 'no "Current status" section (the file cannot say where the project is)'] unless $text =~ /^#+\s*current\s+status/mi;
  push @bad10, ['-', 'no "Files" map'] unless $text =~ /^#+\s*files\b/mi;
}
if (@bad10) { listing(@bad10); } else { print "    nothing missing for type '$type'\n"; }
print "\n";

# ------------------------------------------------------------------ summary
printf("=== SUMMARY (%s): %d dangling refs/links, %d untyped strength lines, %d advocacy lines, %d count leads, %d unresolved pointers, %d markers, %d retraction phrases, %d relative dates%s.\n",
  $type, scalar(@bad1), scalar(@bad2), scalar(@bad3), scalar(@bad4), scalar(@bad5), scalar(@bad6), scalar(@bad7), scalar(@bad8),
  ($type eq 'handoff' ? sprintf(', %d handoff-structure faults', scalar(@bad9)) : ''));
print "=== This is a PRE-FILTER. Build the claim ledger (SKILL.md step 2) before writing any verdict.\n";
exit 0;
PERL
exit $?
