# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  callPackage,
  testers,
  parameters ? {},
}:
let
  experiment = testers.runNixOSTest (import ../../nix/experiment.nix parameters);
  parse = fileName: callPackage ../parse { inherit fileName; packets = experiment; };
  parsed-pre = parse "pre";
  parsed-post = parse "post";
  statistics = callPackage ../statistics { pre = parsed-pre; post = parsed-post; };
  graphs = callPackage ../graph { inherit statistics; };
in {
  inherit experiment parsed-pre parsed-post statistics graphs;
}
