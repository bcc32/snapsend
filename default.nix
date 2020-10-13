with import <nixpkgs> { };

let
  inherit (ocamlPackages)
    buildDunePackage async async_interactive core core_bench re shexp;

in buildDunePackage rec {
  pname = "snapsend";
  version = "0.1.0";
  src = nix-gitignore.gitignoreFilterSource lib.cleanSourceFilter [ ] ./.;
  propagatedBuildInputs = [ async async_interactive core re shexp ];
  meta = { homepage = "https://github.com/bcc32/snapsend"; };
}
