{
  kor,
  lib,
  horizon,
  ...
}:
let
  inherit (kor) concatMapAttrs;
  inherit (lib) mkOverride optional optionals;
  inherit (horizon) node exNodes;
  inherit (builtins) concatStringsSep;

  mkCriomeHostEntries =
    name: node:
    let
      inherit (node) criomOSName nodeIp yggAddress;
      inherit (node.methods) isNixCache nixCacheDomain;

      mkPreNodeHost = linkLocalIP: {
        name = linkLocalIP;
        value = [ ("wg." + criomOSName) ];
      };

      nodeHost = {
        name = nodeIp;
        value = [ criomOSName ];
      };

      preNodeHosts = map mkPreNodeHost node.linkLocalIPs;

      nodeHosts = optionals (nodeIp != null) ([ nodeHost ] ++ preNodeHosts);

      yggdrasilHost = optional (yggAddress != null) {
        name = yggAddress;
        value = [ criomOSName ] ++ (optional isNixCache nixCacheDomain);
      };

    in
    yggdrasilHost ++ nodeHosts;

in
{
  imports = [
    ./unbound.nix
    ./yggdrasil.nix
  ];

  networking = {
    hostName = node.name;
    dhcpcd.extraConfig = "noipv4ll";
    nameservers = [
      "::1"
      "127.0.0.1"
    ];
    hosts = concatMapAttrs mkCriomeHostEntries exNodes;
  };

  services = {
    nscd.enable = false;
  };

  system.nssModules = mkOverride 0 [ ];
}
