---
name: bootstrap
description: Guide new machine setup for agent-env — install prerequisites, transfer Age key, sync global secrets
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# Bootstrap agent-env on a New Machine

Walk through the complete new machine setup interactively.

## Instructions

### Step 1: Check prerequisites

Run `which sops age agent-env` to see what's installed. Report status for each:
- **sops**: Required for encrypted secrets. Install: `brew install sops` (macOS) or see https://github.com/getsops/sops
- **age**: Required for key generation. Install: `brew install age` (macOS) or see https://github.com/FiloSottile/age
- **agent-env**: The tool itself. Install: `curl -fsSL https://raw.githubusercontent.com/jordanburke/agent-env/main/install.sh | bash`

### Step 2: Check Age key

Check if `~/.config/sops/age/keys.txt` exists. If not, ask the user how they want to get it:

- **Bitwarden CLI**: `bw get notes "age-key" > ~/.config/sops/age/keys.txt && chmod 600 ~/.config/sops/age/keys.txt`
- **SCP**: `scp user@other-machine:~/.config/sops/age/keys.txt ~/.config/sops/age/keys.txt`
- **Generate new**: `age-keygen -o ~/.config/sops/age/keys.txt` (will need to add public key to `.sops.yaml` files and re-encrypt)
- **Manual paste**: Create the file and paste the key content

### Step 3: Verify SOPS decryption

If `~/.config/agent-env/.sops.env` exists, test decryption: `sops -d ~/.config/agent-env/.sops.env`

If it doesn't exist, ask if they want to:
- Copy from another machine: `scp user@other-machine:~/.config/agent-env/.sops.env ~/.config/agent-env/`
- Sync via chezmoi: `chezmoi apply`
- Create fresh: `agent-env init --sops` from any directory

### Step 4: Final verification

Run `agent-env check` and `agent-env view` to confirm everything works.

Report the final status: which tools are installed, whether the Age key is present, whether global secrets decrypt successfully.
