# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  callPackage,
  testers,
}:
let
  experiment = testers.runNixOSTest (import ../../nix/experiment.nix);
  parse = fileName: callPackage ../parse { inherit fileName; packets = experiment; };
  parsed-lan = parse "lan";
  parsed-wan = parse "wan";
  statistics = callPackage ../statistics { lan = parsed-lan; wan = parsed-wan; };
  graphs = callPackage ../graph { inherit statistics; };
in {
  inherit experiment parsed-lan parsed-wan statistics graphs;
}
