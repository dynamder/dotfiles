#!/usr/bin/env bash
# Bootstrap this dotfiles repository as the Neovim and Emacs configuration.
#
# Target platform: Linux / macOS / WSL. Windows users should run install.ps1.
#
# The config directories are resolved from the environment, never hard-coded:
#   nvim  -> ${XDG_CONFIG_HOME:-$HOME/.config}/nvim
#   emacs -> ~/.emacs.d          (Emacs' own fallback when XDG is absent)
#
# Usage: ./install.sh [options]
set -euo pipefail

DRY_RUN=0
NO_PLUGINS=0
UPDATE=0
TARGET_OVERRIDE=""
EMACS_TARGET_OVERRIDE=""

usage() {
  cat <<'EOF'
Bootstrap this dotfiles repository as the Neovim and Emacs configuration.

Usage: ./install.sh [options]

Options:
  -n, --dry-run      Show what would happen, change nothing
      --no-plugins   Skip the headless "Lazy restore" plugin installation
  -u, --update       Run "git pull --ff-only" before linking
  -t, --target DIR   Override the Neovim config directory (for testing)
  -E, --emacs-target DIR
                     Override the Emacs config directory (default: ~/.emacs.d)
  -h, --help         Show this help

Environment:
  XDG_CONFIG_HOME    Config base directory (default: ~/.config)

Links two directories from this repository:
  nvim  -> ${XDG_CONFIG_HOME:-$HOME/.config}/nvim
  emacs -> ~/.emacs.d

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
    -E|--emacs-target)
      [ $# -ge 2 ] || ddie "--emacs-target needs a directory"
      EMACS_TARGET_OVERRIDE="$2"
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
SOURCE_NVIM="$REPO_ROOT/nvim"
SOURCE_EMACS="$REPO_ROOT/emacs"

[ -f "$SOURCE_NVIM/init.lua" ] || ddie \
  "cannot find nvim/init.lua next to this script — run it from the dotfiles repository root"
[ -f "$SOURCE_EMACS/init.el" ] || ddie \
  "cannot find emacs/init.el next to this script — run it from the dotfiles repository root"

# --- resolve the config directories from the environment ---------------------

if [ -n "$TARGET_OVERRIDE" ]; then
  TARGET="$TARGET_OVERRIDE"
else
  TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
fi

if [ -n "$EMACS_TARGET_OVERRIDE" ]; then
  EMACS_TARGET="$EMACS_TARGET_OVERRIDE"
else
  EMACS_TARGET="$HOME/.emacs.d"
fi

[ -n "$TARGET" ] || ddie "resolved an empty target directory; pass --target DIR"
TARGET="${TARGET%/}"
case "$TARGET" in
  ""|/|"$HOME"|"${HOME:-/nonexistent}")
    ddie "refusing to use '/${TARGET#/}' as the config directory" ;;
esac

[ -n "$EMACS_TARGET" ] || ddie "resolved an empty emacs target; pass --emacs-target DIR"
EMACS_TARGET="${EMACS_TARGET%/}"
case "$EMACS_TARGET" in
  ""|/|"$HOME"|"${HOME:-/nonexistent}")
    ddie "refusing to use '/${EMACS_TARGET#/}' as the emacs config directory" ;;
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
step "emacs dir: $EMACS_TARGET"
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

# --- link each config directory into place -----------------------------------

link_config() {
  local source="$1" target="$2" label="$3"

  if [ -L "$target" ] && [ "$(resolve "$target")" = "$(resolve "$source")" ]; then
    ok "$label already links to $source"
    return 0
  fi

  if [ -L "$target" ]; then
    # 链接本身没有内容，备份没有意义；rm 只删链接，不碰它指向的目录。
    if [ "$DRY_RUN" = 1 ]; then
      info "would remove stale link $target"
    else
      rm -f -- "$target"
      ok "stale link removed: $target"
    fi
  elif [ -e "$target" ]; then
    local backup="$target.bak-$(date +%Y%m%d-%H%M%S)"
    while [ -e "$backup" ] || [ -L "$backup" ]; do
      backup="$backup-$$"
    done
    if [ "$DRY_RUN" = 1 ]; then
      info "would move existing $label $target -> $backup"
    else
      mv -- "$target" "$backup"
      ok "existing $label backed up to $backup"
    fi
  fi

  local parent
  parent="$(dirname -- "$target")"
  if [ ! -d "$parent" ]; then
    if [ "$DRY_RUN" = 1 ]; then
      info "would create $parent"
    else
      mkdir -p -- "$parent"
      ok "created $parent"
    fi
  fi

  if [ "$DRY_RUN" = 1 ]; then
    info "would create symlink $target -> $source"
  else
    ln -s -- "$source" "$target"
    ok "symlink created: $target -> $source"
  fi
}

link_config "$SOURCE_NVIM"  "$TARGET"       "nvim"
link_config "$SOURCE_EMACS" "$EMACS_TARGET" "emacs"

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
  info "nvim  : $TARGET"
  info "plugins: ${XDG_DATA_HOME:-$HOME/.local/share}/nvim (not versioned)"
  info "emacs : $EMACS_TARGET"
  if command -v emacs >/dev/null 2>&1; then
    info "Emacs 不自动联网：进 Emacs 后跑一次 M-x my/bootstrap-packages 装依赖（见 emacs/README.md）。"
  else
    warn "emacs 不在 PATH 上；装好之后进 Emacs 跑一次 M-x my/bootstrap-packages 装依赖。"
  fi
fi
