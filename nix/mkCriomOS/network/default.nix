{
  lib,
  horizon,
  ...
}:
let
  inherit (lib) mkOverride optional optionals;
  inherit (horizon) node exNodes;

  mkCriomeHostEntries =
    name: node:
    let
      inherit (node) criomeDomainName nodeIp yggAddress;
      inherit (node.methods) isNixCache nixCacheDomain;

      mkPreNodeHost = linkLocalIP: {
        name = linkLocalIP;
        value = [ ("wg." + criomeDomainName) ];
      };

      nodeHost = {
        name = nodeIp;
        value = [ criomeDomainName ];
      };

      preNodeHosts = map mkPreNodeHost node.linkLocalIps;

      nodeHosts = optionals (nodeIp != null) ([ nodeHost ] ++ preNodeHosts);

      yggdrasilHost = optional (yggAddress != null) {
        name = yggAddress;
        value = [ criomeDomainName ] ++ (optional isNixCache nixCacheDomain);
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
    hosts = lib.concatMapAttrs mkCriomeHostEntries exNodes;
  };

  services = {
    nscd.enable = false;
  };

  system.nssModules = mkOverride 0 [ ];
}
