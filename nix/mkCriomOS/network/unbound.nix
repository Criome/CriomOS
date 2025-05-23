{
  config,
  lib,
  pkgs,
  horizon,
  ...
}:
let
  inherit (builtins)
    map
    concatStringsSep
    concatMap
    attrNames
    ;
  inherit (lib) mapAttrsToList concatMapStringsSep lowPrio;
  inherit (horizon.astra) typeIs criomOSName;

  listenIPs = [
    "::1"
    "127.0.0.1"
  ];
  allowedIPs = [
    "::1"
    "127.0.0.1"
  ];

  TLSDNServers = {
    "cloudflare-dns.com" = [
      "2606:4700:4700::1111"
      "1.1.1.1"
      "2606:4700:4700::1001"
      "1.0.0.1"
    ];
    "dns.quad9.net" = [
      "2620:fe::fe"
      "9.9.9.9"
      "2620:fe::9"
      "149.112.112.112"
    ];
  };

  mkForwardServerUrls = domain: ipList: map (ip: "${ip}@853#${domain}") ipList;

  forwardServerUrls = concatMap (name: mkForwardServerUrls name TLSDNServers.${name}) (
    attrNames TLSDNServers
  );

in
{
  services.unbound = {
    # enable = (!typeIs.edj); # bootstrap
    enable = true;
    settings = {
      server = {
        interface = listenIPs;
        do-not-query-localhost = false;
        tls-cert-bundle = "/etc/ssl/certs/ca-certificates.crt";
      };
      forward-zone = [
        {
          name = ".";
          forward-tls-upstream = true;
          forward-addr = forwardServerUrls;
        }
      ];
    };
  };

}
