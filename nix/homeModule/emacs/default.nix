{
  pkgs,
  pkdjz,
  user,
  crioZone,
  profile,
  ...
}:
let
  inherit (pkdjz) meikImaks;
  package = meikImaks { inherit user profile; };

in
{
  home = {
    packages = [ package ] ++ (with pkgs; [ nil ]);

    sessionVariables = {
      EDITOR = "emacsclient -c";
    };
  };

  programs.emacs.package = package;

  services = {
    emacs = {
      enable = true;
      inherit package;
      startWithUserSession = "graphical";
    };
  };
}
