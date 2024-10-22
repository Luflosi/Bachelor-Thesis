# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ ... }:
{
  networking.hostId = "b9116a61";

  networking.vlans.lan = {
    id = 2;
    interface = "eno1";
  };
}
