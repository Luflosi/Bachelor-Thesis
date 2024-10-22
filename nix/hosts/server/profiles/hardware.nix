# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ ... }:
{
  networking.hostId = "6675b430";

  networking.vlans.wan = {
    id = 3;
    interface = "eno1";
  };
}
