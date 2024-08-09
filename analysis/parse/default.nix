# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  packets,
  fileName,
  runCommand,
  lib,
  python3,
  tshark
}:
let
 fs = lib.fileset;
in
runCommand "parse-${fileName}" {
  src = fs.toSource {
    root = ./.;
    fileset = fs.fileFilter (file: ! file.hasExt "nix") ./.;
  };
  nativeBuildInputs = [
    tshark
    python3
  ];
} ''
  cd "$src"
  mkdir -p "$out"
  sh tshark.sh < '${packets}/${fileName}.pcap' | python parse.py > "$out/${fileName}.json"
''
