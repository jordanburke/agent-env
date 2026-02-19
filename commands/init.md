---
name: init
description: Initialize agent-env in the current project — creates .sops.yaml and .sops.env with SOPS encryption
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
argument-hint: "[--dotenv]"
---

# Initialize agent-env

Initialize agent-env secret management in the current project directory.

## Instructions

1. Check if agent-env is installed by running `which agent-env`. If not found, inform the user to install it first: `curl -fsSL https://raw.githubusercontent.com/jordanburke/agent-env/main/install.sh | bash`

2. Check if `.sops.env` or `.env` already exists in the current directory. If so, inform the user and ask whether to overwrite or skip.

3. Check if `.sops.yaml` exists at the repo root. If not, ask the user for their Age public key (check `~/.config/sops/age/keys.txt` for the public key line first) and create one:

```yaml
creation_rules:
  - path_regex: \.sops\.env$
    age: <their-public-key>
```

4. Run `agent-env init --sops` to create the encrypted `.sops.env`.

5. If the `--dotenv` argument was provided, run `agent-env init` instead (plaintext `.env`).

6. Run `agent-env check` to verify the setup.

7. Report what was created and next steps (use `agent-env edit` to add keys).
