# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ ... }:
{
  networking.hostId = "e6214dd8";

  networking.vlans = {
    lan = {
      id = 2;
      interface = "eno1";
    };
    wan = {
      id = 3;
      interface = "eno1";
    };
  };
}
