# A more correct `unix`

CriomOS is part of the larger [Sema](https://github.com/criome/sema)
achievement. It aims to provide a *correct* runtime platform for the
[Criome](https://github.com/criome/criome) using linux. It can be thought of as
an evolved version of NixOS, which is used for the bootstrap version.

## Node: maisiliym.prometheus (GMKtec EVO-X2)

- Purpose: produces the Ethernet-first live-image that boots the GMKtec EVO-X2
  as node `maisiliym.prometheus`, which is sourced from the `maisiliym`
  `prometheus-node` branch and consumed by nested agents handling bootstrap
  tasks.
- Build path: the image is built via the `crioZones.maisiliym.prometheus.os`
  attribute; agents should run `nix build .#crioZones.maisiliym.prometheus.os
  --no-link` from the nested repo to reproduce the artifact.
- Hardware: the GMKtec EVO-X2 is AMD-based, so `nix/mkCriomOS/metal/default.nix`
  deliberately keeps it out of the Intel media-driver set and enables
  `hardware.amdgpu` only when `model == "GMKtec EVO-X2"` to keep the driver
  stack neutral yet correct.
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
