{
  pkgs,
}:
pkgs.llama-cpp-rocm.overrideAttrs (_: {
  version = "8248";
  src = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    tag = "b8248";
    hash = "sha256-2HPsaeSV9pwPm0Yh0/4ZRrrmZvvjpij5jX98bHOwn8E=";
    leaveDotGit = true;
    postFetch = ''
      git -C "$out" rev-parse --short HEAD > $out/COMMIT
      find "$out" -name .git -print0 | xargs -0 rm -rf
    '';
  };
})
