{
  horizon,
  config,
  kor,
  pkgs,
  ...
}:
let
  inherit (builtins)
    filter
    mapAttrs
    attrNames
    hasAttr
    concatStringsSep
    concatMap
    ;
  inherit (kor)
    optionals
    optional
    optionalString
    mkIf
    optionalAttrs
    ;

  inherit (horizon) astra exNodes users;
  inherit (astra.methods) adminSshPreCriomes;

  userNames = attrNames users;

  mkSshString =
    preCriome:
    concatStringsSep " " [
      "ed25519"
      preCriome.ssh
    ];

  mkUser =
    attrName: user:
    let
      inherit (user) trost methods;
      inherit (user.methods) sshyz hazPreCriome;

    in
    optionalAttrs (trost > 0) {
      name = user.name;

      useDefaultShell = true;
      isNormalUser = true;

      openssh.authorizedKeys.keys = sshyz;

      extraGroups =
        [ "audio" ]
        ++ (optional (config.programs.sway.enable == true) "sway")
        ++ (optionals (trost >= 2) (
          [ "video" ] ++ (optional (config.networking.networkmanager.enable == true)) "networkmanager"
        ))
        ++ (optionals (trost >= 3) [
          "adbusers"
          "nixdev"
          "systemd-journal"
          "dialout"
          "plugdev"
          "storage"
          "libvirtd"
        ]);
    };

  mkUserUsers = mapAttrs mkUser users;

  rootUserAkses = {
    root = {
      openssh.authorizedKeys.keys = adminSshPreCriomes;
    };
  };

in
{
  users = {
    users = mkUserUsers // rootUserAkses;
  };
}
