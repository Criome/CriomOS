let
  npins = import ../npins;
  flake-inputs = import npins.flake-inputs;
in
flake-inputs { root = ./.; }
