{ lib, nix-gitignore, buildDunePackage, async, async_interactive, core
, core_bench, ppx_log, re, shexp }:

buildDunePackage rec {
  pname = "snapsend";
  version = "0.1.0";
  useDune2 = true;
  src = nix-gitignore.gitignoreFilterSource lib.cleanSourceFilter [ ] ./.;
  propagatedBuildInputs = [ async async_interactive core ppx_log re shexp ];
  meta = { homepage = "https://github.com/bcc32/snapsend"; };
}
