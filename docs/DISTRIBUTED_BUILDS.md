# Distributed builds — archive's setup

How nodes-as-builders / nodes-as-dispatchers actually works in this
repo, after the 2026-04-27 fix that unblocked the long-broken setup.

## Wire shape

Two NixOS roles per node, derived from the maisiliym proposal:

- **Builder**: a node that *receives* dispatched builds.
  Predicate ([mkHorizonModule.nix](../nix/mkCrioZones/mkHorizonModule.nix)):
  ```
  isBuilder = !typeIs.edge
           && isFullyTrusted
           && (sizedAtLeast.med || behavesAs.center)
           && hasBasePrecriads
  ```
  `hasBasePrecriads = hasNixPreCriad && hasYggPrecriad && hasSshPrecriad`
  — the node must have all three pubkeys registered in the proposal,
  or it won't be considered a builder. Adding a builder = three keys.

- **Dispatcher**: a node that *sends* builds to remote builders.
  Predicate:
  ```
  isDispatcher = !behavesAs.center && isFullyTrusted && sizedAtLeast.min
  ```

`builders` (the list `nix.buildMachines` is built from) =
`filter (n: nodes.${n}.methods.isBuilder) exNodeNames`.

## Receiver side (what `isBuilder` enables)

```nix
nix.sshServe = {
  enable = isBuilder;
  protocol = "ssh-ng";    # nix-daemon --stdio over SSH
  write = true;            # required: clients upload .drv inputs
  trusted = true;          # adds nix-ssh to nix.settings.trusted-users
                           # (without this, builds dispatch but fail)
  keys = dispatchersSshPreCriomes;  # SSH host pubkeys of dispatchers
};
```

**The three previously-missing flags** (`write` / `trusted` /
`protocol`) caused the long-running silent breakage. Without `trusted
= true`, builds dispatch but fail with "user is not allowed to override
system configuration." Without `write = true`, only substitution
works, not build dispatch. Without `protocol = ssh-ng`, you fall back
to the older `nix-store --serve` path.

What `nix.sshServe.enable = true` actually creates:

- System user `nix-ssh` (group `nix-ssh`)
- sshd `Match User nix-ssh` block with `ForceCommand nix-daemon
  --stdio`, `PermitTTY no`, `AllowTcpForwarding no`. No shell, no PTY.
- Authorized keys at `/etc/ssh/authorized_keys.d/nix-ssh`, populated
  from `keys`.

## Dispatcher side (what `isDispatcher` enables)

```nix
nix.distributedBuilds = isDispatcher;
nix.buildMachines = map (b: {
  inherit (b) hostName sshUser sshKey supportedFeatures system systems maxJobs;
  protocol = "ssh-ng";
  speedFactor = 10;
  publicHostKey = b.publicHostKey;
}) (optionals isDispatcher builderConfigs);

programs.ssh.knownHosts = lib.listToAttrs (map (b: {
  name = b.hostName;
  value.publicKey = b.publicHostKeyLine;
}) (optionals isDispatcher builderConfigs));

nix.settings.builders-use-substitutes = isDispatcher;
```

`publicHostKey` is the critical missing piece in the original "TODO -
broken" config: without it, root-no-TTY nix-daemon cannot answer
sshd's first-connection trust prompt and the build silently hangs.
Sourced from each builder's `inputNodes.<n>.preCriomes.ssh`
(populated in `mkBuilder`'s `BuilderConfig`).

## The host-key-as-user-key trick

The dispatcher's nix-daemon runs as **root** with no provisioned user
key — NixOS doesn't auto-generate `/root/.ssh/id_*`. Instead:

- Dispatcher uses **`/etc/ssh/ssh_host_ed25519_key`** (its own SSH
  *host* key) as the daemon's SSH client identity.
- Builder authorizes the dispatcher's **host pubkey** as if it were a
  user key in `nix.sshServe.keys`.

This is the convention nix.dev doesn't write down but that long-time
NixOS users converge on. Properties:

- Fully declarative consumer side (the builder's `keys` list is
  declarative).
- Producer side (dispatcher's host keypair) already exists by virtue of
  `services.openssh.enable` — sshd auto-generates at first boot, mode
  600 root-owned.
- No manual `ssh-keygen` step.

## Bootstrapping a new builder's nix signing key

For a node to satisfy `hasBasePrecriads`, it needs a `nixPreCriome`
(nix signing pubkey) registered in the maisiliym proposal. New
builders bootstrap this once:

```bash
ssh root@<node>.maisiliym.criome '
  mkdir -p /var/lib/nix-serve
  nix-store --generate-binary-cache-key \
    <node>.maisiliym.criome \
    /var/lib/nix-serve/nix-secret-key \
    /var/lib/nix-serve/nix-secret-key.pub
  chmod 600 /var/lib/nix-serve/nix-secret-key
  cat /var/lib/nix-serve/nix-secret-key.pub
'
```

The output is `<node>.maisiliym.criome:<base64>`. Take the base64
portion and add to that node's entry in
[`maisiliym/datom.nix`](https://github.com/LiGoldragon/maisiliym/blob/dev/datom.nix):

```nix
preCriomes = {
  ssh = "AAAAC3NzaC1lZDI1NTE5AAAA...";  # /etc/ssh/ssh_host_ed25519_key.pub (base64 only)
  nixPreCriome = "<base64>";
  nixSigningPublicKey = "<base64>";  # same value (dual key)
  yggdrasil = { ... };
};
```

The signing-key NAME passed to `nix-store --generate-binary-cache-key`
**must** match what archive's projection forms — i.e.
`<criomeDomainName>` *without* a `-1` version suffix. Archive's
projection is just `<domain>:<key>`, no version number.

## Verifying a deploy

After `nixos-rebuild switch` on a node flagged `isBuilder`:

```
getent passwd nix-ssh                      # user exists
grep "Match User nix-ssh" /etc/ssh/sshd_config -A3  # ForceCommand line
ls /etc/ssh/authorized_keys.d/nix-ssh      # dispatchers' pubkeys
grep nix-ssh /etc/nix/nix.conf             # in trusted-users
```

After deploy on a node flagged `isDispatcher`:

```
cat /etc/nix/machines                      # builders list, with publicHostKey at end
grep prometheus /etc/ssh/ssh_known_hosts    # known-hosts populated
```

End-to-end smoke test (forces remote build, ignores binary cache):

```
nix build --max-jobs 0 --impure --expr \
  'let pkgs = import <nixpkgs> {}; in
   pkgs.runCommand "dist-test-'$(date +%s)'" {} \
   "echo built > $out"'
```

The `building '... .drv' on 'ssh-ng://nix-ssh@<host>'` log line is
proof the dispatch happened (don't rely on `uname -n` inside the
sandbox — it returns `localhost` regardless of where it ran).

## Common breakages and their causes

1. **No `nix-ssh` user after deploy** — `isBuilder` evaluated false.
   Most likely `hasBasePrecriads` failed (missing nix or ssh pubkey
   in the maisiliym proposal). Fix: add the three keys.
2. **Builds dispatch but fail "user not allowed to override system
   configuration"** — `nix.sshServe.trusted` was not set. Fix in
   archive's `nix.nix`.
3. **Dispatcher hangs forever on first SSH attempt** — `publicHostKey`
   missing or `programs.ssh.knownHosts` not populated. Fix: ensure
   `BuilderConfig.public_host_key{,_line}` are populated in
   `mkBuilder`.
4. **Heavy LLVM/kernel/chromium drvs build locally instead of
   dispatching** — `supportedFeatures` missing `big-parallel`. Fix in
   `mkBuilder`'s feature list.
5. **`nix.settings.builders` (string) AND `nix.buildMachines` (typed
   option) both set** — the typed option renders into
   `/etc/nix/machines` and points `nix.conf` at it; setting both
   creates conflict. Use only the typed option.

## Where the wiring lives

- Receiver + dispatcher branches: [nix/mkCriomOS/nix.nix](../nix/mkCriomOS/nix.nix)
- `mkBuilder` (BuilderConfig per builder): [nix/mkCrioZones/mkHorizonModule.nix](../nix/mkCrioZones/mkHorizonModule.nix)
- Predicate definitions: same file (`isBuilder`, `isDispatcher`,
  `hasBasePrecriads`).
- Per-node keys (the data): [maisiliym/datom.nix](https://github.com/LiGoldragon/maisiliym/blob/dev/datom.nix)
  `preCriomes` block per node.
