# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  packets,
  fileName,
  removeEnds,
  stdenvNoCC,
  lib,
  python3,
}:
let
  python = python3.withPackages (python-pkgs: (import ./python-deps.nix python-pkgs));
in
stdenvNoCC.mkDerivation {
  name = "parse-${fileName}";
  realBuilder = lib.getExe python;
  args = [ ./parse.py "--input" "${packets}/${fileName}.pcap" "--metadata" "${packets}/parameters.json" "--write-out-path" "${fileName}.json" ] ++ (lib.optional removeEnds "--remove-ends");
  strictDeps = true;
  __structuredAttrs = true;
}
