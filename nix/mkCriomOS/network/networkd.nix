{
  lib,
  pkgs,
  horizon,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (horizon.node.methods) centerLike;

  # Subnet for USB-dongle hotplug router
  hotplugSubnet = "10.47.0";
  hotplugPrefix = 24;

in
mkIf centerLike {
  # Use systemd-networkd instead of NetworkManager
  networking.useNetworkd = true;
  systemd.network.enable = true;

  # Main NIC — DHCP client for internet
  systemd.network.networks."10-main-eth" = {
    matchConfig = {
      Type = "ether";
      Driver = "!cdc_ether !r8152 !ax88179_178a !asix";
    };
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
    linkConfig.RequiredForOnline = "routable";
  };

  # USB ethernet dongles — act as a router, serve DHCP
  systemd.network.networks."20-usb-eth" = {
    matchConfig = {
      Type = "ether";
      Driver = "cdc_ether r8152 ax88179_178a asix";
    };
    networkConfig = {
      Address = "${hotplugSubnet}.1/${toString hotplugPrefix}";
      DHCPServer = true;
      IPMasquerade = "ipv4";
      IPv6SendRA = true;
    };
    dhcpServerConfig = {
      PoolOffset = 10;
      PoolSize = 200;
      DNS = "${hotplugSubnet}.1";
      EmitDNS = true;
      EmitRouter = true;
    };
    linkConfig.RequiredForOnline = "no";
  };

  # Enable IP forwarding for masquerade
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  # DNS for hotplug clients
  services.resolved = {
    enable = true;
    fallbackDns = [ "1.1.1.1" "9.9.9.9" ];
  };
}
