# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  callPackage,
  measurementDriver,
  parameters,
  settings,
  stdenvNoCC,
}:
let
  runDriver = driver: testScript: stdenvNoCC.mkDerivation {
    name = "vm-test-run";
    requiredSystemFeatures = [ "nixos-test" "kvm" ];
    strictDeps = true;
    buildCommand = ''
      mkdir -p $out
      # effectively mute the XMLLogger
      export LOGFILE=/dev/null
      ${driver}/bin/nixos-test-driver -o $out '${testScript}'
    '';
  };
  testScript = callPackage (import ../create-test-script.nix parameters) { inherit settings; };
  measurement = runDriver measurementDriver testScript;
in
  measurement
