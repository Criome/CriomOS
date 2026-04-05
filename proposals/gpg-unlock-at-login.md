# GPG Key Unlock at Login — Proposal

## Goal

Unlock GPG private key automatically at login using a single password, with hardware-backed security where possible.

## Current State

- GPG keys are managed via gopass in CriomOS
- gpg-agent runs per-user session
- Key passphrase must be entered manually on first use each session
- GNOME Keyring is enabled (`gnome.gnome-keyring.enable`) but not integrated with GPG agent

## Options

### Option 1: pam-gnupg

**How it works:** PAM module intercepts login password, passes it to gpg-agent via `--allow-preset-passphrase`. Key unlocks if GPG passphrase matches login password.

**NixOS integration:** `security.pam.services.login.gnupg.enable = true` (or greetd/regreet PAM service)

**Pros:**
- Simple, well-understood, in nixpkgs
- No additional hardware or infrastructure
- Password stays in memory, never written to disk

**Cons:**
- GPG passphrase must equal login password
- No hardware binding — any machine with the key + password can unlock
- Password change requires changing both login and GPG passphrase

**Research needed:**
- Does it work with regreet (greetd) on niri?
- Which PAM services need it enabled? (login, greetd, swaylock, noctalia lock?)
- Interaction with gnome-keyring which is already enabled

### Option 2: TPM2-sealed GPG passphrase

**How it works:** GPG passphrase (can differ from login password) is encrypted/sealed to TPM2 with PCR policy. At login, a PAM session hook uses `systemd-creds decrypt` or `tpm2-tools` to unseal the passphrase and pass it to gpg-agent.

**Pros:**
- GPG passphrase independent of login password
- Hardware-bound — passphrase only decryptable on this specific machine in its current boot state
- Survives password changes without re-encrypting GPG key

**Cons:**
- PCR policy breaks on kernel/bootloader/initrd updates (needs re-sealing)
- More complex setup and maintenance
- No existing NixOS module — needs custom PAM + systemd integration
- TPM availability varies by machine (ouranos has it, older nodes may not)

**Research needed:**
- Which PCR registers to bind? (PCR 7 for secure boot state is common)
- How to handle re-sealing on nixos-rebuild (activation hook?)
- Does Strix Halo (prometheus) / ouranos have TPM2?
- Interaction with LUKS TPM2 unlock if also used for disk encryption
- Rust tooling: `tpm2-tss` crate maturity

### Option 3: GPG smartcard / YubiKey

**How it works:** GPG private key lives on hardware token (YubiKey, Nitrokey, etc.). gpg-agent talks to the card via PC/SC. Only a PIN is needed per session, and the key never leaves the hardware.

**Pros:**
- Strongest security — key material cannot be extracted
- Works across machines (plug in the key)
- PIN can be cached for session duration
- Well-supported in gpg-agent + NixOS

**Cons:**
- Requires purchasing hardware (~$50-80 per key)
- Key is not recoverable if hardware is lost (need backup key or backup card)
- Requires physical presence of the token
- Subkey migration to card is one-way

**Research needed:**
- YubiKey 5 vs Nitrokey 3 for GPG + FIDO2 + PIV
- Can the smartcard PIN be auto-entered from login password via PAM?
- Backup key strategy (second YubiKey? paper backup of master key?)
- Interaction with existing SSH key setup in CriomOS

### Option 4: Hybrid — pam-gnupg + TPM-backed login

**How it works:** Use pam-gnupg (option 1) but make the login itself TPM-aware. Login password is the GPG passphrase, and the system additionally uses TPM for disk encryption / measured boot. The TPM doesn't directly touch GPG, but the overall security posture is elevated.

**Pros:**
- Simple GPG unlock (pam-gnupg)
- TPM secures the boot chain and disk, not the GPG flow directly
- Practical middle ground

**Cons:**
- GPG passphrase still equals login password
- TPM doesn't add security to the GPG unlock step itself

## Recommendation

Start with **Option 1 (pam-gnupg)** — it's the lowest friction path and solves the immediate UX problem. If hardware tokens are acquired later, migrate to **Option 3**. Option 2 is interesting but the maintenance cost (PCR re-sealing on every nixos-rebuild) may not be worth it.

## Next Steps

- [ ] Verify TPM2 availability on ouranos and prometheus
- [ ] Test pam-gnupg with regreet/greetd on niri
- [ ] Determine which GPG key(s) need auto-unlock (signing key? encryption subkey? all?)
- [ ] Evaluate YubiKey 5C NFC as long-term solution
