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
in
lib.mkIf (isCodeDev && sizedAtLeast.med) {
  home.packages = [
    beadsPkg
    doltPkg
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
}
