# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  callPackage,
  packets,
}:
let
  parse = fileName: callPackage ../parse { inherit packets fileName; };
  lan = parse "lan";
  wan = parse "wan";
  statistics = callPackage ../statistics { inherit lan wan; };
  graph = callPackage ../graph { inherit statistics; };
in graph
