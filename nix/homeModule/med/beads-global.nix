{
  lib,
  pkgs,
  config,
  user,
  inputs,
  ...
}:
let
  inherit (user.methods) isCodeDev sizedAtLeast;
  system = pkgs.stdenv.hostPlatform.system;

  beadsPkg = inputs.mentci-tools.packages.${system}.beads;
  doltPkg = pkgs.dolt;

  port = 13306;
  sharedServerDir = "${config.home.homeDirectory}/.beads/shared-server";
  # bd launches dolt with cmd.Dir = <sharedServerDir>/dolt and expects the
  # sql-server's working tree to be that path. See beads v1.0.2
  # internal/doltserver/doltserver.go:175-204, 770.
  doltDataDir = "${sharedServerDir}/dolt";
  portFile = "${sharedServerDir}/dolt-server.port";

  # One-shot seed script: idempotently ensures the beads_global workspace
  # + database exist on the shared server. Runs after beads-global.service
  # is up. See beads v1.0.2 cmd/bd/init.go:578-610, 1269-1275, 1717-1761.
  # bd refuses to init in any dir under ~/.beads/ ("cannot initialize bd
  # inside a .beads directory"). Park the seed workspace under XDG state.
  globalInitWorkspace = "${config.xdg.stateHome}/beads-global-init";
  # Wrapper: cd into the seed workspace first so `bd --global` has a shared-
  # server-mode workspace to resolve against. Needed because bd --global
  # refuses to run from embedded-mode projects due to project-id reconciliation
  # against the server (cmd/bd/main.go:660-694 FindDatabasePath).
  bdGlobalWrapper = pkgs.writeShellScriptBin "bd-global" ''
    cd "${globalInitWorkspace}"
    exec ${beadsPkg}/bin/bd --global "$@"
  '';

  seedScript = pkgs.writeShellScript "beads-global-seed" ''
    set -eu

    # Skip if the global workspace has already been seeded.
    if [ -d "${globalInitWorkspace}/.beads" ]; then
      echo "beads-global already seeded at ${globalInitWorkspace}"
      exit 0
    fi

    # Wait up to 30s for the sql-server to accept connections.
    for _ in $(seq 1 30); do
      if ${pkgs.netcat}/bin/nc -z 127.0.0.1 ${toString port}; then
        break
      fi
      sleep 1
    done

    mkdir -p "${globalInitWorkspace}"
    cd "${globalInitWorkspace}"
    # --database=beads_global pins the DB name (overrides prefix-based naming).
    # --shared-server + --external: use the already-running sql-server.
    # --stealth: keep .beads/ out of any enclosing git.
    ${beadsPkg}/bin/bd init \
      --shared-server --external --stealth \
      --database=beads_global \
      --server-host=127.0.0.1 --server-port=${toString port} \
      --server-user=root \
      --non-interactive
  '';
in
lib.mkIf (isCodeDev && sizedAtLeast.med) {
  home.packages = [
    beadsPkg
    doltPkg
    bdGlobalWrapper
  ];

  # Env vars consumed by bd to find the shared server.
  # BEADS_DOLT_SHARED_SERVER=1 is the gate (doltserver.go:111-116).
  # Host/port/user names are literal — the non-SERVER variants are NOT
  # read by DefaultConfig (configfile.go:264-361; doltserver.go:440).
  home.sessionVariables = {
    BEADS_DOLT_SHARED_SERVER = "1";
    BEADS_DOLT_SERVER_HOST = "127.0.0.1";
    BEADS_DOLT_SERVER_PORT = toString port;
    BEADS_DOLT_SERVER_USER = "root";
    BEADS_DOLT_PASSWORD = "";
  };

  systemd.user.services.beads-global = {
    Unit = {
      Description = "beads shared dolt sql-server (backs bd --global / shared-server mode)";
      After = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      # Ensure the data dir exists and the port file is present so bd's
      # DefaultConfig picks our port (doltserver.go:460-487) instead of
      # falling back to DefaultSharedServerPort = 3308 (doltserver.go:89).
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p ${doltDataDir}"
        "${pkgs.bash}/bin/bash -c 'echo ${toString port} > ${portFile}'"
      ];
      WorkingDirectory = doltDataDir;
      ExecStart = "${doltPkg}/bin/dolt sql-server --host 127.0.0.1 --port ${toString port} --data-dir ${doltDataDir}";
      Restart = "on-failure";
      RestartSec = "10s";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.beads-global-init = {
    Unit = {
      Description = "Seed beads_global database + workspace on the shared server (one-shot, idempotent)";
      After = [ "beads-global.service" ];
      Wants = [ "beads-global.service" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = [
        "BEADS_DOLT_SHARED_SERVER=1"
        "BEADS_DOLT_SERVER_HOST=127.0.0.1"
        "BEADS_DOLT_SERVER_PORT=${toString port}"
        "BEADS_DOLT_SERVER_USER=root"
        "BEADS_DOLT_PASSWORD="
      ];
      ExecStart = "${seedScript}";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
