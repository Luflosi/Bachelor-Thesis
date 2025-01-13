# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  callPackage,
  stdenvNoCC,
  measurementDriver,
  parameters ? {},
  protocols,
}:
let
  runDriver = driver: testScript: stdenvNoCC.mkDerivation {
    name = "vm-test-run";
    requiredSystemFeatures = [ "nixos-test" "kvm" ];
    buildCommand = ''
      mkdir -p $out
      # effectively mute the XMLLogger
      export LOGFILE=/dev/null
      ${driver}/bin/nixos-test-driver -o $out '${testScript}'
    '';
  };
  testScript = callPackage (import ../../nix/create-test-script.nix parameters) { };
  measurement = runDriver measurementDriver testScript;
  parse = fileName: removeEnds: callPackage ../parse { inherit fileName removeEnds; packets = measurement; };
  parsed-pre = parse "pre" true;
  parsed-post = parse "post" false;
  statistics = callPackage ../statistics { pre = parsed-pre; post = parsed-post; overhead = protocols.${parameters.encapsulation}; };
  graphs = callPackage ../graph { inherit statistics; };
in {
  inherit measurement parsed-pre parsed-post statistics graphs;
}
