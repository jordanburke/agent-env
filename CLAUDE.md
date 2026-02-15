# agent-env

Universal secret injection for AI coding agents.

## What This Is

`agent-env` is a single bash script that loads secrets from `.env` (dotenv) or `.sops.env` (SOPS-encrypted) files and injects them into an AI agent's environment via `exec`. It works with any agent that runs as a CLI process.

## Architecture

```
agent-env run claude
    |
    v
  Discover secrets file (walk up from PWD to git root, then global fallbacks)
    |
    v
  Auto-detect format: grep -q "^sops:" → SOPS, else dotenv
    |
    v
  Load secrets into environment
    SOPS:   sops exec-env <file> '<command>'
    dotenv: set -a; source <file>; set +a
    |
    v
  exec <agent> "$@"   (process replacement, no subprocess)
```

## CLI Design (Subcommand-Based)

```
agent-env run [options] <agent> [args...]   # inject secrets and run agent
agent-env init [--sops]                     # create .env or .sops.env
agent-env edit                              # edit secrets file (sops edit or $EDITOR)
agent-env view                              # view decrypted secrets
agent-env check                             # verify setup (files, tools, keys)
agent-env upgrade                           # self-update from git
agent-env version                           # print version
agent-env help                              # show usage
```

### Run Options
- `--verbose` / `-v` — print discovery and loading steps
- `--env FILE` — explicit secrets file path (skip discovery)
- `--sops` — force SOPS mode
- `--dotenv` — force dotenv mode
- `--secrets` — alias for `--env`

## File Discovery Order

1. `.env` or `.sops.env` in PWD
2. Walk parent directories up to git root
3. `~/.config/agent-env/.env` or `~/.config/agent-env/.sops.env`
4. `~/.env` or `~/.sops.env`

SOPS files (`.sops.env`) take priority over dotenv (`.env`) when both exist.

## Supported Agents

| Agent | Command |
|-------|---------|
| Claude Code | `agent-env run claude` |
| Codex | `agent-env run codex` |
| Aider | `agent-env run aider` |
| Goose | `agent-env run goose` |
| Cline | `agent-env run cline` |
| Continue | `agent-env run continue` |
| Cursor (CLI) | `agent-env run cursor` |
| Windsurf (CLI) | `agent-env run windsurf` |
| Any CLI | `agent-env run <command>` |

## Development

### Project Structure
```
agent-env/
  bin/agent-env       # main bash script (~400 lines)
  install.sh          # installer (local or curl-piped)
  uninstall.sh        # clean uninstaller
  README.md           # full documentation
  CLAUDE.md           # this file
  LICENSE             # MIT
  site/               # Astro landing page
    src/
      pages/index.astro
      components/       # Hero, Problem, HowItWorks, AgentGrid, Install, Footer
      layouts/Base.astro
```

### Testing
```bash
# Full test suite (requires bats-core: brew install bats-core)
bats test/agent-env.bats

# Quick smoke tests
bash -n bin/agent-env              # syntax check
./bin/agent-env help               # show usage
./bin/agent-env version            # show version
./bin/agent-env check              # verify setup

# With a test .env
echo "TEST_VAR=hello" > /tmp/test.env
./bin/agent-env run --env /tmp/test.env env | grep TEST_VAR
```

### Landing Page
```bash
cd site
pnpm install
pnpm dev              # dev server
pnpm build            # static build
```

## Security Model

- Secrets never written to disk (except encrypted SOPS files)
- Process replacement via `exec` — no parent process lingers
- SOPS integration for encrypted-at-rest secrets
- No secrets in command-line arguments (env vars only)
- `.env` files excluded from git via `.gitignore`

## Dependencies

### Required
- bash 4+
- An AI agent CLI

### Optional (only for SOPS mode)
- [sops](https://github.com/getsops/sops) — secret operations
- [age](https://github.com/FiloSottile/age) — encryption backend for SOPS
