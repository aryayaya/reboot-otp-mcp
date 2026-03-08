#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
MCP_SOURCE_DIR="$REPO_ROOT/mcp-server"
SKILL_SOURCE="$REPO_ROOT/skills/reboot-guard/SKILL.md"
CONFIG_TEMPLATE="$REPO_ROOT/examples/picoclaw-config.example.json"
ENV_TEMPLATE="$REPO_ROOT/examples/privileged.env.example"
SUDOERS_TEMPLATE="$REPO_ROOT/examples/sudoers.example"
REQUIRED_GOTOOLCHAIN="go1.25.7"
REQUIRED_REBOOT_PATH="/usr/sbin/reboot"
DEFAULT_BINARY_PATH="/usr/local/bin/picoclaw-privileged-mcp"
DEFAULT_MODE="harmless"

TARGET_PROJECT=""
RUNTIME_USER="${USER:-}"
RUNTIME_HOME="${HOME:-}"
BINARY_INSTALL_PATH="$DEFAULT_BINARY_PATH"
ENV_FILE_PATH=""
PICOCLAW_CONFIG_PATH=""
ACTION_MODE="$DEFAULT_MODE"
SECRET_MODE="existing"
TOTP_SECRET=""
SHOULD_WRITE_ENV="no"
SHOULD_WRITE_CONFIG="no"
GO_TOOLCHAIN_OK="no"
PYTHON3_BIN=""

log() {
  printf '\n==> %s\n' "$1"
}

warn() {
  printf 'WARNING: %s\n' "$1" >&2
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

prompt() {
  local label="$1"
  local default_value="${2-}"
  local value
  if [[ -n "$default_value" ]]; then
    read -r -p "$label [$default_value]: " value
    if [[ -z "$value" ]]; then
      value="$default_value"
    fi
  else
    read -r -p "$label: " value
  fi
  printf '%s' "$value"
}

prompt_yes_no() {
  local label="$1"
  local default_value="${2:-yes}"
  local reply
  local hint="[y/n]"
  if [[ "$default_value" == "yes" ]]; then
    hint="[Y/n]"
  elif [[ "$default_value" == "no" ]]; then
    hint="[y/N]"
  fi

  while true; do
    read -r -p "$label $hint " reply
    reply=$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')
    if [[ -z "$reply" ]]; then
      reply="$default_value"
    fi
    case "$reply" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) printf 'Please answer yes or no.\n' ;;
    esac
  done
}

require_command() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || fail "Required command not found: $name"
}

ensure_absolute_path() {
  local value="$1"
  [[ "$value" = /* ]] || fail "Path must be absolute: $value"
}

ensure_directory_exists() {
  local value="$1"
  [[ -d "$value" ]] || fail "Directory does not exist: $value"
}

print_file_preview() {
  local title="$1"
  local body="$2"
  printf '\n--- %s ---\n%s\n' "$title" "$body"
}

render_config_snippet() {
  local env_path="$1"
  local binary_path="$2"
  cat <<EOF
{
  "mcp": {
    "enabled": true,
    "servers": {
      "privileged": {
        "enabled": true,
        "type": "stdio",
        "command": "$binary_path",
        "args": [],
        "env_file": "$env_path"
      }
    }
  }
}
EOF
}

render_env_contents() {
  local secret="$1"
  local mode="$2"
  cat <<EOF
TOTP_SECRET=$secret
REBOOT_ACTION_MODE=$mode
EOF
}

render_env_preview() {
  local mode="$1"
  cat <<EOF
TOTP_SECRET=***hidden***
REBOOT_ACTION_MODE=$mode
EOF
}

render_sudoers_line() {
  local username="$1"
  printf '%s ALL=(root) NOPASSWD: %s\n' "$username" "$REQUIRED_REBOOT_PATH"
}

build_secret_with_python() {
  "$PYTHON3_BIN" - <<'PY'
import base64
import secrets
print(base64.b32encode(secrets.token_bytes(20)).decode('ascii').rstrip('='))
PY
}

write_env_file() {
  local env_path="$1"
  local secret="$2"
  local mode="$3"
  local env_dir
  env_dir=$(dirname "$env_path")
  mkdir -p "$env_dir"
  chmod 700 "$env_dir"
  umask 177
  cat > "$env_path" <<EOF
$(render_env_contents "$secret" "$mode")
EOF
  chmod 600 "$env_path"
}

write_minimal_config() {
  local config_path="$1"
  local env_path="$2"
  local binary_path="$3"
  local config_dir
  config_dir=$(dirname "$config_path")
  mkdir -p "$config_dir"
  cat > "$config_path" <<EOF
$(render_config_snippet "$env_path" "$binary_path")
EOF
}

preflight_checks() {
  log "Preflight checks"
  [[ "$(uname -s)" == "Linux" ]] || fail "This installer only supports Linux."
  require_command systemctl
  require_command sudo
  require_command go
  require_command install
  [[ -x "$REQUIRED_REBOOT_PATH" ]] || fail "Required reboot path not found: $REQUIRED_REBOOT_PATH"
  [[ -d "$MCP_SOURCE_DIR" ]] || fail "Missing source directory: $MCP_SOURCE_DIR"
  [[ -f "$SKILL_SOURCE" ]] || fail "Missing skill source: $SKILL_SOURCE"
  [[ -f "$CONFIG_TEMPLATE" ]] || fail "Missing example file: $CONFIG_TEMPLATE"
  [[ -f "$ENV_TEMPLATE" ]] || fail "Missing example file: $ENV_TEMPLATE"
  [[ -f "$SUDOERS_TEMPLATE" ]] || fail "Missing example file: $SUDOERS_TEMPLATE"

  if GOTOOLCHAIN="$REQUIRED_GOTOOLCHAIN" go version >/dev/null 2>&1; then
    GO_TOOLCHAIN_OK="yes"
  else
    fail "Unable to use GOTOOLCHAIN=$REQUIRED_GOTOOLCHAIN. Install that Go toolchain before continuing."
  fi

  if command -v python3 >/dev/null 2>&1; then
    PYTHON3_BIN=$(command -v python3)
  fi

  printf 'Linux detected: %s\n' "$(uname -sr)"
  printf 'systemctl found: %s\n' "$(command -v systemctl)"
  printf 'sudo found: %s\n' "$(command -v sudo)"
  printf 'go found: %s\n' "$(command -v go)"
  printf 'GOTOOLCHAIN %s available: %s\n' "$REQUIRED_GOTOOLCHAIN" "$GO_TOOLCHAIN_OK"
  printf 'Required reboot path confirmed: %s\n' "$REQUIRED_REBOOT_PATH"
}

collect_inputs() {
  log "Collect operator inputs"

  while true; do
    TARGET_PROJECT=$(prompt "Target Picoclaw project path")
    ensure_absolute_path "$TARGET_PROJECT"
    if [[ -d "$TARGET_PROJECT" ]]; then
      break
    fi
    warn "Target project path does not exist: $TARGET_PROJECT"
  done

  if [[ -z "$RUNTIME_USER" ]]; then
    RUNTIME_USER=$(prompt "Runtime username")
  else
    RUNTIME_USER=$(prompt "Runtime username" "$RUNTIME_USER")
  fi
  [[ -n "$RUNTIME_USER" ]] || fail "Runtime username is required."

  if [[ -z "$RUNTIME_HOME" ]]; then
    RUNTIME_HOME=$(prompt "Runtime home directory")
  else
    RUNTIME_HOME=$(prompt "Runtime home directory" "$RUNTIME_HOME")
  fi
  ensure_absolute_path "$RUNTIME_HOME"
  ensure_directory_exists "$RUNTIME_HOME"

  PICOCLAW_CONFIG_PATH="$RUNTIME_HOME/.picoclaw/config.json"
  ENV_FILE_PATH="$RUNTIME_HOME/.picoclaw/secrets/privileged.env"

  BINARY_INSTALL_PATH=$(prompt "Installed MCP binary path" "$BINARY_INSTALL_PATH")
  ensure_absolute_path "$BINARY_INSTALL_PATH"

  ENV_FILE_PATH=$(prompt "Secret env file path" "$ENV_FILE_PATH")
  ensure_absolute_path "$ENV_FILE_PATH"

  printf '\nChoose action mode:\n'
  printf '  1) harmless  - validate success path without reboot\n'
  printf '  2) real      - valid OTP triggers sudo %s\n' "$REQUIRED_REBOOT_PATH"
  local mode_choice
  while true; do
    mode_choice=$(prompt "Select mode" "1")
    case "$mode_choice" in
      1|harmless)
        ACTION_MODE="harmless"
        break
        ;;
      2|real)
        ACTION_MODE="real"
        break
        ;;
      *)
        printf 'Choose 1/harmless or 2/real.\n'
        ;;
    esac
  done

  printf '\nTOTP secret options:\n'
  printf '  1) use existing secret\n'
  printf '  2) generate a new secret now\n'
  local secret_choice
  while true; do
    secret_choice=$(prompt "Select secret option" "1")
    case "$secret_choice" in
      1|existing)
        SECRET_MODE="existing"
        read -r -s -p "Enter existing TOTP secret: " TOTP_SECRET
        printf '\n'
        [[ -n "$TOTP_SECRET" ]] || fail "TOTP secret cannot be empty."
        break
        ;;
      2|generate)
        SECRET_MODE="generate"
        [[ -n "$PYTHON3_BIN" ]] || fail "python3 is required to generate a new TOTP secret automatically."
        TOTP_SECRET=$(build_secret_with_python)
        [[ -n "$TOTP_SECRET" ]] || fail "Failed to generate TOTP secret."
        break
        ;;
      *)
        printf 'Choose 1/existing or 2/generate.\n'
        ;;
    esac
  done
}

render_summary() {
  local skill_destination="$TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md"
  local config_snippet
  local env_preview
  local sudoers_line

  config_snippet=$(render_config_snippet "$ENV_FILE_PATH" "$BINARY_INSTALL_PATH")
  env_preview=$(render_env_preview "$ACTION_MODE")
  sudoers_line=$(render_sudoers_line "$RUNTIME_USER")

  log "Computed deployment values"
  printf 'Target project: %s\n' "$TARGET_PROJECT"
  printf 'Runtime username: %s\n' "$RUNTIME_USER"
  printf 'Runtime home: %s\n' "$RUNTIME_HOME"
  printf 'Skill destination: %s\n' "$skill_destination"
  printf 'Binary install path: %s\n' "$BINARY_INSTALL_PATH"
  printf 'Picoclaw config path: %s\n' "$PICOCLAW_CONFIG_PATH"
  printf 'Env file path: %s\n' "$ENV_FILE_PATH"
  printf 'Action mode: %s\n' "$ACTION_MODE"
  printf 'Required reboot path: %s\n' "$REQUIRED_REBOOT_PATH"

  print_file_preview "Picoclaw MCP config snippet" "$config_snippet"
  print_file_preview "Secret env file contents" "$env_preview"
  print_file_preview "Sudoers line" "$sudoers_line"

  if [[ "$SECRET_MODE" == "generate" ]]; then
    printf '\nGenerated TOTP secret: %s\n' "$TOTP_SECRET"
    printf 'Add this secret to your authenticator app before testing.\n'
  else
    printf '\nUsing operator-provided TOTP secret. It was not echoed back.\n'
  fi

  prompt_yes_no "Continue with build and file operations?" "no" || fail "Installation cancelled before writing files."
}

build_and_install_binary() {
  log "Build and install MCP binary"
  local parent_dir
  local build_output
  parent_dir=$(dirname "$BINARY_INSTALL_PATH")
  [[ -d "$parent_dir" ]] || fail "Install directory does not exist: $parent_dir"

  build_output=$(mktemp)
  trap 'rm -f "$build_output"' RETURN
  GOTOOLCHAIN="$REQUIRED_GOTOOLCHAIN" go build -C "$MCP_SOURCE_DIR" -o "$build_output"
  install -m 755 "$build_output" "$BINARY_INSTALL_PATH"
  printf 'Installed binary: %s\n' "$BINARY_INSTALL_PATH"
}

install_skill() {
  log "Install skill into target project"
  local skill_destination_dir="$TARGET_PROJECT/.claude/skills/reboot-guard"
  local skill_destination="$skill_destination_dir/SKILL.md"
  mkdir -p "$skill_destination_dir"
  install -m 644 "$SKILL_SOURCE" "$skill_destination"
  printf 'Installed skill: %s\n' "$skill_destination"
}

handle_env_file() {
  log "Handle secret env file"
  if [[ -e "$ENV_FILE_PATH" ]]; then
    warn "Env file already exists: $ENV_FILE_PATH"
  fi
  if prompt_yes_no "Write env file at $ENV_FILE_PATH?" "yes"; then
    write_env_file "$ENV_FILE_PATH" "$TOTP_SECRET" "$ACTION_MODE"
    SHOULD_WRITE_ENV="yes"
    printf 'Wrote env file: %s\n' "$ENV_FILE_PATH"
  else
    SHOULD_WRITE_ENV="no"
    printf 'Skipped env file write. Apply the previewed env contents manually.\n'
  fi
}

handle_config_file() {
  log "Handle Picoclaw config"
  if [[ -e "$PICOCLAW_CONFIG_PATH" ]]; then
    warn "Existing config detected: $PICOCLAW_CONFIG_PATH"
    printf 'This installer will not patch an existing config automatically.\n'
    printf 'Use the previewed JSON snippet to update your config manually.\n'
    SHOULD_WRITE_CONFIG="no"
    return
  fi

  if prompt_yes_no "Create a new minimal Picoclaw config at $PICOCLAW_CONFIG_PATH?" "no"; then
    write_minimal_config "$PICOCLAW_CONFIG_PATH" "$ENV_FILE_PATH" "$BINARY_INSTALL_PATH"
    SHOULD_WRITE_CONFIG="yes"
    printf 'Created config: %s\n' "$PICOCLAW_CONFIG_PATH"
  else
    SHOULD_WRITE_CONFIG="no"
    printf 'Skipped config write. Apply the previewed JSON snippet manually.\n'
  fi
}

print_sudoers_guidance() {
  local sudoers_line
  sudoers_line=$(render_sudoers_line "$RUNTIME_USER")

  log "Sudoers guidance"
  printf 'Apply this line manually after review:\n%s\n' "$sudoers_line"
  printf '\nSuggested destination: /etc/sudoers.d/picoclaw\n'
  printf 'Suggested helper command:\n'
  printf "printf '%%s\\n' '%s' | sudo tee /etc/sudoers.d/picoclaw >/dev/null && sudo chmod 440 /etc/sudoers.d/picoclaw && sudo visudo -cf /etc/sudoers.d/picoclaw\n" "$sudoers_line"
  printf '\nThe installer does not modify sudoers for you.\n'
}

print_final_steps() {
  log "Final next steps"
  printf '1. Review or apply the sudoers line exactly as shown above.\n'
  printf '2. Restart Picoclaw after config, env, binary, and skill changes.\n'
  printf '3. Run the validation sequence from docs/testing.md:\n'
  printf '   - malformed input: /reboot\n'
  printf '   - invalid OTP: /reboot --otp 000000\n'
  printf '   - missing TOTP_SECRET: temporarily remove env entry and expect OTP verification is not configured.\n'
  if [[ "$ACTION_MODE" == "harmless" ]]; then
    printf '   - harmless success path first: /reboot --otp 123456 with a real current OTP\n'
    printf '   - switch REBOOT_ACTION_MODE=real only when ready for a real reboot\n'
  else
    printf '   - you selected real mode, so validate carefully and expect a real reboot on a valid OTP\n'
  fi
  printf '\nSummary:\n'
  printf '  binary installed: %s\n' "$BINARY_INSTALL_PATH"
  printf '  skill installed: %s\n' "$TARGET_PROJECT/.claude/skills/reboot-guard/SKILL.md"
  printf '  env file written: %s\n' "$SHOULD_WRITE_ENV"
  printf '  config file written: %s\n' "$SHOULD_WRITE_CONFIG"
  printf '  Picoclaw config path: %s\n' "$PICOCLAW_CONFIG_PATH"
  printf '  env file path: %s\n' "$ENV_FILE_PATH"
  printf '  action mode: %s\n' "$ACTION_MODE"
}

main() {
  preflight_checks
  collect_inputs
  render_summary
  build_and_install_binary
  install_skill
  handle_env_file
  handle_config_file
  print_sudoers_guidance
  print_final_steps
}

main "$@"
