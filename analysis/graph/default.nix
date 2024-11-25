# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  stdenvNoCC,
  lib,
  python3,
  statistics,
  variant,
}:
assert builtins.elem variant [ "latencies" "packet-counts" "throughput" ];
let
  python = python3.withPackages (python-pkgs: (import ./python-deps.nix python-pkgs));
  inputs = builtins.map (dir: "${dir}/statistics.json") statistics;
in
stdenvNoCC.mkDerivation {
  name = "graph-${variant}";
  realBuilder = lib.getExe python;
  args = [ ./graph-${variant}.py "--inputs" ] ++ inputs ++ [ "--write-out-path" ];
}
