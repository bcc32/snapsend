{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    ocaml-overlays.url = "github:nix-ocaml/nix-overlays";
    ocaml-overlays.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      flake-utils,
      nixpkgs,
      ocaml-overlays,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ ocaml-overlays.overlays.default ];
        };
      in
      with pkgs;
      let
        ocamlPackages = ocaml-ng.ocamlPackages_5_2;
      in
      rec {
        devShells.default = mkShell {
          inputsFrom = [ packages.default ];
          buildInputs = lib.optional stdenv.isLinux inotify-tools ++ [
            ocamlPackages.merlin
            ocamlPackages.ocamlformat
            ocamlPackages.ocp-indent
            ocamlPackages.utop
          ];
        };

        packages.default = ocamlPackages.buildDunePackage rec {
          pname = "snapsend";
          version = "0.1.0";
          useDune2 = true;
          src = ./.;
          buildInputs = with ocamlPackages; [
            async
            core
            file_path
            ppx_log
            re
            shexp
          ];
          nativeBuildInputs = [ makeBinaryWrapper ];

          postFixup = ''
            wrapProgram $out/bin/snapsend --prefix PATH : ${
              lib.makeBinPath [
                btrfs-progs
                openssh
              ]
            }
          '';

          meta = {
            homepage = "https://github.com/bcc32/snapsend";
          };
        };
      }
    );
}
