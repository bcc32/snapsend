{ lib, nix-gitignore, buildDunePackage, makeWrapper, async, btrfs-progs, core
, core_bench, openssh, ppx_log, re, shexp }:

buildDunePackage rec {
  pname = "snapsend";
  version = "0.1.0";
  useDune2 = true;
  src = nix-gitignore.gitignoreFilterSource lib.cleanSourceFilter [ ] ./.;
  propagatedBuildInputs = [ async core ppx_log re shexp ];

  buildInputs = [ makeWrapper ];

  postFixup = ''
    wrapProgram $out/bin/snapsend --prefix PATH : ${
      lib.makeBinPath [ btrfs-progs openssh ]
    }
      '';
  meta = { homepage = "https://github.com/bcc32/snapsend"; };
}
