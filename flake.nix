# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  description = "My Thesis as a Nix Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, ... }@inputs: let
    lib = inputs.nixpkgs.lib;
    forAllSystems = function: lib.genAttrs [
      "aarch64-linux"
      "x86_64-linux"
    ] (system: function system);

    get-latex-packages = pkgs: with pkgs; [
      (texlive.combine {
        inherit (texlive)
          scheme-medium
          titlesec
          wrapfig
          lstaddons
          lkproof
          needspace
          ntheorem
          tocbibind
          mfirstuc
          eulervm
          todonotes
          glossaries
          xfor
          datatool
          ;
      })
    ];

    get-latex-dev-packages = pkgs: with pkgs; [
      texlab
      zathura
      wmctrl
    ];
  in {
    packages = forAllSystems (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = import ./nix/overlays;
      };
      filterPipeline = pipeline: lib.filterAttrs (n: v: builtins.elem n [ "experiment" "parsed-lan" "parsed-wan" "statistics" "graphs" ]) pipeline;
      pipeline = filterPipeline (pkgs.callPackage ./analysis/pipeline { });
    in pipeline // {
      report = import ./report/build-document.nix {
        inherit pkgs;
        texlive = get-latex-packages pkgs;
        shellEscape = true;
        minted = true;
        SOURCE_DATE_EPOCH = toString self.lastModified;
      };
      default = self.outputs.packages.${system}.graphs;
    });

    checks = lib.recursiveUpdate self.outputs.packages (forAllSystems (system: let
      pkgs = import inputs.nixpkgs { inherit system; };
    in {
      reuse = pkgs.runCommand "run-reuse" {
        src = ./.;
        nativeBuildInputs = with pkgs; [ reuse ];
      } ''
        cd "$src"
        reuse lint --lines
        touch "$out"
      '';
    }));

    devShells = (forAllSystems (system: let
      pkgs = import inputs.nixpkgs { inherit system; };
    in {
      default = pkgs.mkShellNoCC {
        packages = [
          pkgs.reuse
          pkgs.tshark
          (pkgs.python3.withPackages (python-pkgs:
            (import ./analysis/graph/python-deps.nix python-pkgs) ++
            (import ./analysis/parse/python-deps.nix python-pkgs) ++
            [
              python-pkgs.ipython
            ]
          ))
          (get-latex-packages pkgs)
          (get-latex-dev-packages pkgs)
        ];
      };
    }));
  };
}
