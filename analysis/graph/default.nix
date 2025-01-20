# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  stdenvNoCC,
  lib,
  python3,
  statistics,
}:
let
  python = python3.withPackages (python-pkgs: (import ./python-deps.nix python-pkgs));
in
stdenvNoCC.mkDerivation {
  name = "graph";
  realBuilder = lib.getExe python;
  args = [ ./graph.py "--input" "${statistics}/statistics.json" "--write-out-path" ];
  strictDeps = true;
}
