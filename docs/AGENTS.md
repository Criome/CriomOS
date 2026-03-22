# Repository Guidelines

## Project Structure & Module Organization
- Root Nix entrypoints live in `flake.nix` and `default.nix`.
- Core system modules are under `nix/mkCriomOS/`; zone and sphere builders live in `nix/mkCrioZones/` and `nix/mkCrioSphere/`.
- Home Manager modules are in `nix/homeModule/` (with `min/`, `med/`, `max/` profiles).
- Package and tooling overlays are in `nix/pkdjz/` and `nix/mkPkgs/`.
- Schema concept definitions are in `capnp/` (not consumed by builds — Nix is the production schema).
- Lock files for external service data live in `data/config/` (e.g., `data/config/nordvpn/servers-lock.json`, `data/config/pi/prometheus-model-lock.json`).
- Inputs are pinned in `npins/` and `flake.lock`.
- Rust crates live in `src/` (e.g., `src/brightness-ctl/`).
- Nix package wrappers for local crates live in `nix/` (e.g., `nix/brightness-ctl.nix`).

## VCS
- Jujutsu (`jj`) is mandatory. **Never use git commands directly** — git is the backend only. Using git CLI can corrupt jj state.
- All VCS operations use jj: `jj new`, `jj describe`, `jj bookmark set`, `jj git push -b`.
- Commit messages use the Mentci three-tuple CozoScript format:
  `(("CommitType", "scope"), ("Action", "what changed"), ("Verdict", "why"))`
- CommitTypes: fix, feat, doctrine, refactor, schema, contract, codegen, prune, doc, nix, test, migrate.
- Actions: add, remove, rename, rewrite, extract, merge, split, move, replace, fix, extend, reduce.
- Verdicts: error, evolution, dependency, gap, redundancy, violation, drift.

## Build Commands
- **Always push changes before building.** Build from origin, not the dirty working tree — this ensures the nix store cache is populated with correct hashes:
  ```
  jj bookmark set dev -r @ && jj git push -b dev
  jj new
  nix build github:Criome/CriomOS/dev#crioZones.maisiliym.<node>.os --no-link --print-out-paths --refresh
  ```
- Never use `nix build .#` for deployment builds — only for local eval testing.
- Never use `<nixpkgs>` / `NIX_PATH` style commands in this repo. Use flake attrs and `nix shell nixpkgs#<pkg>` for ad-hoc tools.
- Build a home profile:
  ```
  nix build github:Criome/CriomOS/dev#crioZones.maisiliym.<node>.home.<user> --no-link --print-out-paths
  ```
- Build a VM (for ISO-type nodes):
  ```
  nix build github:Criome/CriomOS/dev#crioZones.maisiliym.<node>.vm --no-link --print-out-paths
  ```
- Test with a local Maisiliym override (not for production):
  ```
  nix build .#crioZones.maisiliym.<node>.os --override-input maisiliym path:/home/li/git/maisiliym --no-link --print-out-paths
  ```
- Update a flake input:
  ```
  nix flake update <input-name>
  ```

## Deployment

### Standard deployment (via Yggdrasil)

1. **Build** from origin:
   ```
   nix build github:Criome/CriomOS/dev#crioZones.maisiliym.<node>.os --no-link --print-out-paths --refresh
   ```

2. **Copy** via Yggdrasil:
   ```
   nix copy --to "ssh://root@[<ygg-address>]" <store-path>
   ```

3. **Activate**:
   ```
   ssh root@<ygg-address> <store-path>/bin/switch-to-configuration switch
   ```

4. **Home profile activation** (run as root, `su` to the target user):
   ```
   nix copy --to "ssh://root@[<ygg-address>]" <home-store-path>
   ssh root@<ygg-address> su -l <user> -c '<home-store-path>/activate'
   ```

### Local deployment (already on the target node)
```
ssh root@localhost <store-path>/bin/switch-to-configuration switch
ssh root@localhost su -l <user> -c '<home-store-path>/activate'
```

### Recovery deployment (via asklepios live USB)
When a node is unresponsive, boot the asklepios USB, then:

1. **Find the node** via link-local on ethernet:
   ```
   ping -c 3 ff02::1%enp0s31f6   # find link-local address
   ssh root@<link-local>%enp0s31f6
   ```

2. **Mount the node's drives**:
   ```
   mkdir -p /mnt && mount /dev/nvme0n1p2 /mnt
   mkdir -p /mnt/boot && mount /dev/nvme0n1p1 /mnt/boot
   # For btrfs with subvolumes, mount each subvol:
   mount -o subvol=root /dev/nvme0n1p2 /mnt
   mount -o subvol=home /dev/nvme0n1p2 /mnt/home
   mount -o subvol=nix /dev/nvme0n1p2 /mnt/nix
   mount -o subvol=var /dev/nvme0n1p2 /mnt/var
   ```

3. **Copy the system closure to the node's store** (not the live store):
   ```
   NIX_SSHOPTS="-o StrictHostKeyChecking=no" nix copy --to "ssh://root@<link-local>%<iface>?remote-store=/mnt" <store-path>
   ```

4. **Install**:
   ```
   nixos-install --system <store-path> --no-channel-copy --root /mnt
   ```

5. **Never run `activate` or `switch-to-configuration switch` inside a chroot** — it will break the live USB environment. Only use `nixos-install` or `switch-to-configuration boot`.

### Dangerous operations — DO NOT DO
- **Never** run a system's `activate` script inside a chroot of a mounted install — it overwrites `/etc` on the live system.
- **Never** deploy a major nixpkgs upgrade to a headless machine without testing on a machine with a screen first.
- **Never** deploy to a headless node without the asklepios USB available for recovery.
- **Never** reboot a machine with a live USB still inserted unless you intend to boot from it.

### Known node addresses (Yggdrasil)
- ouranos: `201:6de1:5500:7cac:2db9:759e:42d2:fb1d`
- prometheus: `200:ca41:6b12:fba:d7bc:cfc6:4aaa:165f`

DNS resolution (`ouranos.maisiliym.criome`) requires the target node's Unbound to be running. Use Yggdrasil addresses directly for deployment.

### Link-local access (when Yggdrasil is down)
If the router blocks inter-client TCP but allows IPv6 multicast, or for direct ethernet:
```
# Set NM to not fight over the interface
nmcli con mod "Wired connection 1" ipv4.method disabled ipv6.method link-local

# Discover devices
ping ff02::1%<interface>

# SSH via link-local
ssh root@<link-local>%<interface>
```

### Yggdrasil re-seeding (after disk wipe)
After wiping `/var`, yggdrasil keys are lost. Re-seed:
```
mkdir -p /var/lib/private/yggdrasil
yggdrasil -genconf -json | jq "{PrivateKey}" > /var/lib/private/yggdrasil/preCriad.json
systemctl restart yggdrasil
yggdrasilctl getself  # get new address
```
Then update the address in `maisiliym/datom.nix` and push.

## Nixpkgs Upgrades — MANDATORY CHECKLIST

Major nixpkgs upgrades (>1 month gap) require:

1. **Research breaking changes** — check NixOS release notes, kernel changelogs, and deprecated options.
2. **Check for removed NixOS options** — `programs.light`, `programs.adb`, etc. get removed between releases. Search for deprecation warnings.
3. **Check kernel param compatibility** — GPU params (`amdgpu.gttsize`, `ttm.pages_limit`, `amdgpu.cwsr_enable`) change behavior between kernel versions. Research before keeping them.
4. **Build ALL node OS targets** before deploying any — a param that works on one node may OOM another.
5. **Deploy to a node with a screen first** — never upgrade a headless node without verifying boot on a node you can recover.
6. **Have asklepios USB ready** before deploying to headless nodes.
7. **Test VM first for new node types** — `nix build ...#<node>.vm` before building the ISO.

## Network Architecture

### Edge nodes (ouranos, zeus, tiger, etc.)
- Use **NetworkManager** — wifi, VPN, user switching
- `networking.networkmanager.enable = true`
- Gated by `sizedAtLeast.min && !centerLike`

### Headless nodes (prometheus, balboa)
- Use **systemd-networkd** — static, reliable, no GUI
- `networking.useNetworkd = true` via `nix/mkCriomOS/network/networkd.nix`
- Gated by `centerLike` (= `typeIs.center || typeIs.largeAI`)
- USB ethernet dongles auto-configure as NAT routers (DHCP server on `10.47.0.0/24`)

### SSH access
- **Keys only** — no password auth, ever. Keys come from the criosphere (`datom.nix` preCriomes).
- `settings.PasswordAuthentication = false` is set in `normalize.nix` and must never be changed.

## Adding a New Horizon Field (Schema Extension)

When adding node-level configuration (like NordVPN):

1. **CrioSphere input validation** — add the option to `nix/mkCrioSphere/clustersModule.nix` in `nodeSubmodule`.
2. **Horizon options** — add to `nix/mkCrioZones/horizonOptions.nix`.
3. **Horizon wiring** — pass through in `nix/mkCrioZones/mkHorizonModule.nix` (extract from `inputNode`, add to `node` attrset, derive methods if needed).
4. **Module consumption** — create or update the module in `nix/mkCriomOS/` using `mkIf` on the horizon method.
5. **Maisiliym** — set the field in `datom.nix` on the target node, push, then `nix flake update maisiliym` in CriomOS.
6. **capnp** — optionally update `capnp/criosphere.capnp` to keep the concept doc in sync (not required for builds).

## Adding System Packages
- Per-node conditional packages: `nix/mkCriomOS/normalize.nix` — use `sizedAtLeast.min`/`.med`/`.max`, `behavesAs.*`, or `centerLike` guards.
- ISO nodes (`behavesAs.iso`): keep packages minimal — rescue tools only.
- Home profile packages: `nix/homeModule/min/default.nix` — add to `nixpkgsPackages`, `worldPackages`, or as a standalone `writeScriptBin`.
- Tokenized scripts (gopass-wrapped): follow the pattern in `nix/homeModule/med/default.nix` — use full nix store paths for dependencies (`${pkgs.gopass}/bin/gopass`).

## Lock File Pattern
External service data (NordVPN servers, LLM models) uses JSON lock files in `data/config/`:
- Lock file contains authoritative data with hashes/keys.
- Nix modules read the lock file at build time via `fromJSON (readFile <path>)`.
- Update scripts live alongside the lock file (e.g., `data/config/nordvpn/update-servers`).
- After updating, review the diff with `jj diff`, then push.

### NordVPN server lock
```
nix shell nixpkgs#curl nixpkgs#jq -c ./data/config/nordvpn/update-servers
```

## NordVPN Workflow

### Enabling on a new node
1. Deploy with `nordvpn = false` — the `nordvpn-prepare` service creates `/etc/nordvpn/` for seeding.
2. Run `nordvpn-seed` on the node (from the home profile) — reads the API token from `gopass nordaccount.com/API-Key` and derives the WireGuard private key.
3. Set `nordvpn = true` in Maisiliym `datom.nix` on the target node.
4. Push Maisiliym, `nix flake update maisiliym` in CriomOS, rebuild and deploy.

### Using NordVPN
```
nmcli connection up nordvpn-es-madrid      # connect
nmcli connection down nordvpn-es-madrid    # disconnect
nmcli connection show | grep nordvpn       # list available
```

Split tunnel: IPv4 user traffic goes through the VPN. Yggdrasil (IPv6) and Tailscale (100.64.0.0/10) are exempt.

## Coding Style & Naming Conventions
- Adhere to the Nix-specific Sema object style defined in `NIX_GUIDELINES.md`. The universal principles, with their original Rust examples, are in `GUIDELINES.md` for context.
- Nix files use 2-space indentation and prefer the existing formatting in the file.
- Formatting tools seen in this repo include `nixpkgs-fmt` and `nixfmt-rfc-style`; use the one already used in the area you touch.
- Rust crates follow `~/Mentci/Core/RUST_PATTERNS.md` — Criome Object Rule, single owner, no thiserror, manual error impls.

## Testing Guidelines
- Nix evaluation tests live in `nix/tests/`.
- Prefer adding or updating tests alongside module changes, then validate with `nix flake check`.
- Always build the target node's OS before deploying to verify evaluation succeeds.
- For ISO/rescue nodes, build the VM first (`<node>.vm`) to verify size and functionality before building the ISO.

## Node/Network Truth Guidance
- Maisiliym owns node/network truth in `datom.nix` / `NodeProposal.nodes.*`.
- CriomOS consumes horizon exports from `nix/mkCrioZones/mkHorizonModule.nix`.
- Network modules (`nix/mkCriomOS/network/`) derive host data from horizon.
- When editing network behavior, update Maisiliym first, then CriomOS.
- For production deployment, use `github:LiGoldragon/maisiliym` (not local path overrides).
- `centerLike` = `typeIs.center || typeIs.largeAI` — headless server nodes.

## Constants
System-wide paths and network constants live in `nix/mkCriomOS/constants.nix`:
- `fileSystem.nordvpn.privateKeyFile` — NordVPN key path
- `fileSystem.yggdrasil.*` — Yggdrasil state/runtime paths
- `network.yggdrasil.*` — Yggdrasil subnet and ports

## Agent-Specific Instructions
- Follow `AGENT_RULES.md`: ALL CAPS paths are immutable; PascalCase paths are stable contracts; lowercase paths are mutable.
- **Never use git CLI** — jj only. This is a hard rule.
- **Push before building** — always build from `github:Criome/CriomOS/dev#...`, never from `.#...` for deployment.
- **SSH uses keys only** — never enable password authentication on SSH.
- **Research before kernel upgrades** — GPU params, deprecated options, and driver changes must be verified.
- **Test on screened nodes first** — never deploy untested major changes to headless nodes.
- **Keep asklepios USB ready** — headless deployments require physical recovery capability.
