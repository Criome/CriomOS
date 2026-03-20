# Repository Guidelines

## Project Structure & Module Organization
- Root Nix entrypoints live in `flake.nix` and `default.nix`.
- Core system modules are under `nix/mkCriomOS/`; zone and sphere builders live in `nix/mkCrioZones/` and `nix/mkCrioSphere/`.
- Home Manager modules are in `nix/homeModule/` (with `min/`, `med/`, `max/` profiles).
- Package and tooling overlays are in `nix/pkdjz/` and `nix/mkPkgs/`.
- Schema concept definitions are in `capnp/` (not consumed by builds — Nix is the production schema).
- Lock files for external service data live in `data/config/` (e.g., `data/config/nordvpn/servers-lock.json`, `data/config/pi/prometheus-model-lock.json`).
- Inputs are pinned in `npins/` and `flake.lock`.

## VCS
- Jujutsu (`jj`) is mandatory. Git is the backend only — do not use git commands directly.
- Commit messages use the Mentci three-tuple CozoScript format:
  `(("CommitType", "scope"), ("Action", "what changed"), ("Verdict", "why"))`
- CommitTypes: fix, feat, doctrine, refactor, schema, contract, codegen, prune, doc, nix, test, migrate.
- Actions: add, remove, rename, rewrite, extract, merge, split, move, replace, fix, extend, reduce.
- Verdicts: error, evolution, dependency, gap, redundancy, violation, drift.

## Build Commands
- For operator work, prefer exact attr builds over broad flake evaluation.
- Never use `<nixpkgs>` / `NIX_PATH` style commands in this repo. Use flake attrs and `nix shell nixpkgs#<pkg>` for ad-hoc tools.
- Build a node OS:
  ```
  nix build .#crioZones.maisiliym.<node>.os --no-link --print-out-paths --refresh
  ```
- Build a home profile:
  ```
  nix build .#crioZones.maisiliym.<node>.hom.<user>.<profile> --no-link --print-out-paths
  ```
  Profiles: `light`, `dark`.
- Test with a local Maisiliym override (not for production):
  ```
  nix build .#crioZones.maisiliym.<node>.os --override-input maisiliym path:/home/li/git/maisiliym --no-link --print-out-paths
  ```
- Update a flake input:
  ```
  nix flake update <input-name>
  ```

## Deployment
The `execute deploy-manifest` command is not yet implemented. Deployment is manual:

1. **Build** the system closure:
   ```
   nix build .#crioZones.maisiliym.<node>.os --no-link --print-out-paths --refresh
   ```

2. **Copy** via Yggdrasil (preferred transport):
   ```
   nix copy --to "ssh://root@[<ygg-address>]" <store-path>
   ```

3. **Activate**:
   ```
   ssh root@<ygg-address> <store-path>/bin/switch-to-configuration switch
   ```

4. **Home profile activation** (as the target user):
   ```
   nix copy --to "ssh://root@[<ygg-address>]" <hom-store-path>
   ssh root@<ygg-address> 'sudo -u <user> <hom-store-path>/activate'
   ```

### Known node addresses (Yggdrasil)
- ouranos: `201:6de1:5500:7cac:2db9:759e:42d2:fb1d`
- prometheus: `202:68bc:1221:1b13:5397:2a56:4aea:d4a9`

DNS resolution (`ouranos.maisiliym.criome`) requires the target node's Unbound to be running. Use Yggdrasil addresses directly for deployment.

## Adding a New Horizon Field (Schema Extension)

When adding node-level configuration (like NordVPN):

1. **CrioSphere input validation** — add the option to `nix/mkCrioSphere/clustersModule.nix` in `nodeSubmodule`.
2. **Horizon options** — add to `nix/mkCrioZones/horizonOptions.nix`.
3. **Horizon wiring** — pass through in `nix/mkCrioZones/mkHorizonModule.nix` (extract from `inputNode`, add to `node` attrset, derive methods if needed).
4. **Module consumption** — create or update the module in `nix/mkCriomOS/` using `mkIf` on the horizon method.
5. **Maisiliym** — set the field in `datom.nix` on the target node, push, then `nix flake update maisiliym` in CriomOS.
6. **capnp** — optionally update `capnp/criosphere.capnp` to keep the concept doc in sync (not required for builds).

## Adding System Packages
- Per-node conditional packages: `nix/mkCriomOS/normalize.nix` — use `sizedAtLeast.min`/`.med`/`.max` or `behavesAs.*` guards.
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

## Testing Guidelines
- Nix evaluation tests live in `nix/tests/`.
- Prefer adding or updating tests alongside module changes, then validate with `nix flake check`.
- Always build the target node's OS before deploying to verify evaluation succeeds.

## Node/Network Truth Guidance
- Maisiliym owns node/network truth in `datom.nix` / `NodeProposal.nodes.*`.
- CriomOS consumes horizon exports from `nix/mkCrioZones/mkHorizonModule.nix`.
- Network modules (`nix/mkCriomOS/network/`) derive host data from horizon.
- When editing network behavior, update Maisiliym first, then CriomOS.
- For production deployment, use `github:LiGoldragon/maisiliym` (not local path overrides).

## Constants
System-wide paths and network constants live in `nix/mkCriomOS/constants.nix`:
- `fileSystem.nordvpn.privateKeyFile` — NordVPN key path
- `fileSystem.yggdrasil.*` — Yggdrasil state/runtime paths
- `network.yggdrasil.*` — Yggdrasil subnet and ports

## Agent-Specific Instructions
- Follow `AGENT_RULES.md`: ALL CAPS paths are immutable; PascalCase paths are stable contracts; lowercase paths are mutable.
