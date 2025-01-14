# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  callPackage,
  measurementDriver,
  parameters ? {},
  protocols,
}:
let
  measurement = callPackage ../../nix/measurement/VM/run.nix { inherit measurementDriver parameters; };
  parse = fileName: removeEnds: callPackage ../parse { inherit fileName removeEnds; packets = measurement; };
  parsed-pre = parse "pre" true;
  parsed-post = parse "post" false;
  statistics = callPackage ../statistics { pre = parsed-pre; post = parsed-post; overhead = protocols.${parameters.encapsulation}; };
  graphs = callPackage ../graph { inherit statistics; };
in {
  inherit measurement parsed-pre parsed-post statistics graphs;
}
