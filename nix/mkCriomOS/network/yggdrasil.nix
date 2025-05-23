{
  kor,
  pkgs,
  horizon,
  konstynts,
  ...
}:
let
  inherit (builtins) mapAttrs attrNames filter;
  inherit (kor) mkIf optionalString;
  inherit (horizon.astra.methods) hasYggPrecriad;
  inherit (konstynts) fileSystem;
  inherit (konstynts.fileSystem.yggdrasil)
    preCriadJson
    subDirName
    preCriomeJson
    interfaceName
    combinedConfigJson
    ;
  inherit (konstynts.network.yggdrasil) ports;

  package = pkgs.yggdrasil;
  yggExec = "${package}/bin/yggdrasil";
  yggCtlExec = "${package}/bin/yggdrasilctl";
  jqEksek = "${pkgs.jq}/bin/jq";

  yggCriodFilterSocket = fileSystem.systemd.runtimeDirectory + "/yggCriodFilter";

  mkConfigFile =
    conf:
    pkgs.writeTextFile {
      name = "yggdrasilConf.json";
      text = builtins.toJSON conf;
    };

  yggdrasilConfig = {
    IfName = "yggTun";
    NodeInfoPrivacy = true;
    MulticastInterfaces = [
      {
        Regex = ".*";
        Beacon = true;
        Listen = true;
        Port = ports.linkLocalTCP;
      }
    ];
  };

  configFile = mkConfigFile yggdrasilConfig;

  seedYggdrasil = !hasYggPrecriad;

  seedYggdrasilScript = pkgs.writeScript "createYggdrasilKeys.sh" ''
    if [[ ! -e ${preCriadJson} ]]; then
      ${yggExec} -genconf -json | \
        ${pkgs.jq}/bin/jq '{ PublicKey, PrivateKey }' > ${preCriadJson}
    fi
  '';

  extractPreCriomeJson = ''
    ${yggCtlExec} -json -v getself > ${preCriomeJson}
  '';

in
{
  environment.systemPackages = [ package ];

  networking.firewall = {
    allowedUDPPorts = [ ports.multicast ];
    allowedTCPPorts = [ ports.linkLocalTCP ];
    trustedInterfaces = [ interfaceName ];
  };

  systemd = {
    services = {
      yggdrasil = {
        description = "Yggdrasil Network Service";
        bindsTo = [ "network-online.target" ];
        after = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        preStart = ''
          ${optionalString seedYggdrasil seedYggdrasilScript} 
          ${pkgs.jq}/bin/jq --slurp add ${preCriadJson} ${configFile} > ${combinedConfigJson}
        '';

        postStart = optionalString seedYggdrasil extractPreCriomeJson;

        serviceConfig = {
          ExecStart = ''
            ${yggExec} -useconffile ${combinedConfigJson}
          '';

          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          Restart = "always";

          StateDirectory = subDirName;
          RuntimeDirectory = subDirName;
          RuntimeDirectoryMode = "0750";

          AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
          CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
          SecureBits = "keep-caps";
          DynamicUser = true;
          MemoryDenyWriteExecute = true;
          ProtectControlGroups = true;
          ProtectHome = "tmpfs";
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6 AF_NETLINK";
          RestrictNamespaces = true;
          RestrictRealtime = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged @keyring"
          ];
        };
      };
    };

  };
}
