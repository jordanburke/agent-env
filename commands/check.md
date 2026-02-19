---
name: check
description: Verify agent-env setup — checks key file, global secrets, project secrets, and SOPS decryption
allowed-tools:
  - Bash
---

# Check agent-env Setup

Run agent-env's built-in verification and report results.

## Instructions

1. Run `agent-env check` and capture the output.

2. If agent-env is not installed, inform the user and suggest installation.

3. If issues are found, provide actionable guidance:
   - **Missing Age key**: Run `age-keygen -o ~/.config/sops/age/keys.txt` or transfer from another machine
   - **Missing global secrets**: Run `agent-env init --sops` from any directory, or copy `~/.config/agent-env/.sops.env` from another machine
   - **Missing project secrets**: Run `/agent-env:init` in the current project
   - **SOPS decryption failure**: Verify `SOPS_AGE_KEY_FILE` is set or Age key exists at `~/.config/sops/age/keys.txt`

4. If all checks pass, confirm the setup is healthy.
