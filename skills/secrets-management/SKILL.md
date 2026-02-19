---
name: secrets-management
description: This skill should be used when the user asks to "manage secrets", "set up agent-env", "configure env vars for MCP", "add a key to sops", "encrypt secrets", "decrypt secrets", "rotate keys", "revoke a key", "new machine setup", "bootstrap secrets", "global vs project secrets", "transfer keys to a new machine", or mentions ".sops.env", "SOPS", "Age encryption", "layered secrets", or "agent-env". Covers encrypted secret management for AI coding agent sessions using SOPS + Age encryption with layered global/project override patterns.
version: 0.1.0
---

# Secret Management with agent-env

Use agent-env to inject secrets from `.env` (plaintext) or `.sops.env` (SOPS-encrypted) files into AI agent environments via process replacement (`exec`). Works with any CLI agent.

## Core Concepts

### Layered Architecture

agent-env loads secrets in two layers (project overrides global):

1. **Global** `~/.config/agent-env/.sops.env` — cross-project keys loaded for every session
2. **Project** `<repo>/.sops.env` — project-specific keys loaded only when present

Place shared keys (ANTHROPIC_API_KEY, GITHUB_TOKEN, AGENTGATEWAY_API_KEY) in the global layer. Place project-specific keys (database URLs, Supabase keys) in the project layer. Project values override global values for the same key.

### File Discovery Order

1. `.sops.env` or `.env` in current directory
2. Walk up parent directories to git root
3. `$XDG_CONFIG_HOME/agent-env/` (default: `~/.config/agent-env/`)
4. Home directory (`~/.sops.env` or `~/.env`)

SOPS files take priority over dotenv when both exist in the same directory.

### SOPS + Age Encryption

SOPS encrypts individual values in YAML or dotenv files using Age public-key cryptography. Encrypted files are safe to commit to git.

- **Age public key**: Used in `.sops.yaml` creation rules
- **Age private key**: `~/.config/sops/age/keys.txt` (never committed)
- **SOPS config**: `.sops.yaml` at repo root defines which Age key encrypts which files

## Common Workflows

### Initialize a Project

```bash
agent-env init --sops          # Create .sops.env with SOPS encryption
agent-env edit                 # Edit secrets (opens in $EDITOR via sops)
agent-env check                # Verify setup
```

Ensure a `.sops.yaml` exists at the repo root with a creation rule for `.sops.env`:

```yaml
creation_rules:
  - path_regex: \.sops\.env$
    age: <public-key>
```

### View Secrets Across Layers

```bash
agent-env view                 # Project secrets only
agent-env view --all           # Global + project (layered)
```

### MCP Environment Variables

`.mcp.json` files reference env vars with `${VAR}` syntax. These resolve from the process environment at runtime. When using `agent-env run claude`, all secrets from both layers are available.

To check which vars a `.mcp.json` needs, scan for `${...}` patterns and verify each exists in either the global or project `.sops.env`.

### Per-Org Encryption Keys

For repositories with multiple orgs, use path-based SOPS rules so each org directory can use a different Age key:

```yaml
creation_rules:
  - path_regex: ^org-a/.*\.yaml$
    age: <org-a-public-key>
  - path_regex: ^org-b/.*\.yaml$
    age: <org-b-public-key>
  - path_regex: \.sops\.env$
    age: <default-public-key>
```

First match wins — place specific rules before general ones.

### New Machine Bootstrap

1. Install prerequisites: `brew install sops age`
2. Transfer Age private key to `~/.config/sops/age/keys.txt` (via Bitwarden CLI, SCP, or password manager)
3. Install agent-env: `curl -fsSL https://raw.githubusercontent.com/jordanburke/agent-env/main/install.sh | bash`
4. Sync global secrets via chezmoi (`chezmoi apply`) or manual copy
5. Verify: `agent-env check && agent-env view`

### Troubleshooting

**"No identity matched any of the recipients"**: SOPS cannot find the Age private key. Verify `SOPS_AGE_KEY_FILE` points to `~/.config/sops/age/keys.txt` or that the file exists at the default XDG path.

**"MAC mismatch"**: The encrypted file is corrupted. Restore from git: `git checkout <file>`. If the file was never valid, recreate it from a template and re-encrypt with `sops -e -i <file>`.

**"No matching creation rule"**: The file path does not match any `path_regex` in `.sops.yaml`. Add a rule or rename the file.

**MCP vars not resolving**: Ensure the session was launched with `agent-env run claude` (or `agent-env claude`). Verify the var exists in `agent-env view --all`.

## Additional Resources

### Reference Files

Consult these when deeper context is needed:
- **`references/layered-secrets.md`** — Consult when setting up multi-repo patterns, debugging override behavior, or understanding global vs project layer resolution
- **`references/sops-age-quickstart.md`** — Consult when setting up SOPS + Age from scratch, generating keys, or managing key rotation

### Example Files

Working configurations in `examples/`:
- **`examples/sops-yaml-basic.yaml`** — Minimal `.sops.yaml` for a single-project setup (start here)
- **`examples/sops-yaml-multi-org.yaml`** — `.sops.yaml` with per-org Age keys and path-based rules (advanced)
