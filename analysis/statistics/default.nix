# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  pre,
  post,
  overhead,
  stdenvNoCC,
  lib,
  python3,
}:
stdenvNoCC.mkDerivation {
  name = "statistics";
  realBuilder = lib.getExe python3;
  args = [ ./statistics.py "--pre" pre "--post" post "--overhead" (toString overhead) "--write-out-path" ];
  strictDeps = true;
  __structuredAttrs = true;
}
