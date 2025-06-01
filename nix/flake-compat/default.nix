# TODO - this is certainly broken
let
  kor = import ../kor;
  inherit (kor) importJSON message;

  getLockFileInput =
    lockFile: inputName:
    let
      lockDatom = importJSON lockFile;
      lockedInput = lockDatom.nodes.${inputName}.locked;
      inherit (lockedInput) type;
    in
    assert assertMsg (type == "github") "getLockFileInput does not support `${type}` type";
    let
      inherit (lockedInput)
        owner
        repo
        narHash
        rev
        ;
    in
    fetchTarball {
      url = "https://github.com/${owner}/${repo}/archive/${rev}.tar.gz";
      sha256 = narHash;
    };

  hobSrc = getLockFileInput ../flake.lock "hob";
  hobLockFile = (import hobSrc).lockFile;
  flakeCompatSrc = getLockFileInput hobLockFile "flake-compat";
  flakeCompatFn = import flakeCompatSrc;
  flakeCompat = flakeCompatFn { src = ../../.; };

in
flakeCompat
