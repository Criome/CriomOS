{
  kor,
  pkgs,
  pkdjz,
  user,
  config,
  profile,
  horizon,
  ...
}:
let
  inherit (kor)
    mkIf
    optionals
    optionalString
    matcSaiz
    ;
  inherit (user.methods)
    sizedAtLeast
    iuzColemak
    izNiksDev
    izSemaDev
    ;
  inherit (user) saiz;
  inherit (profile) dark;
  inherit (pkgs) writeText;
  inherit (horizon.astra.mycin) modyl;

  shellLaunch = command: "${shell} -c '${command}'";
  homeDir = config.home.homeDirectory;
  nixProfileExec = name: "${homeDir}/.nix-profile/bin/${name}";

  shell = zshEksek;
  zshEksek = nixProfileExec "zsh";
  neovim = nixProfileExec "nvim";
  elementaryCode = nixProfileExec "io.elementary.code";
  termVis = shellLaunch "exec ${terminal} -e  ${nixProfileExec "vis"}";
  termNeovim = shellLaunch "exec ${terminal} -e ${neovim}";
  termBrowser = shellLaunch "exec ${terminal} -e ${nixProfileExec "w3m"}";
  terminal = nixProfileExec "foot";

  swayArguments = {
    inherit iuzColemak optionalString;
    waybarEksek = nixProfileExec "waybar";
    swaylockEksek = nixProfileExec "swaylock";
    browser =
      matcSaiz saiz "" termBrowser "${nixProfileExec "qutebrowser"}"
        "${nixProfileExec "qutebrowser"}";
    launcher = "${nixProfileExec "wofi"} --show drun";
    shellTerm = shellLaunch "export SHELL=${zshEksek}; exec ${terminal} ${zshEksek}";
  };

  swayConfigString = import ./swayConf.nix swayArguments;

in
mkIf sizedAtLeast.min {
  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures = {
      base = true;
      gtk = true;
    };
    systemd.enable = true;
    extraSessionCommands = '''';
    config = null;
    extraConfig = swayConfigString;
  };
}
