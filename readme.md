# A more correct `unix`

CriomOS is part of the larger [Sema](https://github.com/criome/sema)
achievement. It aims to provide a *correct* runtime platform for the
[Criome](https://github.com/criome/criome) using linux. It can be thought of as
an evolved version of NixOS, which is used for the bootstrap version.

## Node: maisiliym.prometheus (GMKtec EVO-X2)

- Purpose: produces the Ethernet-first live-image that boots the GMKtec EVO-X2
  as node `maisiliym.prometheus`, which is sourced from the Maisiliym GitHub
  source `github:LiGoldragon/maisiliym` and consumed by nested agents handling bootstrap
  tasks.
- Build path: the image is built via the `crioZones.maisiliym.prometheus.os`
  attribute; agents should run `nix build .#crioZones.maisiliym.prometheus.os
  --no-link --print-out-paths --refresh` from the nested repo to reproduce the artifact.
- Nix usage rule: do not use `<nixpkgs>` / `NIX_PATH` style commands here. Use flake attrs in this repo and registry references such as `nix shell nixpkgs#jq` for ad-hoc environment tools.
- Temporary deployment transport: test the Prometheus Yggdrasil address first and use it when it responds (`200:ca41:6b12:fba:d7bc:cfc6:4aaa:165f` at the time of writing). Localhost is override-only and must pass a `hostname == nodeName` guard before any activation proceeds.
- Deployment command: `execute deploy-manifest --manifest $(nix build .#crioZones.maisiliym.prometheus.deployManifest --no-link --print-out-paths --refresh) --node prometheus`.
- GitHub-only override form when needed: `--override-input maisiliym github:LiGoldragon/maisiliym`.
- Deployment agent note: prefer the project-local `criomos-deployer` agent for exact-attr build + manifest deploy work so the right build is activated on the right node.
- Node/network truth reminder: update `datom.nix` / `NodeProposal.nodes.*` in Maisiliym before touching CriomOS network behavior so the horizon export stays authoritative.
- Hardware: the GMKtec EVO-X2 is AMD-based, so `nix/mkCriomOS/metal/default.nix`
  deliberately keeps it out of the Intel media-driver set and enables
  `hardware.amdgpu` only when `model == "GMKtec EVO-X2"` to keep the driver
  stack neutral yet correct.

  - GPU memory: Vulkan on Strix Halo only sees ~64GB of 128GB unified RAM by default.
    TTM kernel params (`ttm.page_pool_size=27787264 ttm.pages_limit=27787264`) expand
    this to ~106GB. Set in `nix/mkCriomOS/metal/default.nix` for `centerIgnoresSuspend` nodes.
- Networking: the live image is Ethernet-first; `nix/mkCriomOS/normalize.nix`
  enables NetworkManager for sized nodes so a plugged-in cable is detected
  during the initial boot before other transports are considered.
- SSH key expectations: `normalize.nix` already enables the OpenSSH service with
  `ports = [ 22 ]` and default NixOS/OpenSSH host key generation, so first-boot
  sequencing can rely on the standard host-key creation path rather than trying
  to preseed keys.
- Agent integration note: this section is exposed to nested agents so they can
  reconcile the target's purpose, build path, hardware classification, and the
  Ethernet/SSH assumptions when wiring `maisiliym.prometheus` into higher-level
  flows.
