#!/usr/bin/env bash
# Bootstrap this dotfiles repository as the Neovim configuration.
#
# Target platform: Linux / macOS / WSL. Windows users should run install.ps1.
#
# The config directory is resolved from the environment, never hard-coded:
#   ${XDG_CONFIG_HOME:-$HOME/.config}/nvim
#
# Usage: ./install.sh [options]
set -euo pipefail

DRY_RUN=0
NO_PLUGINS=0
UPDATE=0
TARGET_OVERRIDE=""

usage() {
  cat <<'EOF'
Bootstrap this dotfiles repository as the Neovim configuration.

Usage: ./install.sh [options]

Options:
  -n, --dry-run      Show what would happen, change nothing
      --no-plugins   Skip the headless "Lazy restore" plugin installation
  -u, --update       Run "git pull --ff-only" before linking
  -t, --target DIR   Override the Neovim config directory (for testing)
  -h, --help         Show this help

Environment:
  XDG_CONFIG_HOME    Config base directory (default: ~/.config)

Windows users: run install.ps1 instead.
EOF
}

ddie() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1 ;;
    --no-plugins) NO_PLUGINS=1 ;;
    -u|--update)  UPDATE=1 ;;
    -t|--target)
      [ $# -ge 2 ] || ddie "--target needs a directory"
      TARGET_OVERRIDE="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) printf 'install.sh: unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# --- pretty output -----------------------------------------------------------

if [ -t 1 ]; then
  C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RESET=$'\033[0m'
else
  C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RESET=""
fi
step() { printf '%s==> %s%s\n' "$C_CYAN" "$*" "$C_RESET"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '%s  ok  %s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn() { printf '%s  !   %s%s\n' "$C_YELLOW" "$*" "$C_RESET"; }

# --- locate the repository ---------------------------------------------------

SELF="${BASH_SOURCE[0]:-$0}"
REPO_ROOT="$(cd -- "$(dirname -- "$SELF")" && pwd -P)" || ddie "cannot locate repository root"
SOURCE="$REPO_ROOT/nvim"

[ -f "$SOURCE/init.lua" ] || ddie \
  "cannot find nvim/init.lua next to this script — run it from the dotfiles repository root"

# --- resolve the Neovim config directory from the environment ----------------

if [ -n "$TARGET_OVERRIDE" ]; then
  TARGET="$TARGET_OVERRIDE"
else
  TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
fi

[ -n "$TARGET" ] || ddie "resolved an empty target directory; pass --target DIR"
TARGET="${TARGET%/}"
case "$TARGET" in
  ""|/|"$HOME"|"${HOME:-/nonexistent}")
    ddie "refusing to use '/${TARGET#/}' as the config directory" ;;
esac

# Resolve a path to its physical location; falls back to the input.
resolve() {
  local p="$1"
  if [ -r "$p" ] || [ -d "$p" ]; then
    if command -v realpath >/dev/null 2>&1; then
      realpath -- "$p" 2>/dev/null && return 0
    fi
    ( cd -- "$p" 2>/dev/null && pwd -P ) && return 0
  fi
  printf '%s\n' "$p"
}

# --- banner ------------------------------------------------------------------

step "dotfiles : $REPO_ROOT"
step "nvim dir : $TARGET"
if [ "$DRY_RUN" = 1 ]; then
  warn "dry run: nothing will be changed"
fi

if [ -d "$TARGET" ] && [ ! -L "$TARGET" ] && \
   [ "$(resolve "$TARGET")" = "$(resolve "$REPO_ROOT")" ]; then
  ddie "this repository is already sitting at $TARGET; clone it elsewhere and re-run"
fi

# --- optional git pull -------------------------------------------------------

if [ "$UPDATE" = 1 ]; then
  if [ -d "$REPO_ROOT/.git" ]; then
    step "git pull --ff-only"
    if [ "$DRY_RUN" = 1 ]; then
      info "skipped (dry run)"
    else
      # nvim 的配置目录就是仓库里的 nvim/，而 lazy.nvim 会就地重写
      # lazy-lock.json：本机插件版本一旦和仓库锁定有出入，工作树就是脏的，
      # git pull --ff-only 会直接拒绝。锁文件以仓库为准，拉取前丢弃本机漂移。
      git -C "$REPO_ROOT" checkout -- nvim/lazy-lock.json 2>/dev/null || true
      if ! git -C "$REPO_ROOT" pull --ff-only; then
        ddie "git pull failed — 运行 git -C \"$REPO_ROOT\" status 检查剩余脏文件后重跑"
      fi
      ok "repository up to date"
    fi
  else
    warn "not a git checkout; --update ignored"
  fi
fi

# --- inspect what is already at the target -----------------------------------

ALREADY_LINKED=0
if [ -L "$TARGET" ] && [ "$(resolve "$TARGET")" = "$(resolve "$SOURCE")" ]; then
  ALREADY_LINKED=1
fi

if [ "$ALREADY_LINKED" = 1 ]; then
  ok "$TARGET already links to $SOURCE"
else
  if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    BACKUP="$TARGET.bak-$(date +%Y%m%d-%H%M%S)"
    while [ -e "$BACKUP" ] || [ -L "$BACKUP" ]; do
      BACKUP="$BACKUP-$$"
    done
    if [ "$DRY_RUN" = 1 ]; then
      info "would move existing config $TARGET -> $BACKUP"
    else
      mv -- "$TARGET" "$BACKUP"
      ok "existing config backed up to $BACKUP"
    fi
  fi

  PARENT="$(dirname -- "$TARGET")"
  if [ ! -d "$PARENT" ]; then
    if [ "$DRY_RUN" = 1 ]; then
      info "would create $PARENT"
    else
      mkdir -p -- "$PARENT"
      ok "created $PARENT"
    fi
  fi

  if [ "$DRY_RUN" = 1 ]; then
    info "would create symlink $TARGET -> $SOURCE"
  else
    ln -s -- "$SOURCE" "$TARGET"
    ok "symlink created: $TARGET -> $SOURCE"
  fi
fi

# --- plugins -----------------------------------------------------------------

if [ "$NO_PLUGINS" = 1 ]; then
  info "skipping plugin installation (--no-plugins)"
elif ! command -v nvim >/dev/null 2>&1; then
  warn "nvim is not on PATH — skipping plugin installation"
elif [ "$DRY_RUN" = 1 ]; then
  info 'would run: nvim --headless "+Lazy! restore" +qa'
else
  step "installing plugins from lazy-lock.json"
  if ! nvim --headless '+Lazy! restore' +qa; then
    warn "Lazy restore failed — trying Lazy sync instead"
    if ! nvim --headless '+Lazy! sync' +qa; then
      warn "plugin installation failed; open nvim and run :Lazy"
    fi
  else
    ok "plugins restored"
  fi
fi

# --- lock drift --------------------------------------------------------------

if [ "$DRY_RUN" = 0 ] && [ "$NO_PLUGINS" = 0 ] && [ -d "$REPO_ROOT/.git" ]; then
  if ! git -C "$REPO_ROOT" diff --quiet -- nvim/lazy-lock.json; then
    warn "lazy-lock.json 与本机实际插件版本仍不一致（restore 没能完全对齐）"
    info "以仓库为准：git -C \"$REPO_ROOT\" checkout -- nvim/lazy-lock.json"
    info "要固定本机版本：commit 后 push；否则下次 --update 会丢弃这里的漂移"
  fi
fi

# --- done --------------------------------------------------------------------

echo
if [ "$DRY_RUN" = 1 ]; then
  warn "dry run complete — re-run without --dry-run to apply"
else
  ok "done — start nvim and wait for the first-run setup to finish"
  info "config:  $TARGET"
  info "plugins: ${XDG_DATA_HOME:-$HOME/.local/share}/nvim (not versioned)"
fi
