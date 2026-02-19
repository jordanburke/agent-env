# Layered Secrets Architecture

## How Layers Work

agent-env implements a two-layer secret loading system:

```
~/.config/agent-env/.sops.env    <- Global base (always loaded)
<project>/.sops.env              <- Project overlay (loaded if present)
```

### Resolution Rules

1. Global secrets load first from `~/.config/agent-env/.sops.env`
2. Project secrets load second from the nearest `.sops.env` (discovered via file walk)
3. If the same key exists in both, the **project value wins**
4. Keys unique to either layer are always included

### What Goes Where

**Global layer** — keys used across most/all projects:
- `ANTHROPIC_API_KEY` — needed by Claude Code itself
- `GITHUB_TOKEN` — GitHub API access
- `JOPLIN_TOKEN` — note-taking integration
- `AGENTGATEWAY_API_KEY` — MCP proxy access
- `CONCORD_DOKPLOY` — deployment API token

**Project layer** — keys specific to one repo:
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` — project database
- `DATABASE_URL` — project-specific connection string
- `API_SECRET` — project API keys
- `R2_ENDPOINT`, `R2_ACCESS_KEY_ID` — project storage

### Viewing Layers

```bash
# See only project-level secrets
agent-env view

# See merged result (global + project)
agent-env view --all

# Skip global layer entirely
agent-env run --no-global claude
```

## Multi-Repo Patterns

### Shared MCP Configuration

Place shared MCP keys in the global layer. Then any project's `.mcp.json` can reference them without its own `.sops.env`:

```json
{
  "mcpServers": {
    "dokploy": {
      "env": { "DOKPLOY_API_KEY": "${CONCORD_DOKPLOY}" }
    }
  }
}
```

The `${CONCORD_DOKPLOY}` resolves from the global layer — no per-project configuration needed.

### Project-Specific Overrides

A project can override a global key. For example, if the global layer has `GITHUB_TOKEN=ghp_personal` but a project needs a different token:

```bash
# In project .sops.env:
GITHUB_TOKEN=ghp_org_specific_token
```

This project's sessions use the org token; all other projects use the personal one.

### DevOps Repository Pattern

A central devops/infra repo can organize secrets per org:

```
devops/
├── .sops.yaml           # Path-based rules with per-org Age keys
├── .sops.env            # agent-env session keys
├── infra.yaml           # Shared infra secrets (SOPS-encrypted)
├── cquenced/infra.yaml  # Org-specific secrets (different Age key possible)
└── civala/infra.yaml    # Org-specific secrets (different Age key possible)
```

The `.sops.yaml` uses path-based rules so each org can use a different Age key:

```yaml
creation_rules:
  - path_regex: ^cquenced/.*\.yaml$
    age: <cquenced-key>
  - path_regex: ^civala/.*\.yaml$
    age: <civala-key>
  - path_regex: ^infra\.yaml$
    age: <personal-key>
```

### Syncing Global Secrets Across Machines

Since `~/.config/agent-env/.sops.env` is SOPS-encrypted, it's safe to track in a dotfiles repo:

```bash
# Add to chezmoi (one-time)
chezmoi add ~/.config/agent-env/.sops.env

# On new machine
chezmoi apply
```

The Age private key (`~/.config/sops/age/keys.txt`) must be transferred separately via secure out-of-band method (Bitwarden CLI, SCP, password manager).
