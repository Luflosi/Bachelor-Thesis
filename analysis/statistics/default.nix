# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  pre,
  post,
  stdenvNoCC,
  lib,
  python3,
}:
stdenvNoCC.mkDerivation {
  name = "statistics";
  realBuilder = lib.getExe python3;
  args = [ ./statistics.py "--pre" "${pre}/pre.json" "--post" "${post}/post.json" "--write-out-path" ];
}
