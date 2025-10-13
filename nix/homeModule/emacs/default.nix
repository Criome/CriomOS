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

  baseDependencies = with pkgs; [
    nil
    nodejs
    # Collision - unknown source
    # gh
  ];

  synthElDependencies = [
    (pkgs.python312.withPackages (ps: [ ps.aider-chat ]))
  ];

in
{
  home = {
    file.".emacs".text = builtins.readFile ./init.el;

    packages = [ package ] ++ baseDependencies ++ synthElDependencies;

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
