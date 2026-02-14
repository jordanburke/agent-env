# agent-env

**Universal secret injection for AI coding agents.**

One command. Every agent. Secrets stay out of your shell history.

```bash
agent-env run claude        # Claude Code with secrets
agent-env run codex         # Codex with secrets
agent-env run aider         # Aider with secrets
agent-env run <any-cli>     # Any CLI agent
```

## The Problem

AI coding agents need API keys — `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GITHUB_TOKEN`, and more. Today you either:

- **Export them in `.bashrc`** — clutters your shell, leaks to every process
- **Prefix every command** — `ANTHROPIC_API_KEY=sk-... claude` in your history
- **Use direnv** — not designed for secrets, no encryption support
- **Configure each agent separately** — fragmented, different per tool

`agent-env` solves this with a single secrets file, automatic discovery, and optional encryption via SOPS.

## Supported Agents

| Agent | Command | Status |
|-------|---------|--------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `agent-env run claude` | Works |
| [Codex](https://github.com/openai/codex) | `agent-env run codex` | Works |
| [Aider](https://aider.chat) | `agent-env run aider` | Works |
| [Goose](https://github.com/block/goose) | `agent-env run goose` | Works |
| [Cline](https://cline.bot) | `agent-env run cline` | Works |
| [Continue](https://continue.dev) | `agent-env run continue` | Works |
| [Cursor (CLI)](https://cursor.sh) | `agent-env run cursor` | Works |
| [Windsurf (CLI)](https://windsurf.ai) | `agent-env run windsurf` | Works |
| Any CLI tool | `agent-env run <command>` | Works |

## Install

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/jordanburke/agent-env/main/install.sh | bash

# Or clone and install locally
git clone https://github.com/jordanburke/agent-env.git
cd agent-env && ./install.sh
```

Requires: bash 4+. Optional: [sops](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age) for encrypted secrets.

## Quick Start

```bash
# 1. Create a secrets file
agent-env init

# 2. Add your keys
echo "ANTHROPIC_API_KEY=sk-ant-..." >> .env
echo "OPENAI_API_KEY=sk-..." >> .env

# 3. Run your agent
agent-env run claude
```

### With Encryption (SOPS + age)

```bash
# 1. Generate an age key (one-time)
age-keygen -o ~/.config/sops/age/keys.txt

# 2. Create an encrypted secrets file
agent-env init --sops

# 3. Edit secrets (opens in $EDITOR via sops)
agent-env edit

# 4. Run your agent
agent-env run claude
```

## CLI Reference

```
agent-env <command> [options]

COMMANDS
  run <agent> [args...]   Inject secrets and launch an AI agent
  init [--sops]           Create a new secrets file
  edit                    Edit secrets (sops edit or $EDITOR)
  view                    View decrypted secrets
  check                   Verify setup (files, tools, keys)
  upgrade                 Self-update from git
  version                 Print version
  help                    Show usage

RUN OPTIONS
  -v, --verbose           Show discovery and loading steps
  --env FILE              Use a specific secrets file
  --secrets FILE          Alias for --env
  --sops                  Force SOPS mode
  --dotenv                Force dotenv mode
```

## Architecture

```
agent-env run claude
    │
    ▼
  Discover secrets file
  (walk up from PWD → git root → global fallbacks)
    │
    ▼
  Auto-detect format
  (grep "^sops:" → SOPS, else dotenv)
    │
    ▼
  Load secrets into environment
    SOPS:   sops exec-env <file> '<command>'
    dotenv: set -a; source <file>; set +a
    │
    ▼
  exec <agent> "$@"
  (process replacement — no parent lingers)
```

## File Discovery

`agent-env` searches for secrets files in this order:

1. `.sops.env` or `.env` in the current directory
2. Walk up parent directories to the git root
3. `$XDG_CONFIG_HOME/agent-env/` (default: `~/.config/agent-env/`)
4. Home directory (`~/.sops.env` or `~/.env`)

SOPS files (`.sops.env`) always take priority over dotenv (`.env`) when both exist in the same directory.

### Override

Use `--env FILE` to skip discovery and use a specific file:

```bash
agent-env run --env ~/work/.secrets claude
```

## SOPS vs Dotenv

| Feature | Dotenv (`.env`) | SOPS (`.sops.env`) |
|---------|-----------------|---------------------|
| Setup | Zero config | Requires sops + age |
| Security | Plaintext on disk | Encrypted at rest |
| Git-safe | Must be .gitignored | Safe to commit |
| Sharing | Manual copy | Encrypted, sharable |
| Editing | Any editor | `agent-env edit` / `sops` |
| Best for | Solo dev, local | Teams, CI, production |

## MCP Servers

`agent-env` works with MCP servers too — just wrap the MCP command:

```json
{
  "mcpServers": {
    "my-server": {
      "command": "agent-env",
      "args": ["run", "--env", "/path/to/.env", "node", "server.js"]
    }
  }
}
```

## Security Model

- Secrets are loaded into the process environment only — never written to disk by `agent-env`
- Process replacement via `exec` — the `agent-env` process ceases to exist after launch
- SOPS provides encryption-at-rest with age or GPG backends
- No secrets appear in command-line arguments (environment variables only)
- `.env` files are excluded from git via `.gitignore` (enforced by `init`)

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/jordanburke/agent-env/main/uninstall.sh | bash
# or from a local clone:
./uninstall.sh
```

Your secrets files and encryption keys are never removed.

## Related Projects

- [sops](https://github.com/getsops/sops) — Secrets OPerationS, encrypts files with age/GPG/cloud KMS
- [age](https://github.com/FiloSottile/age) — Simple, modern encryption tool
- [direnv](https://direnv.net/) — Per-directory environment variables (not secret-focused)
- [dotenvx](https://dotenvx.com/) — Extended dotenv with encryption
- [1Password CLI](https://developer.1password.com/docs/cli/) — Secret injection from 1Password vaults

## License

MIT - Jordan Burke
