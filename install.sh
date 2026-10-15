#!/usr/bin/env bash
# angular-minimizing-costing-cursor-rule installer for macOS / Linux / WSL / Git Bash
# Author: Abdul Razzak (github.com/RazzakAnsari) - MIT licensed
#
# One project (run from its root):
#   curl -fsSL https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.sh | bash
# Every Angular project under the current folder, in one go:
#   curl -fsSL https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.sh | bash -s -- --all
# Where is it installed?
#   curl -fsSL https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.sh | bash -s -- --status
# Local (from a clone):
#   bash <clone>/install.sh --target . --dry-run
#
# Flag            Environment variable
#   --target DIR    MCCR_TARGET       one project (default: current folder)
#   --all           MCCR_ALL=1        every folder with angular.json under --root
#   --root DIR      MCCR_ROOT         where --all / --status look (default: current folder)
#   --depth N       MCCR_DEPTH        how deep --all / --status look (default 6)
#   --status        MCCR_STATUS=1     list projects under --root and whether the kit is in them
#   --uninstall     MCCR_UNINSTALL=1  remove only what this installer added (add --all for every project)
#   --visible       MCCR_VISIBLE=1    do not hide the files from git (use this if you want to commit them)
#   --rules LIST    MCCR_RULES        all, or a comma list of rule names
#   --tool NAME     MCCR_TOOL         cursor, agents, claude or all
#   --index-ignore  MCCR_INDEXIGNORE=1  also add .cursorindexingignore
#   --dry-run       MCCR_DRYRUN=1     print what would happen, write nothing
#   --force         MCCR_FORCE=1      replace existing files / allow a folder without angular.json
#
# Copies rule files only. Inside a git repo it lists those exact files in the
# repo's .git/info/exclude so they never show up as changes or in commits.
# Never edits .gitignore, never replaces a file git already tracks, never
# overwrites without --force, runs only read-only git commands, never runs
# npm / ng, never edits source code.

set -euo pipefail

NAME="angular-minimizing-costing-cursor-rule"
VERSION="2.0.0"
TARBALL_URL="https://github.com/RazzakAnsari/$NAME/archive/refs/heads/main.tar.gz"
ALWAYS_ON="guardrails response-style tool-budget project-context"
KNOWN_RULES="guardrails ng-app-structure ng-components ng-i18n ng-rxjs ng-services ng-signals ng-specs ng-styles ng-templates project-context response-style tool-budget ts-style"
MARKER_REL=".cursor/rules/.mccr-installed"
NL='
'

TARGET="${MCCR_TARGET:-}"
ROOT="${MCCR_ROOT:-}"
DEPTH="${MCCR_DEPTH:-6}"
RULES="${MCCR_RULES:-all}"
TOOL="${MCCR_TOOL:-cursor}"
ALL="${MCCR_ALL:-0}"
STATUS="${MCCR_STATUS:-0}"
UNINSTALL="${MCCR_UNINSTALL:-0}"
VISIBLE="${MCCR_VISIBLE:-0}"
DRYRUN="${MCCR_DRYRUN:-0}"
FORCE="${MCCR_FORCE:-0}"
INDEXIGNORE="${MCCR_INDEXIGNORE:-0}"
KIT=""
TMP_DIR=""

say() { printf '%s\n' "$*"; }
fail() { printf '%s: %s\n' "$NAME" "$*" >&2; exit 1; }
usage() {
  say "Usage: install.sh [--target DIR] [--all] [--root DIR] [--depth N] [--status] [--uninstall]"
  say "                  [--visible] [--rules all|name,name] [--tool cursor|agents|claude|all]"
  say "                  [--index-ignore] [--dry-run] [--force]"
}
is_on() { case "${1:-0}" in 1|true|yes) return 0 ;; *) return 1 ;; esac; }
g() { local d="$1"; shift; command -v git >/dev/null 2>&1 || return 1; git -C "$d" -c core.quotepath=off "$@" 2>/dev/null; }
abspath() { (cd "$1" 2>/dev/null && pwd); }
is_abs() { case "$1" in /*|[A-Za-z]:*) return 0 ;; *) return 1 ;; esac; }
sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else printf -- '-\n'; fi
}
in_list() { printf '%s\n' "$1" | grep -qxF -- "$2"; }
# "hash rel" lines -> hash for rel
hash_of() { printf '%s\n' "$1" | awk -v r="$2" 'NF { h=$1; sub(/^[^ ]+ /, ""); if ($0 == r) { print h; exit } }'; }
to_pattern() { printf '/%s\n' "$(printf '%s' "$1$2" | sed 's/[][*?\\]/\\&/g')"; }
manifest_path() { printf '%s/%s' "$1" "$MARKER_REL"; }
manifest_files() {
  local m; m="$(manifest_path "$1")"
  if [ -f "$m" ]; then tr -d '\r' < "$m" | sed -n 's/^file=\([^ ]*\) \(.*\)$/\1 \2/p'; fi
}
manifest_get() {
  local m; m="$(manifest_path "$1")"
  if [ -f "$m" ]; then tr -d '\r' < "$m" | sed -n "s/^$2=//p" | head -n 1; fi
}

# Sets R_GIT R_VIAGIT R_EXCLUDE R_PREFIX R_TOP for a folder.
repo_info() {
  local d="$1" ex top cur common line gd c
  R_GIT=0; R_VIAGIT=0; R_EXCLUDE=""; R_PREFIX=""; R_TOP=""
  if [ "$(g "$d" rev-parse --is-inside-work-tree || true)" = "true" ]; then
    ex="$(g "$d" rev-parse --path-format=absolute --git-path info/exclude || true)"
    if [ -z "$ex" ]; then
      ex="$(g "$d" rev-parse --git-path info/exclude || true)"
      if ! is_abs "$ex"; then ex="$d/$ex"; fi
    fi
    R_GIT=1; R_VIAGIT=1; R_EXCLUDE="$ex"
    R_PREFIX="$(g "$d" rev-parse --show-prefix || true)"
    top="$(g "$d" rev-parse --show-toplevel || true)"
    R_TOP="$(abspath "${top:-$d}" || printf '%s' "$d")"
    return 0
  fi
  # git missing or refused this folder: find .git by hand (works for worktrees too)
  cur="$d"; common=""
  while [ -n "$cur" ]; do
    if [ -d "$cur/.git" ]; then common="$cur/.git"; break; fi
    if [ -f "$cur/.git" ]; then
      line="$(head -n 1 "$cur/.git" | tr -d '\r')"
      case "$line" in
        gitdir:*)
          gd="$(printf '%s' "${line#gitdir:}" | sed 's/^[[:space:]]*//')"
          if ! is_abs "$gd"; then gd="$cur/$gd"; fi
          common="$gd"
          if [ -f "$gd/commondir" ]; then
            c="$(head -n 1 "$gd/commondir" | tr -d '\r')"
            if is_abs "$c"; then common="$c"; else common="$gd/$c"; fi
          fi
          break ;;
      esac
    fi
    if [ "$cur" = "/" ]; then break; fi
    cur="$(dirname "$cur")"
  done
  if [ -n "$common" ]; then
    R_GIT=1; R_EXCLUDE="$common/info/exclude"; R_TOP="$cur"
    if [ "$d" != "$cur" ]; then R_PREFIX="${d#"$cur"/}/"; fi
  fi
  return 0
}

# set_block EXCLUDE PREFIX MERGE(0|1) PATTERNS -> prints changed|unchanged
set_block() {
  local ex="$1" open="# >>> $NAME /$2 >>>" close="# <<< $NAME /$2 <<<" merge="$3" pats="$4"
  local old="" rest="" prev="" want="" new=""
  if [ -f "$ex" ]; then
    old="$(cat "$ex"; printf x)"; old="${old%x}"
    rest="$(tr -d '\r' < "$ex" | awk -v o="$open" -v c="$close" 'f==0 && $0==o { f=1; next } f==1 { if ($0==c) f=0; next } { print }')"
    prev="$(tr -d '\r' < "$ex" | awk -v o="$open" -v c="$close" 'f==0 && $0==o { f=1; next } f==1 { if ($0==c) f=0; else if (NF) print; next }')"
  fi
  if [ "$merge" = 1 ]; then
    want="$(printf '%s\n%s\n' "$prev" "$pats" | awk 'NF && !seen[$0]++')"
  else
    want="$(printf '%s\n' "$pats" | awk 'NF && !seen[$0]++')"
  fi
  new="$rest"
  if [ -n "$want" ]; then
    if [ -n "$new" ]; then new="$new$NL"; fi
    new="$new$open$NL$want$NL$close"
  fi
  if [ -n "$new" ]; then new="$new$NL"; fi
  if [ ! -f "$ex" ] && [ -z "$new" ]; then echo unchanged; return 0; fi
  if [ "$new" = "$old" ]; then echo unchanged; return 0; fi
  if ! is_on "$DRYRUN"; then mkdir -p "$(dirname "$ex")"; printf '%s' "$new" > "$ex"; fi
  echo changed
}

# patterns for a list of rel paths (one per line)
patterns_for() {
  local prefix="$1" rel
  while IFS= read -r rel; do
    if [ -n "$rel" ]; then to_pattern "$prefix" "$rel"; fi
  done <<< "$2"
}

write_manifest() {
  local d="$1" owned="$2" hidden="no" now first
  if [ "$3" = 1 ]; then hidden="yes"; fi
  now="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  first="$(manifest_get "$d" installed)"
  mkdir -p "$d/.cursor/rules"
  {
    printf '%s\n' "$NAME" "version=$VERSION" "installed=${first:-$now}" "updated=$now" "hidden=$hidden"
    printf '%s\n' "$owned" | sed -n 's/^\([^ ][^ ]*\) \(.*\)$/file=\1 \2/p'
  } > "$(manifest_path "$d")"
}

other_installs() { # dir -> other worktrees that still have the kit at the same prefix
  local d="$1" wt
  while IFS= read -r wt; do
    if [ -z "$wt" ]; then continue; fi
    wt="$(abspath "$wt" || true)"
    if [ -n "$wt" ] && [ "$wt" != "$R_TOP" ] && [ -f "$wt/$R_PREFIX$MARKER_REL" ]; then printf '%s\n' "$wt"; fi
  done <<< "$(g "$d" worktree list --porcelain | sed -n 's/^worktree //p' || true)"
}

find_projects() {
  local root="$1" depth="$2" list p wt cand extra=""
  list="$(find "$root" -maxdepth "$((depth + 1))" \
      \( -type d \( -name node_modules -o -name dist -o -name bin -o -name obj -o -name out -o -name coverage -o -name '.*' \) ! -path "$root" -prune \) \
      -o \( -type f -name angular.json -print \) 2>/dev/null | while IFS= read -r p; do dirname "$p"; done || true)"
  while IFS= read -r p; do
    if [ -z "$p" ]; then continue; fi
    repo_info "$p"
    if [ "$R_VIAGIT" != 1 ]; then continue; fi
    while IFS= read -r wt; do
      if [ -z "$wt" ]; then continue; fi
      cand="$(abspath "$wt/$R_PREFIX" || true)"
      if [ -n "$cand" ] && [ -f "$cand/angular.json" ]; then extra="$extra$cand$NL"; fi
    done <<< "$(g "$p" worktree list --porcelain | sed -n 's/^worktree //p' || true)"
  done <<< "$list"
  printf '%s\n%s' "$list" "$extra" | awk 'NF' | sort -u
}

kit_src() {
  case "$1" in
    .cursorindexingignore) printf '%s/cursorindexingignore.txt' "$KIT" ;;
    *) printf '%s/%s' "$KIT" "$1" ;;
  esac
}

ROWS=""
T_NEW=0; T_REP=0; T_KEPT=0; T_TR=0; T_REM=0

install_one() {
  local d="$1" items="" rel from to word prev h tracked="" owned="" old_files line k hide=0 can_mark=1
  local n_new=0 n_rep=0 n_kept=0 n_tr=0 git_col result pats ch count r others
  if [ "$TOOL" = cursor ] || [ "$TOOL" = all ]; then
    for r in $CHOSEN; do items="$items.cursor/rules/$r.mdc$NL"; done
    if is_on "$INDEXIGNORE"; then items="$items.cursorindexingignore$NL"; fi
  fi
  if [ "$TOOL" = agents ] || [ "$TOOL" = all ]; then items="${items}AGENTS.md$NL"; fi
  if [ "$TOOL" = claude ] || [ "$TOOL" = all ]; then items="${items}CLAUDE.md$NL"; fi
  items="${items}PROMPTS.md$NL"

  repo_info "$d"
  if [ "$R_GIT" = 1 ] && ! is_on "$VISIBLE"; then hide=1; fi
  if [ "$R_GIT" = 1 ]; then
    local args=()
    while IFS= read -r rel; do if [ -n "$rel" ]; then args+=("$rel"); fi; done <<< "$items"
    tracked="$(g "$d" ls-files -- "${args[@]}" "$MARKER_REL" || true)"
  fi
  old_files="$(manifest_files "$d")"

  while IFS= read -r rel; do
    if [ -z "$rel" ]; then continue; fi
    from="$(kit_src "$rel")"; to="$d/$rel"
    if [ "$hide" = 1 ] && in_list "$tracked" "$rel"; then
      say "  tracked  $rel (git already tracks it - skipped; --visible --force replaces it)"
      n_tr=$((n_tr + 1)); continue
    fi
    if [ -e "$to" ] && ! is_on "$FORCE"; then
      prev="$(hash_of "$old_files" "$rel")"
      h="$(sha "$to")"
      if [ -n "$prev" ]; then owned="$owned$prev $rel$NL"; say "  keep     $rel (already installed)"
      elif [ "$h" != "-" ] && [ "$h" = "$(sha "$from")" ]; then owned="$owned$h $rel$NL"; say "  keep     $rel (same as the kit)"
      else say "  keep     $rel (your own file - left alone)"; fi
      n_kept=$((n_kept + 1)); continue
    fi
    if [ -e "$to" ]; then word=replace; else word=new; fi
    if is_on "$DRYRUN"; then
      say "  would $word $rel"
      owned="$owned$(sha "$from") $rel$NL"
    else
      mkdir -p "$(dirname "$to")"
      cp "$from" "$to"
      owned="$owned$(sha "$to") $rel$NL"
      printf '  %-8s %s\n' "$word" "$rel"
    fi
    if [ "$word" = replace ]; then n_rep=$((n_rep + 1)); else n_new=$((n_new + 1)); fi
  done <<< "$items"

  # keep earlier entries (for example AGENTS.md from a previous --tool all run)
  while IFS= read -r line; do
    if [ -z "$line" ]; then continue; fi
    k="${line#* }"
    if [ -z "$(hash_of "$owned" "$k")" ] && ! in_list "$tracked" "$k" && [ -f "$d/$k" ]; then owned="$owned$line$NL"; fi
  done <<< "$old_files"

  if [ "$hide" = 1 ] && in_list "$tracked" "$MARKER_REL"; then can_mark=0; fi
  if [ -n "$owned" ] && [ "$can_mark" = 1 ] && ! is_on "$DRYRUN"; then write_manifest "$d" "$owned" "$hide"; fi

  if [ "$R_GIT" != 1 ]; then
    git_col="not git"
  elif [ "$hide" = 1 ]; then
    git_col="hidden"
    if [ -n "$owned" ]; then
      pats="$(patterns_for "$R_PREFIX" "$(printf '%s' "$owned" | sed 's/^[^ ]* //')")"
      if [ "$can_mark" = 1 ]; then pats="$pats$NL$(to_pattern "$R_PREFIX" "$MARKER_REL")"; fi
      count="$(printf '%s\n' "$pats" | grep -c . || true)"
      ch="$(set_block "$R_EXCLUDE" "$R_PREFIX" 1 "$pats")"
      if is_on "$DRYRUN"; then say "  would hide $count path(s) from git via $R_EXCLUDE"
      elif [ "$ch" = changed ]; then say "  hidden   $count path(s) from git via $R_EXCLUDE"
      else say "  hidden   $count path(s) from git (already listed in $R_EXCLUDE)"; fi
    fi
  else
    git_col="visible"
    others="$(other_installs "$d")"
    if [ -n "$others" ]; then
      say "  note: other worktrees of this repo share the hide list ($(printf '%s' "$others" | tr '\n' ' ')), so these files stay hidden here too"
      git_col="hidden (shared)"
    else
      ch="$(set_block "$R_EXCLUDE" "$R_PREFIX" 0 "")"
      if [ "$ch" = changed ]; then say "  visible  removed the earlier hide block from $R_EXCLUDE"; fi
    fi
  fi

  if is_on "$DRYRUN"; then result="dry run"
  elif [ $((n_new + n_rep)) -gt 0 ]; then result="installed"
  else result="up to date"; fi
  say "  done: new $n_new, replaced $n_rep, kept $n_kept, tracked-skipped $n_tr"
  ROWS="$ROWS$d	$result	$n_new	$n_rep	$n_kept	$n_tr	$git_col$NL"
  T_NEW=$((T_NEW + n_new)); T_REP=$((T_REP + n_rep)); T_KEPT=$((T_KEPT + n_kept)); T_TR=$((T_TR + n_tr))
}

uninstall_one() {
  local d="$1" files rels="" tracked="" rel p stored left="" n_rem=0 n_kept=0 git_col result others sub ch
  local args=()
  files="$(manifest_files "$d")"
  if [ ! -f "$(manifest_path "$d")" ]; then
    say "  nothing to remove (no $MARKER_REL here)"
    ROWS="$ROWS$d	not installed	0	0	-$NL"; return 0
  fi
  repo_info "$d"
  rels="$(printf '%s\n' "$files" | sed 's/^[^ ]* //' | awk 'NF')"
  while IFS= read -r rel; do if [ -n "$rel" ]; then args+=("$rel"); fi; done <<< "$rels"
  if [ "$R_GIT" = 1 ] && [ "${#args[@]}" -gt 0 ]; then tracked="$(g "$d" ls-files -- "${args[@]}" || true)"; fi
  while IFS= read -r rel; do
    if [ -z "$rel" ]; then continue; fi
    p="$d/$rel"
    if [ ! -f "$p" ]; then continue; fi
    if in_list "$tracked" "$rel"; then say "  keep     $rel (tracked by git)"; n_kept=$((n_kept + 1)); continue; fi
    stored="$(hash_of "$files" "$rel")"
    if ! is_on "$FORCE" && { [ "$stored" = "-" ] || [ "$(sha "$p")" != "$stored" ]; }; then
      say "  keep     $rel (changed since install; --force removes it)"
      left="$left$rel$NL"; n_kept=$((n_kept + 1)); continue
    fi
    if is_on "$DRYRUN"; then say "  would remove $rel"; else rm -f "$p"; say "  removed  $rel"; fi
    n_rem=$((n_rem + 1))
  done <<< "$rels"
  if is_on "$DRYRUN"; then
    if [ -z "$left" ]; then say "  would remove $MARKER_REL"; fi
  elif [ -n "$left" ]; then
    # keep the marker for the files left behind so a later --uninstall --force can still remove them
    write_manifest "$d" "$(printf '%s\n' "$files" | while IFS= read -r line; do if [ -n "$line" ] && in_list "$left" "${line#* }"; then printf '%s\n' "$line"; fi; done)" "$( [ "$R_GIT" = 1 ] && echo 1 || echo 0 )"
  else
    rm -f "$(manifest_path "$d")"
    for sub in .cursor/rules .cursor; do
      if [ -d "$d/$sub" ] && [ -z "$(ls -A "$d/$sub")" ]; then rmdir "$d/$sub"; fi
    done
  fi
  if [ "$R_GIT" != 1 ]; then
    git_col="not git"
  else
    others="$(other_installs "$d")"
    if [ -n "$others" ]; then
      say "  kept the git hide block: the kit is still in $(printf '%s' "$others" | tr '\n' ' ')"
      git_col="block kept (worktree)"
    elif [ -n "$left" ]; then
      ch="$(set_block "$R_EXCLUDE" "$R_PREFIX" 0 "$(patterns_for "$R_PREFIX" "$left$MARKER_REL")")"
      say "  still hiding the changed file(s) from git"
      git_col="still hidden"
    else
      ch="$(set_block "$R_EXCLUDE" "$R_PREFIX" 0 "")"
      if [ "$ch" = changed ]; then
        if is_on "$DRYRUN"; then say "  would remove the hide block from $R_EXCLUDE"; else say "  removed the hide block from $R_EXCLUDE"; fi
        git_col="block removed"
      else git_col="no block"; fi
    fi
  fi
  if is_on "$DRYRUN"; then result="dry run"; else result="removed"; fi
  ROWS="$ROWS$d	$result	$n_rem	$n_kept	$git_col$NL"
  T_REM=$((T_REM + n_rem)); T_KEPT=$((T_KEPT + n_kept))
}

status_row() {
  local d="$1" present="" rel n_rules installed git_col version="" files st tr n_st n_tr n_files
  local args=()
  if [ -f "$(manifest_path "$d")" ]; then
    while IFS= read -r rel; do
      if [ -n "$rel" ] && [ -f "$d/$rel" ]; then present="$present$rel$NL"; fi
    done <<< "$(manifest_files "$d" | sed 's/^[^ ]* //')"
    version="$(manifest_get "$d" version)"
  else
    for rel in $KNOWN_RULES; do
      if [ -f "$d/.cursor/rules/$rel.mdc" ]; then present="$present.cursor/rules/$rel.mdc$NL"; fi
    done
  fi
  n_rules="$(printf '%s' "$present" | grep -c '\.mdc$' || true)"
  if [ -n "$version" ]; then installed="yes"; elif [ "$n_rules" -gt 0 ]; then installed="rule files, no marker"; else installed="no"; fi
  repo_info "$d"
  git_col="not git"
  if [ "$R_GIT" = 1 ]; then
    files="$present"
    if [ -n "$version" ]; then files="$files$MARKER_REL$NL"; fi
    while IFS= read -r rel; do if [ -n "$rel" ]; then args+=("$rel"); fi; done <<< "$files"
    if [ "${#args[@]}" -eq 0 ]; then git_col="-"
    elif [ "$R_VIAGIT" != 1 ]; then git_col="unknown (git unavailable)"
    elif ! st="$(g "$d" status --porcelain --untracked-files=all -- "${args[@]}")"; then git_col="unknown (git failed)"
    else
      tr="$(g "$d" ls-files -- "${args[@]}" || true)"
      n_st="$(printf '%s' "$st" | grep -c . || true)"
      n_tr="$(printf '%s' "$tr" | grep -c . || true)"
      n_files="${#args[@]}"
      if [ "$n_st" -gt 0 ]; then git_col="VISIBLE ($n_st change(s))"
      elif [ "$n_tr" -ge "$n_files" ]; then git_col="committed"
      elif [ "$n_tr" -gt 0 ]; then git_col="hidden ($n_tr committed)"
      else git_col="hidden"; fi
    fi
  fi
  ROWS="$ROWS$d	$installed	$n_rules	$git_col	$version$NL"
}

print_table() { # header (tab separated) + ROWS
  { printf '%s\n' "$1"; printf '%s' "$ROWS"; } | awk -F'\t' '
    { n++; for (i = 1; i <= NF; i++) { cell[n, i] = $i; if (length($i) > w[i]) w[i] = length($i) } if (NF > nf) nf = NF }
    END {
      for (r = 1; r <= n; r++) {
        line = ""
        for (i = 1; i <= nf; i++) line = line sprintf("%-" w[i] "s  ", cell[r, i])
        sub(/ +$/, "", line); print line
        if (r == 1) { line = ""; for (i = 1; i <= nf; i++) { d = ""; for (j = 0; j < w[i]; j++) d = d "-"; line = line d "  " } sub(/ +$/, "", line); print line }
      }
    }'
}

get_kit() {
  local script_dir="" top
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi
  if [ -n "$script_dir" ] && [ -d "$script_dir/kit/.cursor/rules" ]; then
    KIT="$script_dir/kit"
    say "Using local kit: $KIT"
  else
    command -v curl >/dev/null 2>&1 || fail "curl is required"
    command -v tar >/dev/null 2>&1 || fail "tar is required"
    TMP_DIR="$(mktemp -d)"
    say "Downloading $TARBALL_URL"
    curl -fsSL "$TARBALL_URL" | tar -xz -C "$TMP_DIR"
    top="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    [ -n "$top" ] || fail "downloaded archive was empty"
    KIT="$top/kit"
  fi
  KIT="$(abspath "$KIT")"
}

cleanup() { if [ -n "$TMP_DIR" ]; then rm -rf "$TMP_DIR"; fi; return 0; }

main() {
  local mode base projects p r available asked t
  while [ $# -gt 0 ]; do
    case "$1" in
      --target) TARGET="${2:?--target needs a value}"; shift 2 ;;
      --root) ROOT="${2:?--root needs a value}"; shift 2 ;;
      --depth) DEPTH="${2:?--depth needs a value}"; shift 2 ;;
      --rules) RULES="${2:?--rules needs a value}"; shift 2 ;;
      --tool) TOOL="${2:?--tool needs a value}"; shift 2 ;;
      --all) ALL=1; shift ;;
      --status) STATUS=1; shift ;;
      --uninstall) UNINSTALL=1; shift ;;
      --visible) VISIBLE=1; shift ;;
      --index-ignore) INDEXIGNORE=1; shift ;;
      --dry-run) DRYRUN=1; shift ;;
      --force) FORCE=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; fail "unknown option: $1" ;;
    esac
  done
  case "$TOOL" in cursor|agents|claude|all) ;; *) fail "unknown tool '$TOOL' (use cursor, agents, claude or all)" ;; esac
  case "$DEPTH" in ''|*[!0-9]*) fail "--depth needs a number" ;; esac
  if is_on "$STATUS"; then mode=status; elif is_on "$UNINSTALL"; then mode=uninstall; else mode=install; fi

  if is_on "$ALL" || [ "$mode" = status ]; then
    base="${ROOT:-${TARGET:-$(pwd)}}"
    [ -d "$base" ] || fail "folder not found: $base"
    base="$(abspath "$base")"
    say "$NAME: looking for angular.json under $base (depth $DEPTH)"
    projects="$(find_projects "$base" "$DEPTH")"
    if [ -z "$projects" ]; then say "No Angular projects (folders with angular.json) under $base."; exit 0; fi
    say "Found $(printf '%s\n' "$projects" | grep -c .) Angular project(s)."
  else
    t="${TARGET:-$(pwd)}"
    [ -d "$t" ] || fail "target folder not found: $t"
    t="$(abspath "$t")"
    if [ "$mode" = install ] && [ ! -f "$t/angular.json" ]; then
      if is_on "$FORCE"; then
        say "Warning: no angular.json in $t - continuing because force is set."
      else
        say "$NAME: no angular.json in $t."
        say "Run this from your Angular project root, use --force / MCCR_FORCE=1,"
        say "or use --all / MCCR_ALL=1 to install into every Angular project under this folder."
        exit 1
      fi
    fi
    projects="$t"
  fi

  if [ "$mode" = status ]; then
    while IFS= read -r p; do if [ -n "$p" ]; then status_row "$p"; fi; done <<< "$projects"
    say ""
    print_table "Project	Installed	Rules	Git	Version"
    say ""
    say "Installed in $(printf '%s' "$ROWS" | awk -F'\t' '$2 != "no"' | grep -c . || true) of $(printf '%s' "$ROWS" | grep -c . || true) project(s)."
    exit 0
  fi

  trap cleanup EXIT
  if [ "$mode" = install ]; then
    get_kit
    available="$(for f in "$KIT"/.cursor/rules/*.mdc; do basename "$f" .mdc; done | tr '\n' ' ')"
    if [ "$RULES" = "all" ]; then
      CHOSEN="$available"
    else
      CHOSEN="$ALWAYS_ON"
      IFS=',' read -r -a asked <<< "$RULES"
      for r in "${asked[@]}"; do
        r="$(printf '%s' "$r" | tr -d '[:space:]')"
        if [ -z "$r" ]; then continue; fi
        case " $available " in *" $r "*) ;; *) fail "unknown rule '$r'. Available: $available" ;; esac
        case " $CHOSEN " in *" $r "*) ;; *) CHOSEN="$CHOSEN $r" ;; esac
      done
    fi
  fi

  local tag="" vis="hidden from git"
  if is_on "$DRYRUN"; then tag="  (dry run - nothing is written)"; fi
  if is_on "$VISIBLE"; then vis="visible to git"; fi
  if [ "$mode" = install ]; then
    say "$NAME $VERSION by Abdul Razzak  [tool=$TOOL rules=$RULES, $vis]$tag"
  else
    say "$NAME $VERSION - uninstall$tag"
  fi

  local n=0
  while IFS= read -r p; do
    if [ -z "$p" ]; then continue; fi
    n=$((n + 1))
    say ""
    say "-> $p"
    if [ "$mode" = install ]; then
      case "$KIT/" in
        "$p"/*) say "  skipped: this folder holds the kit itself"; ROWS="$ROWS$p	skipped (kit)	0	0	0	0	$NL"; continue ;;
      esac
      install_one "$p"
    else
      uninstall_one "$p"
    fi
  done <<< "$projects"

  say ""
  if is_on "$ALL"; then
    if [ "$mode" = install ]; then print_table "Project	Result	New	Replaced	Kept	Tracked	Git"
    else print_table "Project	Result	Removed	Kept	Git"; fi
    say ""
  fi
  if [ "$mode" = install ]; then
    say "Done. projects: $n  new: $T_NEW  replaced: $T_REP  kept: $T_KEPT  tracked-skipped: $T_TR"
    if ! is_on "$DRYRUN" && [ "$T_NEW" -gt 0 ]; then
      say "Next: fill in .cursor/rules/project-context.mdc, then start a new Cursor chat."
      if ! is_on "$VISIBLE"; then say "The files are listed in .git/info/exclude, so git and Source Control will not show them. Check any time with --status."; fi
    fi
  else
    say "Done. projects: $n  removed: $T_REM  kept: $T_KEPT"
  fi
}

main "$@"
