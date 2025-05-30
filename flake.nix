# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  description = "My Thesis as a Nix Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    rfc-bib = {
      url = "git+file:PDF/rfc.bib";
      flake = false;
    };
  };

  outputs = { self, ... }@inputs: let
    lib = inputs.nixpkgs.lib;
    forAllSystems = function: lib.genAttrs [
      "aarch64-linux"
      "x86_64-linux"
    ] function;

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
          cleveref
          biblatex
          minted
          upquote
          csquotes
          xurl
          ;
      })
      biber
    ];

    get-latex-dev-packages = pkgs: with pkgs; [
      texlab
      zathura
      wmctrl
      texstudio
    ];
  in {
    packages = forAllSystems (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = import ./nix/overlays;
      };
      testMatrixNoCacheID = let
        parameters = lib.importJSON ./test-matrix/parameters.json;
        expanded = builtins.map lib.cartesianProduct parameters;
        result = lib.flatten expanded;
      in builtins.traceVerbose ("${toString (builtins.length result)} measurements in total") result;
      reruns = lib.importJSON ./test-matrix/reruns.json;
      parametersToCacheID = parameters: let
        checkRerun = acc: rerun: let
          rerunNoCacheID = builtins.removeAttrs rerun [ "cacheID" ];
        in
          if rerunNoCacheID == parameters then
            assert acc == 0; # There should be at most one matching entry in the rerun file
            rerun.cacheID
          else
            acc;
      in builtins.foldl' checkRerun 0 reruns;
      addCacheID = parameters: assert !builtins.hasAttr "cacheID" parameters; parameters // { cacheID = parametersToCacheID parameters; };
      test-matrix = builtins.map addCacheID testMatrixNoCacheID;
      filterPipeline = pipeline: lib.filterAttrs (n: v: builtins.elem n [ "graphs" "intermediates" ]) pipeline;
      protocols = import ./nix/constants/protocols.nix;
      protocolToDriver = encapsulation: overhead: (pkgs.testers.runNixOSTest (import ./nix/measurement/VM/define.nix { inherit encapsulation; })).driver;
      measurementDrivers = builtins.mapAttrs protocolToDriver protocols;
      pipelineBuilder = allParameters: filterPipeline (pkgs.callPackage ./analysis/pipeline { inherit measurementDrivers allParameters protocols; });
      defaultPipeline = pipelineBuilder [(import ./nix/constants/defaultValues.nix)];
      pipelines = pipelineBuilder test-matrix;
      linkAllOutputsOfPipeline = pipeline: pkgs.linkFarm "pipeline" (lib.mapAttrsToList (name: value: { inherit name; path = value; }) pipeline);
      parametersToString = p: "duration-${toString p.test_duration_s}s-${toString p.ip_payload_size}bytes-${p.encapsulation}-delay-${toString p.delay_time_ms}ms-jitter-${toString p.delay_jitter_ms}ms-${p.delay_distribution}-loss-${toString p.loss_per_mille}‰-${p.loss_correlation}-duplicate-${toString p.duplicate_per_mille}‰-${p.duplicate_correlation}-reorder-${toString p.reorder_per_mille}‰";
      measurements = pkgs.linkFarm "measurements" (lib.zipListsWith (parameters: intermediates: { name = parametersToString parameters; path = intermediates.measurement; }) test-matrix pipelines.intermediates);
      all-statistics = pkgs.linkFarm "all-statistics" (lib.zipListsWith (parameters: intermediates: { name = parametersToString parameters; path = intermediates.statistic; }) test-matrix pipelines.intermediates);
      all-parsed = pkgs.linkFarm "all-parsed" (lib.flatten (lib.zipListsWith (parameters: intermediates: [{ name = "pre-" + parametersToString parameters; path = intermediates.parsed-pre; } { name = "post-" + parametersToString parameters; path = intermediates.parsed-post; }]) test-matrix pipelines.intermediates));
    in (builtins.head defaultPipeline.intermediates) // {
      inherit (defaultPipeline) graphs;
      graphsMulti = pipelines.graphs;
      inherit measurements all-statistics all-parsed;
      PDF = import ./PDF/build-document.nix {
        inherit lib pkgs;
        inherit (inputs) rfc-bib;
        texlive = get-latex-packages pkgs;
        shellEscape = true;
        minted = true;
        SOURCE_DATE_EPOCH = toString self.lastModified;
      };
      default = self.outputs.packages.${system}.graphs;
    });

    nixosConfigurations = let
      protocolsDir = hostName: "${toString inputs.self}/nix/hosts/${hostName}/protocols";
      isHostWithProtocol = hostName: builtins.elem hostName [ "client" "server" ];
      protocols = builtins.attrNames (import ./nix/constants/protocols.nix);
      protocolsNotNone = builtins.filter (p: p != "none") protocols;
      importProfile = hostName: builtins.map (profile: {
        ${profile} = {
          configuration.imports = [
            "${protocolsDir hostName}/${profile}.nix"
          ];
        };
      }) protocolsNotNone;
      mkSpecializations = hostName: lib.attrsets.mergeAttrsList (importProfile hostName);
      maybeMkSpecializations = hostName: lib.optionalAttrs (isHostWithProtocol hostName) (mkSpecializations hostName);
      mkNixosSystem = hostName: system: inputs.nixpkgs.lib.nixosSystem {
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
            specialisation = maybeMkSpecializations hostName;

            system.configurationRevision = self.rev or self.dirtyRev or "dirty-inputs";
            system.nixos.label = self.shortRev or self.dirtyShortRev or "dirty-inputs";
          }
        ] ++ lib.optional (isHostWithProtocol hostName) ./nix/hosts/${hostName}/protocols/none.nix;
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

    devShells = forAllSystems (system: let
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
    });
  };
}
