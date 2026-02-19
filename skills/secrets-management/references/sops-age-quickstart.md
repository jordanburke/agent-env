# SOPS + Age Quickstart

## Prerequisites

```bash
# macOS
brew install sops age

# Verify
sops --version   # 3.x+
age --version    # 1.x+
```

## Generate an Age Key

```bash
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

This creates a file with both the private key and the public key (in a comment). Extract the public key:

```bash
grep "public key:" ~/.config/sops/age/keys.txt | awk '{print $NF}'
# Output: age1abc123...
```

## Create .sops.yaml

At the repo root, create a `.sops.yaml` that tells SOPS which Age key to use for which files:

```yaml
creation_rules:
  - path_regex: \.sops\.env$
    age: age1abc123...your-public-key-here
```

Multiple rules can target different files with different keys. First match wins.

## Create and Encrypt a .sops.env

### Option A: agent-env (recommended)

```bash
agent-env init --sops   # Creates .sops.env with SOPS encryption
agent-env edit           # Opens in $EDITOR, re-encrypts on save
```

### Option B: Manual

Create a plaintext file:

```bash
# .sops.env (before encryption)
ANTHROPIC_API_KEY=sk-ant-...
GITHUB_TOKEN=ghp_...
```

Encrypt in-place:

```bash
sops -e -i .sops.env
```

The file is now encrypted. Individual values are wrapped in `ENC[AES256_GCM,...]` blocks. The file structure (key names) remains visible; only values are encrypted.

## Edit Encrypted Files

```bash
sops .sops.env           # Opens decrypted in $EDITOR, re-encrypts on save
sops infra.yaml          # Same for YAML files
```

Or use agent-env:

```bash
agent-env edit           # Finds and opens the project's .sops.env
```

## Decrypt (View Only)

```bash
sops -d .sops.env        # Print decrypted to stdout
sops -d infra.yaml       # Same for YAML
```

## Encrypt a New File

```bash
sops -e -i newfile.yaml  # Encrypt in-place (must match a .sops.yaml rule)
```

## SOPS Environment Variables

| Variable | Purpose |
|----------|---------|
| `SOPS_AGE_KEY_FILE` | Path to Age private key (default: `~/.config/sops/age/keys.txt`) |
| `SOPS_AGE_KEY` | Inline Age private key (alternative to file) |

**Important**: SOPS 3.11+ may not auto-discover the key at the default XDG path. Set `SOPS_AGE_KEY_FILE` explicitly if decryption fails:

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
```

## Key Rotation

### Add a Team Member

1. Get their Age public key
2. Add it to `.sops.yaml` (comma-separated or as additional recipient)
3. Re-encrypt existing files:

```bash
sops updatekeys .sops.env
sops updatekeys infra.yaml
```

### Remove a Team Member

1. Remove their key from `.sops.yaml`
2. Rotate the data key (re-encrypts with new key):

```bash
sops -r .sops.env
sops -r infra.yaml
```

### Per-Machine Keys

Generate a unique Age key per machine for revocability:

```bash
# On new machine
age-keygen -o ~/.config/sops/age/keys.txt

# Add its public key to .sops.yaml alongside existing keys
# Then re-encrypt all files
sops updatekeys .sops.env
```

To revoke a machine, remove its key and rotate with `sops -r`.
