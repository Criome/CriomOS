# Repository Guidelines

## Project Structure & Module Organization
- Root Nix entrypoints live in `flake.nix` and `default.nix`.
- Core system modules are under `nix/mkCriomOS/`; zone and sphere builders live in `nix/mkCrioZones/` and `nix/mkCrioSphere/`.
- Home Manager modules are in `nix/homeModule/` (with `min/`, `med/`, `max/` profiles).
- Package and tooling overlays are in `nix/pkdjz/` and `nix/mkPkgs/`.
- Schema concept definitions are in `capnp/` (not consumed by builds — Nix is the production schema).
- LLM model config (single source of truth): `data/config/largeAI/llm.json` — serves `llm.nix`, llama.cpp router, and pi agent settings.
- Lock files for external service data live in `data/config/` (e.g., `data/config/nordvpn/servers-lock.json`).
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

## Context Hygiene

**Never let Nix store paths enter the conversation context.** Store paths are content-addressed, change with every input change, and are useless as stable references. They waste context window space and provide no actionable information.

- Capture store paths in shell variables: `result=$(nix build ... --print-out-paths)`
- Chain build → deploy in a single command: `ssh root@localhost nix-env -p ... --set "$(nix build ... --print-out-paths)"`
- Never print, log, or display store paths to the user or in tool output unless debugging a specific path issue.

## Build Commands

**Always push before building.** Build from origin, not the dirty tree:
```
jj bookmark set main -r @ && jj git push -b main
jj new
```

Build attrs: `github:Criome/CriomOS#crioZones.maisiliym.<node>.<target>`

| Target | What |
|--------|------|
| `.os` | System without home profiles |
| `.fullOs` | System with home-manager users |
| `.home.<user>` | Standalone home profile |
| `.vm` | QEMU VM (for ISO-type nodes) |
| `.deployManifest` | JSON deploy manifest |

**Build locally** (eval testing only):
```
nix eval .#crioZones.maisiliym.<node>.os.name --no-write-lock-file
```

**Build on the target node** (preferred — store paths land directly, no copy needed):
```
ssh root@<node> systemd-run --unit=<name>-build \
  nix build github:Criome/CriomOS#crioZones.maisiliym.<node>.os \
    --no-link --print-out-paths --refresh --no-write-lock-file
```
Check progress: `journalctl -u <name>-build -f --no-pager`

Headless nodes need `--no-write-lock-file` (no git on PATH in minimal profiles).

**Build from a different machine** (then copy):
```
nix build github:Criome/CriomOS#crioZones.maisiliym.<node>.os \
  --no-link --print-out-paths --refresh
```

**`--refresh` is required** after pushing — nix caches flake refs and won't pick up new commits without it. Alternative: use the explicit commit hash in the URL.

**Local Maisiliym override** (not for production):
```
nix build .#crioZones.maisiliym.<node>.os \
  --override-input maisiliym path:/home/li/git/maisiliym --no-link --print-out-paths
```

**Update a flake input:**
```
nix flake update <input-name>
```

Never use `<nixpkgs>` / `NIX_PATH` in this repo. Use `nix shell nixpkgs#<pkg>` for ad-hoc tools.

## Deployment

### Standard deployment

1. **Push and build** (on the target node or locally):
   ```
   ssh root@<node> systemd-run --unit=<node>-build \
     nix build github:Criome/CriomOS#crioZones.maisiliym.<node>.os \
       --no-link --print-out-paths --refresh --no-write-lock-file
   ```
   Get the store path from: `journalctl -u <node>-build --no-pager | tail -3`

2. **Copy** (only if built on a different machine):
   ```
   nix copy --to "ssh://root@<node>" <store-path>
   ```

3. **Set profile and activate**:
   ```
   ssh root@<node> 'nix-env -p /nix/var/nix/profiles/system --set <store-path> && \
     <store-path>/bin/switch-to-configuration switch'
   ```
   `nix-env --set` updates the system profile so the bootloader picks the right generation.
   Without it, a reboot may boot an old generation.

4. **If rebooting** (e.g. kernel param changes):
   ```
   ssh root@<node> 'nix-env -p /nix/var/nix/profiles/system --set <store-path> && \
     <store-path>/bin/switch-to-configuration boot && reboot'
   ```
   Use `boot` instead of `switch` when you want changes to take effect only after reboot.

### Home profile activation

Local (current node):
```
"$(nix build .#crioZones.<cluster>.<node>.home.<user> --no-link --print-out-paths)"/activate
```

Remote:
```
path=$(nix build .#crioZones.<cluster>.<node>.home.<user> --no-link --print-out-paths)
nix copy --to "ssh://root@<node>" "$path"
ssh root@<node> su -l <user> -c "\"$path\"/activate"
```

Never split build and activate into separate commands that expose store paths — use subshell expansion or shell variables so the path stays in the shell, not in agent context. Store paths in the conversation are noise.

Alternatively, `fullOs` includes home-manager — `switch-to-configuration switch` activates both OS and home profiles in one step.

### Node addressing

| Method | When to use | Example |
|--------|------------|---------|
| DNS name | Unbound running on target | `prometheus.maisiliym.criome` |
| Yggdrasil address | Always works (direct mesh) | `200:ca41:6b12:fba:d7bc:cfc6:4aaa:165f` |
| WAN IP | br-lan down, router still on home LAN | `192.168.1.20` (prometheus) |
| Link-local | Yggdrasil down, direct ethernet | `fe80::...%enp0s31f6` |

DNS requires the target's Unbound to be running. For deployment, prefer DNS when available, fall back to Ygg addresses. When br-lan is down (e.g. after hostapd restart), the WAN interface (`eno1`) is still reachable on the home LAN.

Known addresses:
- ouranos: Ygg `201:6de1:5500:7cac:2db9:759e:42d2:fb1d`
- prometheus: Ygg `200:ca41:6b12:fba:d7bc:cfc6:4aaa:165f`, WAN `192.168.1.20`

### SSH-safe long builds

On headless nodes, builds may outlast the SSH connection. Options:
- **`systemd-run`** (as root, preferred): `systemd-run --unit=<name> nix build ...` — survives SSH disconnect, logs to journal. Check with `journalctl -u <name>`.
- **`pueue`** (as user): `pueue add -- nix build ...` — **requires `loginctl enable-linger <user>`**. Without linger, systemd kills the user session (including pueued and all its tasks) when SSH disconnects. Check with `pueue status`.

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
- **Never** restart `hostapd` or reload the wifi module on a router node you're connected through — it tears down `br-lan`, dropping ALL bridge members (USB ethernet, wifi) and killing Yggdrasil. Use the WAN IP (`192.168.1.20` for prometheus) as a fallback path before touching network services.
- **Never** run a system's `activate` script inside a chroot of a mounted install — it overwrites `/etc` on the live system.
- **Never** deploy a major nixpkgs upgrade to a headless machine without testing on a machine with a screen first.
- **Never** deploy to a headless node without the asklepios USB available for recovery.
- **Never** reboot a machine with a live USB still inserted unless you intend to boot from it.
- **Never** deploy a model that exceeds the GPU memory budget without testing interactively first (see LLM section).
- **Never** edit config files in a panic to "fix" a deployment — verify what's actually deployed first, then make one deliberate change.
- **Never** use hashes from web searches or model cards for `fetchurl` — always `nix-prefetch-url` on the target node and pin HuggingFace URLs to specific repo commits (`resolve/<commit>/` not `resolve/main/`).

### Bridge recovery (after hostapd/wifi restart)
When `br-lan` is recreated, USB ethernet ports and kea lose their state:
```
# Re-add USB ethernet to bridge
ssh root@<wan-ip> 'ip link set enp197s0f4u1 master br-lan'

# Restart kea (stale socket after bridge recreation)
ssh root@<wan-ip> 'systemctl restart kea-dhcp4-server'

# Verify bridge members
ssh root@<wan-ip> 'bridge link show'
```

### MT7925 wifi radio stuck (no beacons)
If hostapd reports ENABLED but the AP is invisible to clients, the MT7925 radio is stuck. Reload the driver:
```
ssh root@<wan-ip> 'systemctl stop hostapd && modprobe -r mt7925e && sleep 2 && modprobe mt7925e && sleep 3 && systemctl start hostapd'
```
Then re-add USB ethernet to the bridge (see above) — the bridge is recreated during this process.

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
- Gated by `sizedAtLeast.min && !behavesAs.router && !behavesAs.iso && !behavesAs.center`

### Headless nodes (prometheus, balboa)
- Use **systemd-networkd** — static, reliable, no GUI
- `networking.useNetworkd = true` via `nix/mkCriomOS/network/networkd.nix`
- Gated by `behavesAs.center && !behavesAs.router`
- USB ethernet dongles auto-bridge to `br-lan` (matched by driver: `cdc_ether r8152 ax88179_178a asix`)
- **DNS**: unbound listens on `127.0.0.1` only; router nodes also listen on `10.18.0.1` (LAN gateway)

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
- Per-node conditional packages: `nix/mkCriomOS/normalize.nix` — use `sizedAtLeast.min`/`.med`/`.max`, `behavesAs.*`, or `behavesAs.center` guards.
- ISO nodes (`behavesAs.iso`): keep packages minimal — rescue tools only.
- Home profile packages: `nix/homeModule/min/default.nix` — add to `nixpkgsPackages`, `worldPackages`, or as a standalone `writeScriptBin`.
- Tokenized scripts (gopass-wrapped): follow the pattern in `nix/homeModule/med/default.nix` — use full nix store paths for dependencies (`${pkgs.gopass}/bin/gopass`).

## Lock File / Config Pattern
External service data uses JSON config files in `data/config/`:
- `data/config/largeAI/llm.json` — LLM models (single source of truth for services, proxy, and pi agent).
- `data/config/nordvpn/servers-lock.json` — NordVPN server list with hashes.
- Nix modules read these at build time via `fromJSON (readFile <path>)`.
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

## LLM Runtime (largeAI nodes)

### Architecture
- Single config file: `data/config/largeAI/llm.json` — defines models, presets, pi agent settings.
- `nix/mkCriomOS/llm.nix` reads the config and generates one router service + `models-dir` + `presets.ini`.
- `nix/homeModule/min/default.nix` reads the same config and generates `.pi/agent/models.json` + settings for the pi coding agent.
- The LLM module loads on any node with `typeIs.largeAI` or `typeIs."largeAI-router"`.
- Client nodes discover the largeAI node via `horizon.exNodes` — no hardcoded addresses.
- Provider name, gateway URL, and enabled models are all derived at eval time from the config + horizon topology.

### Router mode (llama.cpp native)
A single `llama-server` process manages all models via `--models-dir` and `--models-preset`:
- `--models-max 1` — only one model loaded at a time; LRU-evicts on swap
- `--sleep-idle-seconds 300` — unloads model weights after 5 min idle; next request auto-reloads. Frees GPU memory so GFXOFF can fully power-gate the shaders. Configured via `sleepIdleSeconds` in `llm.json`.
- Each model runs as a child process — killed on swap, memory fully freed
- `POST /models/load {"model":"<id>"}` — explicit load
- `POST /models/unload {"model":"<id>"}` — explicit unload
- `GET /v1/models` — list all models and their load status
- Requesting an unloaded model auto-loads it (evicts current model)
- Per-model config (ctx-size, flags) via INI presets generated from `llm.json`
- Service name: `${nodeName}-llama-router` (e.g. `prometheus-llama-router`)
- Single port: 11434 for all models

### Power management (headless nodes)
- **CPU EPP**: `behavesAs.center` nodes set `energy_performance_preference` to `power` via tmpfiles rule. This aggressively downclocks idle cores, reducing fan noise and power. Clocks still ramp on load (~5-10ms latency).
- **GPU display engine**: `amdgpu.dc=0` kernel param on nodes without video output (`!hasVideoOutput && !behavesAs.iso && hasYggPrecriad && hasSshPrecriad`). Skips DCN initialization, saves ~1W idle.
- **GFXOFF**: Automatic on RDNA 3.5 — shaders power-gate when GPU is idle (0% busy). No configuration needed. Verified working on Strix Halo via `/sys/kernel/debug/dri/0/amdgpu_gfxoff`.
- **Idle model unload**: `sleepIdleSeconds` in `llm.json` (default 300s) unloads model weights after idle, freeing GTT memory and letting the memory controller drop to its lowest state.

### Strix Halo GPU memory
- Vulkan on Strix Halo defaults to ~64GB visible device memory despite 128GB unified RAM.
- **TTM kernel params are required** to expose more:
  ```
  ttm.page_pool_size=27787264  # 5/6 of 128GB in pages
  ttm.pages_limit=27787264
  ```
  These are set in `nix/mkCriomOS/metal/default.nix` for `behavesAs.center` nodes.
- `hardware.graphics.enable = true` is required for Vulkan ICD — without it, llama-server falls back to CPU.
- `fit = off` in presets.ini bypasses llama.cpp's conservative memory check that rejects models on unified memory APUs.
- **GPU memory budget with TTM**: ~106GB usable. Without TTM: ~64GB. Calculate model weights + KV cache before deploying.
- `MemoryMax=110G` and `MemoryHigh=100G` on the router service protect system services (hostapd, SSH) from model OOM.

### Model prefetch workflow (FOD pattern)
Large GGUF models must be prefetched directly on the target node. **Never use hashes from web searches or model cards** — HuggingFace re-uploads files under the same URL without versioning.

```
# On prometheus — prefetch and get real hash:
ssh root@prometheus.maisiliym.criome \
  'nix-prefetch-url <huggingface-url> --type sha256'

# Convert to SRI:
nix hash to-sri --type sha256 <hash>

# Pin the HF URL to a specific repo commit:
# resolve/main/file.gguf → resolve/<commit>/file.gguf
# Get the commit: curl -s https://huggingface.co/api/models/<org>/<repo> | jq .sha

# Add to llm.json with the SRI hash and pinned URL
# Create GC root to prevent garbage collection:
ssh root@prometheus.maisiliym.criome \
  'nix-store --add-root /nix/var/nix/gcroots/llm-<name> -r /nix/store/<path>'
```
When `nix build` evaluates `pkgs.fetchurl` with the same hash, it finds the store path already present — zero re-download.

### Testing a model interactively (BEFORE committing to config)
```
ssh root@prometheus.maisiliym.criome

# Use the router's load/unload API:
curl -s http://127.0.0.1:11434/models/load \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-no-key-required" \
  -d '{"model":"qwen3-8b"}'

# Test inference:
curl http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-no-key-required" \
  -d '{"model":"qwen3-8b","messages":[{"role":"user","content":"hi"}],"max_tokens":8}'

# Check memory:
free -h

# List all models and their status:
curl -s http://127.0.0.1:11434/v1/models \
  -H "Authorization: Bearer sk-no-key-required" | jq '.data[] | {id, status: .status.value}'
```

### Current deployment (March 2026)
- **Default model**: Qwen3.5-122B-A10B Q4_K_M — 76.5GB, 10B active MoE, 128K context
- **Available**: 7 models (5GB–76.5GB), hot-swappable on demand
- **Speed**: ~26 tok/s on Vulkan GPU (Qwen3.5-122B)
- **Port**: 11434 (single router port for all models)
- **Service**: `prometheus-llama-router`

## Debugging Commands

### Network
```
# Find devices on link-local ethernet
ping ff02::1%enp0s31f6

# Set NM to link-local only (stops DHCP from disconnecting)
nmcli connection modify "Wired connection 1" ipv4.method link-local ipv6.method link-local
nmcli connection up "Wired connection 1"

# Scan for WiFi AP
nmcli device wifi rescan; sleep 5; nmcli device wifi list

# Check hostapd
ssh root@<host> 'systemctl is-active hostapd; journalctl -u hostapd --no-pager -n 10'

# Check bridge and its members
ssh root@<host> 'ip link show br-lan; ip addr show br-lan; bridge link show'

# Check unbound listening (should include 10.18.0.1 on router nodes)
ssh root@<host> 'ss -ulnp | grep unbound'

# Check kea DHCP
ssh root@<host> 'systemctl is-active kea-dhcp4-server; journalctl -u kea-dhcp4-server --no-pager -n 5'

# Check networkd config files
ssh root@<host> 'ls /etc/systemd/network/'
```

### LLM services
```
# Check router service
ssh root@prometheus.maisiliym.criome 'systemctl status prometheus-llama-router --no-pager -l | head -20'

# Check model loading logs
ssh root@prometheus.maisiliym.criome 'journalctl -u prometheus-llama-router --no-pager -n 20'

# Check Vulkan GPU detection
ssh root@prometheus.maisiliym.criome 'journalctl -u prometheus-llama-router --no-pager | grep -iE "vulkan|gpu|device|offload|layers"'

# Check OOM kills
ssh root@prometheus.maisiliym.criome 'dmesg | grep -i oom | tail -5'

# Check TTM params active
ssh root@prometheus.maisiliym.criome 'cat /proc/cmdline | tr " " "\n" | grep ttm'

# List models and load status
curl -s http://prometheus.maisiliym.criome:11434/v1/models \
  -H "Authorization: Bearer sk-no-key-required" | jq '.data[] | {id, status: .status.value}'

# Quick inference test
curl -s --max-time 30 http://prometheus.maisiliym.criome:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-no-key-required" \
  -d '{"model":"qwen3.5-122b-a10b","messages":[{"role":"user","content":"hi"}],"max_tokens":8}' | jq '.timings.predicted_per_second'

# Swap to a different model
curl -s http://prometheus.maisiliym.criome:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-no-key-required" \
  -d '{"model":"qwen3-8b","messages":[{"role":"user","content":"hi"}],"max_tokens":8}'
```

### GPU power
```
# GPU power draw (microwatts)
ssh root@<host> 'cat /sys/class/drm/card0/device/hwmon/hwmon*/power1_average'

# GFXOFF state (1=shaders gated, 0=awake)
ssh root@<host> 'od -An -tu4 -N4 /sys/kernel/debug/dri/0/amdgpu_gfxoff'

# GPU clocks and utilization
ssh root@<host> 'cat /sys/class/drm/card0/device/pp_dpm_sclk; echo "Busy:"; cat /sys/class/drm/card0/device/gpu_busy_percent'

# GTT (GPU memory) usage
ssh root@<host> 'cat /sys/class/drm/card0/device/mem_info_gtt_used'

# CPU EPP setting
ssh root@<host> 'cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference'

# Check amdgpu.dc=0 in boot params
ssh root@<host> 'cat /proc/cmdline | tr " " "\n" | grep amdgpu'
```

### Nix store
```
# Verify store integrity
ssh root@<host> 'nix-store --verify --check-contents 2>&1 | tail -5'

# List GC roots (model shards)
ssh root@<host> 'ls -la /nix/var/nix/gcroots/llm-*'

# Check which system profile is active
ssh root@<host> 'readlink /nix/var/nix/profiles/system; readlink /run/current-system'

# Check what system booted vs what's deployed
ssh root@<host> 'readlink /run/current-system; readlink result'
```

### NixOS deploy recovery
```
# Emergency: mask a crash-looping service
ssh root@<host> 'systemctl stop <service>; systemctl mask <service>'
# Note: mask fails on NixOS (read-only /etc/systemd/system). Use kill instead:
ssh root@<host> 'systemctl stop <service>; pkill -f <process-name>'

# Force set system profile and switch in one shot
ssh root@<host> 'GOOD=$(readlink result); nix-env -p /nix/var/nix/profiles/system --set $GOOD; $GOOD/bin/switch-to-configuration switch; $GOOD/bin/switch-to-configuration boot; echo DONE'
```

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
- `behavesAs.largeAI` = `typeIs.largeAI || typeIs."largeAI-router"` — nodes serving LLM inference.
- `behavesAs.center` = `typeIs.center || behavesAs.largeAI` — headless server nodes.
- `behavesAs.router` = `typeIs.hybrid || typeIs.router || typeIs."largeAI-router"` — nodes running hostapd + NAT.
- `hasVideoOutput` = `behavesAs.edge` — nodes with a display attached.

## Tree-Sitter Grammar Integration

### Adding a new tree-sitter grammar

Two patterns exist — follow the one matching the upstream:

**Flake grammar** (preferred, e.g. `tree-sitter-cozo`):
1. Grammar repo has its own `flake.nix` exposing `packages.${system}.default`.
2. CriomOS flake input: `tree-sitter-X = { url = "github:Criome/tree-sitter-X"; inputs.nixpkgs.follows = "nixpkgs"; };`
3. `nix/pkdjz/adHoc.nix`: pass-through lambda — `lambda = { src, pkgs }: src.packages.${pkgs.system}.default;`
4. `nix/pkdjz/mkEmacs/default.nix`: add to function args and `treeSitterPackages`.
5. `nix/pkdjz/mkEmacs/packages.el`: `define-derived-mode` with `treesit-font-lock-rules` under the `treesit` use-package block.

**Source-only grammar** (e.g. `tree-sitter-capnp`):
1. Upstream has no flake — `flake = false` in CriomOS input.
2. `nix/pkdjz/adHoc.nix`: `stdenv.mkDerivation` that compiles `src/parser.c` → `.so`.
3. Same Emacs wiring as above.

### Emacs tree-sitter mode requirements

`treesit-major-mode-setup` alone provides **zero highlighting**. A working mode requires:
```elisp
(setq-local treesit-font-lock-feature-list '((comment string) (keyword type) ...))
(setq-local treesit-font-lock-settings (treesit-font-lock-rules ...))
(treesit-parser-create 'lang)
(treesit-major-mode-setup)
```

The `.scm` query files in the grammar repo are for the tree-sitter CLI, **not for Emacs**.

### Emacs 29+ theme face requirement

Custom themes must define these faces or tree-sitter highlighting is invisible:
`font-lock-number-face`, `font-lock-operator-face`, `font-lock-function-call-face`,
`font-lock-bracket-face`, `font-lock-property-use-face`, `font-lock-escape-face`,
`font-lock-delimiter-face`, `font-lock-misc-punctuation-face`, `font-lock-variable-use-face`.

These are defined in the ignis theme (`nix/homeModule/baseModule.nix`).

## Constants
System-wide paths and network constants live in `nix/mkCriomOS/constants.nix`:
- `fileSystem.nordvpn.privateKeyFile` — NordVPN key path
- `fileSystem.yggdrasil.*` — Yggdrasil state/runtime paths
- `network.yggdrasil.*` — Yggdrasil subnet and ports

## Agent-Specific Instructions
- **Never use git CLI** — jj only. This is a hard rule.
- **Push before building** — always build from `github:Criome/CriomOS/dev#...`, never from `.#...` for deployment.
- **SSH uses keys only** — never enable password authentication on SSH.
- **Research before kernel upgrades** — GPU params, deprecated options, and driver changes must be verified.
- **Test on screened nodes first** — never deploy untested major changes to headless nodes.
- **Keep asklepios USB ready** — headless deployments require physical recovery capability.
