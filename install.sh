#!/usr/bin/env sh
# Install the godplans skill into AI coding tool skill directories.
#
# Usage:
#   ./install.sh                       install globally for every detected tool
#   ./install.sh --project [dir]       install into a project (default: cwd)
#   ./install.sh --tools claude,codex  limit targets (agents,claude,factory,cline,windsurf,copilot-cloud)
#   ./install.sh --copy                copy instead of symlink (Windows, some CI)
#   ./install.sh --uninstall           remove exactly what this script created
#   ./install.sh --force               replace or remove an unowned destination
#
# Destinations exploit skill-path convergence, so few targets cover many tools:
#   agents         ~/.agents/skills  or  <project>/.agents/skills
#                  (Codex, Cursor, Zed, VS Code/Copilot, Gemini CLI, OpenCode,
#                   Amp, Windsurf, Kilo, Goose, and most Agent Skills adopters)
#   claude         ~/.claude/skills  or  <project>/.claude/skills
#                  (Claude Code; also read by Cursor, OpenCode, Amp, Windsurf,
#                   Copilot, Cline as compatibility paths)
#   factory        ~/.factory/skills          (Factory Droid, global only)
#   cline          ~/.cline/skills            (Cline, global only)
#   windsurf       ~/.codeium/windsurf/skills (Windsurf native global)
#   copilot-cloud  <project>/.github/skills   (Copilot coding agent, project only)
#
# Tools with no skill support (T3 Chat, Aider, plain chat UIs) use PROMPT.md;
# instructions are printed at the end.

set -eu

unset CDPATH
SRC_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
SKILL_SRC="$SRC_DIR/skills/godplans"
SKILL_NAME="godplans"
VERSION=$(awk -F'"' '/^  version:/ { print $2; exit }' "$SKILL_SRC/SKILL.md")
COPY_MARKER_NAME=".godplans-installed-by-script"
LINK_MARKER_NAME=".$SKILL_NAME-installed-by-script"
COPY_MARKER_VALUE="godplans-installer-v1:copy"
LINK_MARKER_VALUE="godplans-installer-v1:symlink"

MODE="global"
PROJECT_DIR=""
TOOLS="all"
LINK_MODE="symlink"
ACTION="install"
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      MODE="project"
      if [ $# -gt 1 ] && [ "${2#--}" = "$2" ]; then PROJECT_DIR="$2"; shift; else PROJECT_DIR="$PWD"; fi
      ;;
    --global) MODE="global" ;;
    --tools)
      [ $# -gt 1 ] || { echo "--tools needs a comma-separated list" >&2; exit 1; }
      TOOLS="$2"; shift
      ;;
    --copy) LINK_MODE="copy" ;;
    --uninstall) ACTION="uninstall" ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown flag: $1 (try --help)" >&2; exit 1 ;;
  esac
  shift
done

append_tool() {
  case ",$NORMALIZED_TOOLS," in
    *",$1,"*) ;;
    *)
      if [ -n "$NORMALIZED_TOOLS" ]; then
        NORMALIZED_TOOLS="$NORMALIZED_TOOLS,$1"
      else
        NORMALIZED_TOOLS=$1
      fi
      ;;
  esac
}

normalize_tools() {
  if [ "$TOOLS" = "all" ]; then
    NORMALIZED_TOOLS="all"
    return 0
  fi
  case "$TOOLS" in
    ""|,*|*,|*,,*)
      echo "--tools needs a non-empty comma-separated list" >&2
      return 1
      ;;
  esac

  NORMALIZED_TOOLS=""
  remaining_tools=$TOOLS
  while [ -n "$remaining_tools" ]; do
    case "$remaining_tools" in
      *,*)
        requested_tool=${remaining_tools%%,*}
        remaining_tools=${remaining_tools#*,}
        ;;
      *)
        requested_tool=$remaining_tools
        remaining_tools=""
        ;;
    esac
    case "$requested_tool" in
      agents|codex|cursor|zed|vscode|copilot|gemini|gemini-cli|opencode|amp|kilo|goose)
        append_tool agents
        ;;
      claude|claude-code) append_tool claude ;;
      factory|factory-droid) append_tool factory ;;
      cline) append_tool cline ;;
      windsurf) append_tool windsurf ;;
      copilot-cloud) append_tool copilot-cloud ;;
      *)
        echo "Unknown tool: $requested_tool" >&2
        return 1
        ;;
    esac
  done
}

normalize_tools
TOOLS=$NORMALIZED_TOOLS

wants() {
  [ "$TOOLS" = "all" ] && return 0
  case ",$TOOLS," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

if [ "$TOOLS" != "all" ]; then
  if [ "$MODE" = "project" ]; then
    for global_only_tool in factory cline windsurf; do
      if wants "$global_only_tool"; then
        echo "Tool $global_only_tool is not available in project mode" >&2
        exit 1
      fi
    done
  elif wants copilot-cloud; then
    echo "Tool copilot-cloud is not available in global mode" >&2
    exit 1
  fi
fi

if [ "$MODE" = "project" ]; then
  [ -d "$PROJECT_DIR" ] || { echo "No such project dir: $PROJECT_DIR" >&2; exit 1; }
  PROJECT_DIR=$(CDPATH= cd -- "$PROJECT_DIR" && pwd -P)
fi

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

marker_value() {
  sed -n '1p' "$1" 2>/dev/null
}

link_marker_target() {
  sed -n '2p' "$1" 2>/dev/null
}

is_link_marker() {
  owned_link_marker=$1
  [ -f "$owned_link_marker" ] &&
    [ ! -L "$owned_link_marker" ] &&
    [ "$(marker_value "$owned_link_marker")" = "$LINK_MARKER_VALUE" ] &&
    [ -n "$(link_marker_target "$owned_link_marker")" ]
}

is_owned_copy() {
  owned_copy_dest=$1
  owned_copy_marker="$owned_copy_dest/$COPY_MARKER_NAME"
  [ -d "$owned_copy_dest" ] &&
    [ ! -L "$owned_copy_dest" ] &&
    [ -f "$owned_copy_marker" ] &&
    [ ! -L "$owned_copy_marker" ] &&
    [ "$(marker_value "$owned_copy_marker")" = "$COPY_MARKER_VALUE" ]
}

is_owned_link() {
  owned_link_dest=$1
  owned_link_root=$2
  owned_link_marker="$owned_link_root/$LINK_MARKER_NAME"
  [ -L "$owned_link_dest" ] || return 1
  is_link_marker "$owned_link_marker" || return 1
  recorded_link_target=$(link_marker_target "$owned_link_marker")
  if command -v readlink >/dev/null 2>&1; then
    owned_link_target=$(readlink "$owned_link_dest" 2>/dev/null) || return 1
    [ "$owned_link_target" = "$recorded_link_target" ]
  else
    owned_link_target=$(CDPATH= cd -- "$owned_link_dest" 2>/dev/null && pwd -P) || return 1
    recorded_link_target=$(CDPATH= cd -- "$recorded_link_target" 2>/dev/null && pwd -P) || return 1
    [ "$owned_link_target" = "$recorded_link_target" ]
  fi
}

is_owned() {
  is_owned_copy "$1" || is_owned_link "$1" "$2"
}

preflight_place() {
  preflight_label=$1
  preflight_root=$2
  preflight_dest="$preflight_root/$SKILL_NAME"
  preflight_link_marker="$preflight_root/$LINK_MARKER_NAME"

  if path_exists "$preflight_dest" && ! is_owned "$preflight_dest" "$preflight_root"; then
    if [ "$FORCE" -ne 1 ]; then
      if [ "$ACTION" = "uninstall" ]; then
        echo "Refusing to remove unowned destination: $preflight_dest ($preflight_label). Use --force to override." >&2
      else
        echo "Refusing to replace unowned destination: $preflight_dest ($preflight_label). Use --force to override." >&2
      fi
      return 1
    fi
  fi

  if [ "$ACTION" = "install" ] && [ "$LINK_MODE" = "symlink" ] &&
     path_exists "$preflight_link_marker" && ! is_link_marker "$preflight_link_marker" &&
     [ "$FORCE" -ne 1 ]; then
    echo "Refusing to replace unowned ownership marker: $preflight_link_marker. Use --force to override." >&2
    return 1
  fi
}

copy_skill() {
  copy_dest=$1
  cp -R "$SKILL_SRC" "$copy_dest"
  # Running the skill's Python helper from a checkout can leave bytecode beside
  # it. That is local build output, never part of the installed skill.
  find "$copy_dest" -name __pycache__ -type d -prune -exec rm -rf {} +
  find "$copy_dest" -name '*.pyc' -type f -exec rm -f {} +
  if ! printf '%s\n' "$COPY_MARKER_VALUE" > "$copy_dest/$COPY_MARKER_NAME"; then
    rm -rf "$copy_dest"
    echo "Could not record ownership for copied destination: $copy_dest" >&2
    return 1
  fi
}

place() {
  place_label=$1
  place_root=$2
  place_dest="$place_root/$SKILL_NAME"
  place_link_marker="$place_root/$LINK_MARKER_NAME"

  if [ "$ACTION" = "uninstall" ]; then
    if path_exists "$place_dest"; then
      rm -rf "$place_dest"
      echo "Removed $place_dest ($place_label)"
    fi
    if is_link_marker "$place_link_marker"; then
      rm -f "$place_link_marker"
    fi
    return 0
  fi

  mkdir -p "$place_root"
  if path_exists "$place_dest"; then
    rm -rf "$place_dest"
  fi
  if path_exists "$place_link_marker" &&
     { is_link_marker "$place_link_marker" || [ "$FORCE" -eq 1 ]; }; then
    rm -rf "$place_link_marker"
  fi

  if [ "$LINK_MODE" = "symlink" ] && ln -s "$SKILL_SRC" "$place_dest" 2>/dev/null; then
    if ! printf '%s\n%s\n' "$LINK_MARKER_VALUE" "$SKILL_SRC" > "$place_link_marker"; then
      rm -rf "$place_dest"
      echo "Could not record ownership for linked destination: $place_dest" >&2
      return 1
    fi
    echo "Linked  $place_dest -> $SKILL_SRC ($place_label)"
  else
    if path_exists "$place_dest"; then
      rm -rf "$place_dest"
    fi
    copy_skill "$place_dest"
    echo "Copied  $SKILL_SRC -> $place_dest ($place_label)"
  fi
}

run_targets() {
  target_operation=$1
  if [ "$MODE" = "project" ]; then
    wants agents        && "$target_operation" "Agent Skills convention" "$PROJECT_DIR/.agents/skills"
    wants claude        && "$target_operation" "Claude Code"             "$PROJECT_DIR/.claude/skills"
    wants copilot-cloud && "$target_operation" "Copilot coding agent"    "$PROJECT_DIR/.github/skills"
  else
    wants agents && "$target_operation" "Agent Skills convention" "${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
    wants claude && "$target_operation" "Claude Code"             "${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
    if wants factory && { [ "$TOOLS" != "all" ] || [ -d "$HOME/.factory" ]; }; then
      "$target_operation" "Factory Droid" "$HOME/.factory/skills"
    fi
    if wants cline && { [ "$TOOLS" != "all" ] || [ -d "$HOME/.cline" ]; }; then
      "$target_operation" "Cline" "$HOME/.cline/skills"
    fi
    if wants windsurf && { [ "$TOOLS" != "all" ] || [ -d "$HOME/.codeium" ]; }; then
      "$target_operation" "Windsurf" "$HOME/.codeium/windsurf/skills"
    fi
  fi
  return 0
}

run_targets preflight_place
run_targets place

if [ "$ACTION" = "install" ]; then
  cat <<EOF

godplans v$VERSION installed.

Invoke: /godplans (Claude Code, Cursor, VS Code, Zed, Factory)
        \$godplans (Codex)   @godplans (Windsurf)   auto-trigger elsewhere

Alternative install: npx skills add hannsxpeter/godplans

No-skill-support tools:
  T3 Chat: paste PROMPT.md into Settings > Customization, or attach it to a chat.
  Aider:   aider --read PROMPT.md   (or add to .aider.conf.yml read: list)
  Any chat UI: paste PROMPT.md as the system prompt.
EOF
fi
