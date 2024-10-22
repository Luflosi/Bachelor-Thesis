# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  description = "My Thesis as a Nix Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
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
      test-matrix = lib.importJSON ./test-matrix/tests.json;
      filterPipeline = pipeline: lib.filterAttrs (n: v: builtins.elem n [ "experiment" "parsed-pre" "parsed-post" "statistics" "graphs" ]) pipeline;
      pipelineBuilder = parameters: filterPipeline (pkgs.callPackage ./analysis/pipeline { inherit parameters; });
      defaultPipeline = pipelineBuilder (import ./nix/defaultValues.nix);
      pipelines = builtins.map pipelineBuilder test-matrix;
      linkAllOutputsOfPipeline = pipeline: pkgs.linkFarm "pipeline" (lib.mapAttrsToList (name: value: { inherit name; path = value; }) pipeline);
      mkPipelineName = p: "pipeline-duration-${toString p.test_duration_s}s-${toString p.ip_payload_size}bytes-${p.encapsulation}-delay-${toString p.delay_time_ms}ms-jitter-${toString p.delay_jitter_ms}ms-${p.delay_distribution}-loss-${toString p.loss_per_mille}‰-${p.loss_correlation}-duplicate-${toString p.duplicate_per_mille}‰-${p.duplicate_correlation}-reorder-${toString p.reorder_per_mille}‰";
      testsFromJSON = pkgs.linkFarm "testsFromJSON" (lib.zipListsWith (parameters: pipeline: { name = mkPipelineName parameters; path = linkAllOutputsOfPipeline pipeline; }) test-matrix pipelines);
    in defaultPipeline // {
      inherit testsFromJSON;
      report = import ./report/build-document.nix {
        inherit pkgs;
        texlive = get-latex-packages pkgs;
        shellEscape = true;
        minted = true;
        SOURCE_DATE_EPOCH = toString self.lastModified;
      };
      default = self.outputs.packages.${system}.graphs;
    });

    nixosConfigurations = let
      mkNixosSystem = hostName: system: inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          inputs.disko.nixosModules.disko
          ./nix/hosts/${hostName}
          ./nix/profiles/hardware.nix
          ./nix/hosts/${hostName}/profiles/hardware.nix
          {
            networking.hostName = hostName;
            nixpkgs.pkgs = (import inputs.nixpkgs {
              inherit system;
              overlays = import ./nix/overlays;
            });
            nixpkgs.hostPlatform = system;
          }
        ];
      };
    in {
      client = mkNixosSystem "client"   "x86_64-linux";
      logger = mkNixosSystem "logger"   "x86_64-linux";
      router = mkNixosSystem "router"   "x86_64-linux";
      server = mkNixosSystem "server"   "x86_64-linux";
    };

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
