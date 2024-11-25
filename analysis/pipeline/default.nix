# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  callPackage,
  testers,
  stdenv,
  lib,
  pkgs,
  experimentDriver,
  parameters ? {},
  protocols,
}:
let
  runDriver = driver: testScript: stdenv.mkDerivation {
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
  experiment = runDriver experimentDriver testScript;
  parse = fileName: removeEnds: callPackage ../parse { inherit fileName removeEnds; packets = experiment; };
  parsed-pre = parse "pre" true;
  parsed-post = parse "post" false;
  statistic = callPackage ../statistics { pre = parsed-pre; post = parsed-post; overhead = protocols.${parameters.encapsulation}; };
  statistics = [ statistic ];
  graph-latencies = callPackage ../graph { inherit statistics; variant = "latencies"; };
  graph-packet-counts = callPackage ../graph { inherit statistics; variant = "packet-counts"; };
  graph-throughput = callPackage ../graph { inherit statistics; variant = "throughput"; };
in {
  inherit experiment parsed-pre parsed-post graph-latencies graph-packet-counts graph-throughput;
  statistics = statistic;
}
