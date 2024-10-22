# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  lan,
  wan,
  stdenvNoCC,
  lib,
  python3,
}:
stdenvNoCC.mkDerivation {
  name = "statistics";
  realBuilder = lib.getExe python3;
  args = [ ./statistics.py "--lan" "${lan}/lan.json" "--wan" "${wan}/wan.json" "--write-out-path" ];
}
