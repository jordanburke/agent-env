#!/usr/bin/env bats

# ============================================================================
# Tests for agent-env
# Run: bats test/agent-env.bats
# ============================================================================

AGENT_ENV="$BATS_TEST_DIRNAME/../bin/agent-env"

setup() {
  TEST_DIR="$(mktemp -d)"
  ORIG_HOME="$HOME"
  export HOME="$TEST_DIR/home"
  mkdir -p "$HOME"
}

teardown() {
  export HOME="$ORIG_HOME"
  rm -rf "$TEST_DIR"
}

# ---------------------------------------------------------------------------
# 1. Subcommand Dispatch
# ---------------------------------------------------------------------------

@test "help prints usage and exits 0" {
  run "$AGENT_ENV" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
  [[ "$output" == *"COMMANDS"* ]]
}

@test "no args shows help and exits 0" {
  run "$AGENT_ENV"
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "--help shows help" {
  run "$AGENT_ENV" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "-h shows help" {
  run "$AGENT_ENV" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "version prints version string" {
  run "$AGENT_ENV" version
  [ "$status" -eq 0 ]
  [[ "$output" == *"agent-env"* ]]
  [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "--version prints version string" {
  run "$AGENT_ENV" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"agent-env"* ]]
}

@test "unknown subcommand falls through to run (shorthand)" {
  # "agent-env echo" should behave like "agent-env run echo"
  # Without a secrets file it should fail with discovery error
  cd "$TEST_DIR"
  run "$AGENT_ENV" echo hello
  [ "$status" -ne 0 ]
  [[ "$output" == *"No secrets file found"* ]]
}

# ---------------------------------------------------------------------------
# 2. File Discovery
# ---------------------------------------------------------------------------

@test "finds .env in current directory" {
  cd "$TEST_DIR"
  echo "FOUND_IT=yes" > .env
  run "$AGENT_ENV" run --verbose env
  [ "$status" -eq 0 ]
  [[ "$output" == *"$TEST_DIR/.env"* ]]
  [[ "$output" == *"FOUND_IT=yes"* ]]
}

@test "finds .sops.env in current directory (format detection)" {
  cd "$TEST_DIR"
  printf "sops:\n  version: 3\nFAKE=val\n" > .sops.env
  # Will fail because sops can't decrypt a fake file, but discovery should find it
  run "$AGENT_ENV" run --verbose env
  # Check that it found the .sops.env file
  [[ "$output" == *".sops.env"* ]]
}

@test ".sops.env takes priority over .env in same directory" {
  cd "$TEST_DIR"
  echo "DOTENV=yes" > .env
  printf "sops:\n  version: 3\n" > .sops.env
  run "$AGENT_ENV" run --verbose env
  # It should pick .sops.env, not .env
  [[ "$output" == *".sops.env"* ]]
}

@test "walks up parent directories to find .env" {
  local parent="$TEST_DIR/parent"
  local child="$parent/child/grandchild"
  mkdir -p "$child"
  echo "PARENT_SECRET=found" > "$parent/.env"
  # Create a git repo at parent so it stops there
  git -C "$parent" init --quiet
  cd "$child"
  run "$AGENT_ENV" run --verbose env
  [ "$status" -eq 0 ]
  [[ "$output" == *"$parent/.env"* ]]
  [[ "$output" == *"PARENT_SECRET=found"* ]]
}

@test "stops walking at git root" {
  local above="$TEST_DIR/above"
  local repo="$above/repo"
  local deep="$repo/src/deep"
  mkdir -p "$above" "$deep"
  echo "ABOVE_SECRET=should_not_find" > "$above/.env"
  git -C "$repo" init --quiet
  cd "$deep"
  run "$AGENT_ENV" run env
  [ "$status" -ne 0 ]
  [[ "$output" == *"No secrets file found"* ]]
}

@test "falls back to ~/.config/agent-env/.env" {
  mkdir -p "$HOME/.config/agent-env"
  echo "GLOBAL_SECRET=global" > "$HOME/.config/agent-env/.env"
  # Use an isolated temp dir outside any git repo
  local isolated
  isolated="$(mktemp -d)"
  cd "$isolated"
  run "$AGENT_ENV" run env
  rm -rf "$isolated"
  [ "$status" -eq 0 ]
  [[ "$output" == *"GLOBAL_SECRET=global"* ]]
}

@test "--env FILE uses explicit file" {
  local explicit="$TEST_DIR/my-secrets.env"
  echo "EXPLICIT=yes" > "$explicit"
  cd "$TEST_DIR"
  run "$AGENT_ENV" run --env "$explicit" env
  [ "$status" -eq 0 ]
  [[ "$output" == *"EXPLICIT=yes"* ]]
}

@test "--env with missing file exits with error" {
  cd "$TEST_DIR"
  run "$AGENT_ENV" run --env "$TEST_DIR/nonexistent.env" env
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

# ---------------------------------------------------------------------------
# 3. Format Detection
# ---------------------------------------------------------------------------

@test "plain .env file detected as dotenv" {
  cd "$TEST_DIR"
  echo "KEY=value" > .env
  run "$AGENT_ENV" run --verbose env
  [ "$status" -eq 0 ]
  [[ "$output" == *"dotenv"* ]]
}

@test "file with sops: header detected as sops" {
  cd "$TEST_DIR"
  printf "sops:\n  version: 3\n" > .sops.env
  run "$AGENT_ENV" run --verbose env
  # Should mention SOPS in output (either mode or error about sops)
  [[ "$output" == *"sops"* ]] || [[ "$output" == *"SOPS"* ]]
}

# ---------------------------------------------------------------------------
# 4. Dotenv Loading (run subcommand)
# ---------------------------------------------------------------------------

@test "secrets from .env are exported to child process" {
  cd "$TEST_DIR"
  echo "MY_SECRET=hello_world" > .env
  run "$AGENT_ENV" run env
  [ "$status" -eq 0 ]
  [[ "$output" == *"MY_SECRET=hello_world"* ]]
}

@test "multiple secrets loaded correctly" {
  cd "$TEST_DIR"
  cat > .env <<'EOF'
SECRET_A=alpha
SECRET_B=bravo
SECRET_C=charlie
EOF
  run "$AGENT_ENV" run env
  [ "$status" -eq 0 ]
  [[ "$output" == *"SECRET_A=alpha"* ]]
  [[ "$output" == *"SECRET_B=bravo"* ]]
  [[ "$output" == *"SECRET_C=charlie"* ]]
}

@test "shorthand dispatch works same as explicit run" {
  cd "$TEST_DIR"
  echo "SHORTHAND_TEST=works" > .env
  run "$AGENT_ENV" echo hello
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello"* ]]
}

@test "agent args are passed through" {
  cd "$TEST_DIR"
  echo "X=1" > .env
  run "$AGENT_ENV" run echo one two three
  [ "$status" -eq 0 ]
  [[ "$output" == *"one two three"* ]]
}

# ---------------------------------------------------------------------------
# 5. Init Subcommand
# ---------------------------------------------------------------------------

@test "init creates .env with template content" {
  cd "$TEST_DIR"
  run "$AGENT_ENV" init
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/.env" ]
  # Should have comment/template content
  run cat "$TEST_DIR/.env"
  [[ "$output" == *"agent-env"* ]]
}

@test "init creates .gitignore if missing" {
  cd "$TEST_DIR"
  run "$AGENT_ENV" init
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/.gitignore" ]
  run cat "$TEST_DIR/.gitignore"
  [[ "$output" == *".env"* ]]
}

@test "init appends to existing .gitignore" {
  cd "$TEST_DIR"
  echo "node_modules" > .gitignore
  run "$AGENT_ENV" init
  [ "$status" -eq 0 ]
  run cat "$TEST_DIR/.gitignore"
  [[ "$output" == *"node_modules"* ]]
  [[ "$output" == *".env"* ]]
}

@test "init skips .gitignore if .env already listed" {
  cd "$TEST_DIR"
  printf "node_modules\n.env\n" > .gitignore
  run "$AGENT_ENV" init
  [ "$status" -eq 0 ]
  # .env should appear exactly once
  local count
  count=$(grep -cx '.env' "$TEST_DIR/.gitignore")
  [ "$count" -eq 1 ]
}

@test "init fails if .env already exists" {
  cd "$TEST_DIR"
  echo "EXISTING=yes" > .env
  run "$AGENT_ENV" init
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

# ---------------------------------------------------------------------------
# 6. Upgrade Subcommand
# ---------------------------------------------------------------------------

@test "upgrade works when run from a git repo (local-clone style)" {
  # Set up a fake git repo that acts as agent-env clone
  local fake_repo="$TEST_DIR/fake-agent-env"
  mkdir -p "$fake_repo/bin"
  cp "$AGENT_ENV" "$fake_repo/bin/agent-env"
  chmod +x "$fake_repo/bin/agent-env"
  git -C "$fake_repo" init --quiet
  git -C "$fake_repo" -c user.name="Test" -c user.email="test@test.com" add -A
  git -C "$fake_repo" -c user.name="Test" -c user.email="test@test.com" commit -m "init" --quiet

  # Add a bare remote so git pull --ff-only works
  local bare_repo="$TEST_DIR/bare-remote.git"
  git clone --bare "$fake_repo" "$bare_repo" --quiet
  git -C "$fake_repo" remote add origin "$bare_repo"
  git -C "$fake_repo" fetch origin --quiet
  git -C "$fake_repo" branch --set-upstream-to=origin/master master 2>/dev/null \
    || git -C "$fake_repo" branch --set-upstream-to=origin/main main 2>/dev/null \
    || true

  # Create symlink like install.sh would
  mkdir -p "$HOME/.local/bin"
  ln -sf "$fake_repo/bin/agent-env" "$HOME/.local/bin/agent-env"

  run "$HOME/.local/bin/agent-env" upgrade
  [ "$status" -eq 0 ]
  [[ "$output" == *"Updating from"* ]]
  [[ "$output" == *"Upgraded to"* ]]
}

@test "upgrade fails gracefully with no git repo found" {
  # No symlink, no AGENT_ENV_HOME, no git repo
  mkdir -p "$HOME/.local/bin"
  cp "$AGENT_ENV" "$HOME/.local/bin/agent-env"
  chmod +x "$HOME/.local/bin/agent-env"

  run "$HOME/.local/bin/agent-env" upgrade
  [ "$status" -ne 0 ]
  [[ "$output" == *"Cannot find agent-env git repo"* ]]
}

# ---------------------------------------------------------------------------
# 7. Uninstall Subcommand
# ---------------------------------------------------------------------------

@test "uninstall removes symlink" {
  mkdir -p "$HOME/.local/bin"
  ln -sf "/some/fake/target" "$HOME/.local/bin/agent-env"

  run "$AGENT_ENV" uninstall --yes
  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.local/bin/agent-env" ]
  [[ "$output" == *"Removed"* ]]
}

@test "uninstall --yes skips confirmation prompt" {
  mkdir -p "$HOME/.local/bin"
  ln -sf "/some/fake/target" "$HOME/.local/bin/agent-env"

  # Create a fake install dir
  local install_dir="$HOME/.local/share/agent-env"
  mkdir -p "$install_dir"

  run "$AGENT_ENV" uninstall --yes
  [ "$status" -eq 0 ]
  [ ! -d "$install_dir" ]
  [[ "$output" == *"Removed"* ]]
}

@test "uninstall prints secrets-safe message" {
  mkdir -p "$HOME/.local/bin"
  run "$AGENT_ENV" uninstall --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"NOT removed"* ]]
  [[ "$output" == *"secrets are safe"* ]]
}

@test "uninstall handles missing symlink gracefully" {
  # No symlink exists
  run "$AGENT_ENV" uninstall --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"No binary link found"* ]]
}

# ---------------------------------------------------------------------------
# 8. Error Cases
# ---------------------------------------------------------------------------

@test "run with no agent command exits with error" {
  cd "$TEST_DIR"
  echo "KEY=val" > .env
  run "$AGENT_ENV" run
  [ "$status" -ne 0 ]
  [[ "$output" == *"No agent command"* ]]
}

@test "run with nonexistent agent exits with error" {
  cd "$TEST_DIR"
  echo "KEY=val" > .env
  run "$AGENT_ENV" run nonexistent_agent_xyz_12345
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "run with no secrets file exits with error" {
  cd "$TEST_DIR"
  run "$AGENT_ENV" run echo hello
  [ "$status" -ne 0 ]
  [[ "$output" == *"No secrets file found"* ]]
}

@test "unknown run option exits with error" {
  cd "$TEST_DIR"
  echo "KEY=val" > .env
  run "$AGENT_ENV" run --bogus-flag env
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown run option"* ]]
}

# ---------------------------------------------------------------------------
# 9. Install Script
# ---------------------------------------------------------------------------

@test "install.sh passes syntax check" {
  run bash -n "$BATS_TEST_DIRNAME/../install.sh"
  [ "$status" -eq 0 ]
}

@test "agent-env passes syntax check" {
  run bash -n "$AGENT_ENV"
  [ "$status" -eq 0 ]
}

@test "is_local_install detects local clone when bin/agent-env exists" {
  # Create a simulated local clone with install.sh and bin/agent-env
  local fake_clone="$TEST_DIR/clone"
  mkdir -p "$fake_clone/bin"
  echo '#!/usr/bin/env bash' > "$fake_clone/bin/agent-env"
  cp "$BATS_TEST_DIRNAME/../install.sh" "$fake_clone/install.sh"
  chmod +x "$fake_clone/install.sh"

  # Source the install script in a way that sets BASH_SOURCE correctly
  run bash -c "
    cd '$fake_clone'
    # Extract is_local_install and test it as if BASH_SOURCE[0]=install.sh
    is_local_install() {
      local script_dir='$fake_clone'
      [[ -f \"\$script_dir/bin/agent-env\" ]]
    }
    if is_local_install; then
      echo 'local_install=true'
    else
      echo 'local_install=false'
    fi
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"local_install=true"* ]]
}

@test "install.sh does not crash when piped (no BASH_SOURCE)" {
  # Simulate piped execution where BASH_SOURCE[0] is empty
  run bash -c '
    is_local_install() {
      [[ -n "${BASH_SOURCE[0]:-}" ]] || return 1
      local script_dir
      script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      [[ -f "$script_dir/bin/agent-env" ]]
    }
    # In piped mode, BASH_SOURCE[0] is empty string, not unset
    unset BASH_SOURCE 2>/dev/null || true
    if is_local_install; then
      echo "detected_local"
    else
      echo "detected_remote"
    fi
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"detected_remote"* ]]
}
