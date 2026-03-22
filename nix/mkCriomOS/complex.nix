{
  pkgs,
  constants,
  ...
}:
let
  inherit (constants.fileSystem.complex) dir keyFile sshPubFile;

  clavifaber = pkgs.callPackage ../clavifaber.nix { };

in
{
  environment.systemPackages = [ clavifaber ];

  systemd.services.complex-init = {
    description = "Generate node identity complex (Ed25519 keypair)";
    wantedBy = [ "multi-user.target" ];
    before = [
      "NetworkManager.service"
      "sshd.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ -f "${keyFile}" ]; then
        chmod 600 "${keyFile}"
        chmod 700 "${dir}"
        chown -R root:root "${dir}"
        echo "complex: identity exists at ${dir}"
        cat "${sshPubFile}"
        exit 0
      fi

      echo "complex: generating node identity at ${dir}"
      ${clavifaber}/bin/clavifaber complex-init --dir "${dir}"
    '';
  };
}
