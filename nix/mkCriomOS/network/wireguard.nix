{
  kor,
  pkgs,
  horizon,
  konstynts,
  pkdjz,
  ...
}:
let
  inherit (builtins)
    mapAttrs
    attrNames
    filter
    concatStringsSep
    ;
  inherit (kor)
    mkIf
    mapAttrsToList
    optionalAttrs
    filterAttrs
    ;
  inherit (horizon) astra exNodes;
  inherit (horizon.astra.methods)
    hasWireguardPrecriad
    wireguardUntrustedProxies
    ;

  mkUntrustedProxy = untrustedProxy: {
    inherit (wireguardUntrustedProxies) publicKey endpoint;
    allowedIPs = [ "0.0.0.0/0" ];
  };

  mkUntrustedProxyIp = untrustedProxy: untrustedProxy.interfaceIp;

  untrustedProxiesPeers = map mkUntrustedProxy wireguardUntrustedProxies;

  untrustedProxiesIps = map mkUntrustedProxyIp wireguardUntrustedProxies;

  mkNodePeer = name: node: {
    allowedIPs = [ node.nodeIp ];
    publicKey = node.wireguardPreCriome;
    endpoint = "wg.${node.criomOSName}:51820";
  };

  validPreNodes = filterAttrs (n: v: v.methods.hasWireguardPrecriad) exNodes;

  nodePeers = mapAttrsToList mkNodePeer validPreNodes;

  privateKeyFile = "/etc/wireguard/privateKey";

in
{
  networking = {
    wireguard = {
      enable = true;
      interfaces = {
        wgProxies = {
          ips = untrustedProxiesIps;
          peers = untrustedProxiesPeers;
          inherit privateKeyFile;
        };

        wgNode = {
          ips = [ astra.nodeIp ];
          inherit privateKeyFile;
          peers = nodePeers;
          listenPort = 51820;
        };

      };
    };
  };

}
