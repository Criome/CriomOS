{
  pkgs,
  pkdjz,
  user,
  crioZone,
  profile,
  ...
}:
let
  inherit (pkdjz) mkEmacs;
  package = mkEmacs { inherit user profile; };

in
{
  home = {
    file.".emacs".text = builtins.readFile ./init.el;

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
