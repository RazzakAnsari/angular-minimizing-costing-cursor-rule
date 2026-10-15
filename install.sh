#!/usr/bin/env bash
# minimize-cursor-cost-rule installer for macOS / Linux / WSL
# Author: Abdul Razzak (github.com/RazzakAnsari) - MIT licensed
#
# Remote (from your Angular project root):
#   curl -fsSL https://raw.githubusercontent.com/RazzakAnsari/minimize-cursor-cost-rule/main/install.sh | bash
# Remote with flags:
#   curl -fsSL https://raw.githubusercontent.com/RazzakAnsari/minimize-cursor-cost-rule/main/install.sh | bash -s -- --dry-run
# Local (from a clone):
#   bash <clone>/install.sh --target . --dry-run
#
# Environment variables work too:
#   MCCR_TARGET, MCCR_RULES, MCCR_TOOL, MCCR_DRYRUN=1, MCCR_FORCE=1, MCCR_INDEXIGNORE=1
#
# Copies rule files only. Never overwrites without --force, never runs
# npm / ng / git, never edits source code.

set -euo pipefail

TARBALL_URL="https://github.com/RazzakAnsari/minimize-cursor-cost-rule/archive/refs/heads/main.tar.gz"
ALWAYS_ON="guardrails response-style tool-budget project-context"

TARGET="${MCCR_TARGET:-$(pwd)}"
RULES="${MCCR_RULES:-all}"
TOOL="${MCCR_TOOL:-cursor}"
DRYRUN="${MCCR_DRYRUN:-0}"
FORCE="${MCCR_FORCE:-0}"
INDEXIGNORE="${MCCR_INDEXIGNORE:-0}"

say() { printf '%s\n' "$*"; }
fail() { printf 'minimize-cursor-cost-rule: %s\n' "$*" >&2; exit 1; }
usage() {
  say "Usage: install.sh [--target DIR] [--rules all|name,name] [--tool cursor|agents|claude|all]"
  say "                  [--index-ignore] [--dry-run] [--force]"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:?--target needs a value}"; shift 2 ;;
    --rules) RULES="${2:?--rules needs a value}"; shift 2 ;;
    --tool) TOOL="${2:?--tool needs a value}"; shift 2 ;;
    --index-ignore) INDEXIGNORE=1; shift ;;
    --dry-run) DRYRUN=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; fail "unknown option: $1" ;;
  esac
done

is_on() { case "$1" in 1|true|yes) return 0 ;; *) return 1 ;; esac; }

case "$TOOL" in cursor|agents|claude|all) ;; *) fail "unknown tool '$TOOL' (use cursor, agents, claude or all)" ;; esac
[ -d "$TARGET" ] || fail "target folder not found: $TARGET"
TARGET="$(cd "$TARGET" && pwd)"

if [ ! -f "$TARGET/angular.json" ]; then
  if is_on "$FORCE"; then
    say "Warning: no angular.json in $TARGET - continuing because force is set."
  else
    say "minimize-cursor-cost-rule: no angular.json in $TARGET."
    say "Run this from your Angular project root, or use --force / MCCR_FORCE=1."
    exit 1
  fi
fi

TMP_DIR=""
cleanup() { [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"; return 0; }
trap cleanup EXIT

SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/kit/.cursor/rules" ]; then
  KIT="$SCRIPT_DIR/kit"
  say "Using local kit: $KIT"
else
  command -v curl >/dev/null 2>&1 || fail "curl is required"
  command -v tar >/dev/null 2>&1 || fail "tar is required"
  TMP_DIR="$(mktemp -d)"
  say "Downloading $TARBALL_URL"
  curl -fsSL "$TARBALL_URL" | tar -xz -C "$TMP_DIR"
  ROOT="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  [ -n "$ROOT" ] || fail "downloaded archive was empty"
  KIT="$ROOT/kit"
fi

case "$KIT/" in "$TARGET"/*) fail "target is the kit itself. Run this from your Angular project root." ;; esac

RULE_DIR="$KIT/.cursor/rules"
AVAILABLE="$(for f in "$RULE_DIR"/*.mdc; do basename "$f" .mdc; done | tr '\n' ' ')"

if [ "$RULES" = "all" ]; then
  CHOSEN="$AVAILABLE"
else
  CHOSEN="$ALWAYS_ON"
  IFS=',' read -r -a ASKED <<< "$RULES"
  for r in "${ASKED[@]}"; do
    r="$(printf '%s' "$r" | tr -d '[:space:]')"
    [ -z "$r" ] && continue
    case " $AVAILABLE " in *" $r "*) ;; *) fail "unknown rule '$r'. Available: $AVAILABLE" ;; esac
    case " $CHOSEN " in *" $r "*) ;; *) CHOSEN="$CHOSEN $r" ;; esac
  done
fi

tag=""
is_on "$DRYRUN" && tag="  (dry run - nothing is written)"
say "minimize-cursor-cost-rule by Abdul Razzak -> $TARGET  [tool=$TOOL rules=$RULES]$tag"

n_new=0; n_replaced=0; n_kept=0
place() {
  local from="$1" rel="$2" to="$TARGET/$2" word
  if [ -e "$to" ] && ! is_on "$FORCE"; then
    say "  keep     $rel (already there)"
    n_kept=$((n_kept+1))
    return 0
  fi
  if [ -e "$to" ]; then word="replace"; else word="new"; fi
  if is_on "$DRYRUN"; then
    say "  would $word $rel"
  else
    mkdir -p "$(dirname "$to")"
    cp "$from" "$to"
    printf '  %-8s %s\n' "$word" "$rel"
  fi
  if [ "$word" = "replace" ]; then n_replaced=$((n_replaced+1)); else n_new=$((n_new+1)); fi
}

if [ "$TOOL" = "cursor" ] || [ "$TOOL" = "all" ]; then
  for r in $CHOSEN; do place "$RULE_DIR/$r.mdc" ".cursor/rules/$r.mdc"; done
  is_on "$INDEXIGNORE" && place "$KIT/cursorindexingignore.txt" ".cursorindexingignore"
fi
if [ "$TOOL" = "agents" ] || [ "$TOOL" = "all" ]; then place "$KIT/AGENTS.md" "AGENTS.md"; fi
if [ "$TOOL" = "claude" ] || [ "$TOOL" = "all" ]; then place "$KIT/CLAUDE.md" "CLAUDE.md"; fi
place "$KIT/PROMPTS.md" "PROMPTS.md"

say ""
say "Done. new: $n_new  replaced: $n_replaced  kept: $n_kept"
if ! is_on "$DRYRUN" && [ "$n_new" -gt 0 ]; then
  say "Next: fill in .cursor/rules/project-context.mdc, then start a new Cursor chat."
fi
