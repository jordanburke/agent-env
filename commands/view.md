---
name: view
description: View decrypted secrets from agent-env layers — shows global and project secrets with their sources
allowed-tools:
  - Bash
argument-hint: "[--all]"
---

# View agent-env Secrets

Display the decrypted secrets from all agent-env layers.

## Instructions

1. Run `agent-env view` to show project-level secrets.

2. Run `agent-env view --all` to show the merged global + project view.

3. Present results clearly, indicating which layer each key comes from:
   - **Global**: `~/.config/agent-env/.sops.env`
   - **Project**: `<current-repo>/.sops.env`
   - **Override**: key exists in both layers (project wins)

4. If no secrets are found, suggest running `/agent-env:init` or `/agent-env:check`.

5. **Security note**: Do not log or display actual secret values in full. Show key names and indicate values are present (e.g., `ANTHROPIC_API_KEY=sk-ant-...****`). If the user explicitly asks to see full values, show them.
