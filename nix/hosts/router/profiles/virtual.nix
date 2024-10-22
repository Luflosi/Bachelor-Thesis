# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ ... }:
{
  virtualisation.interfaces = {
    lan.vlan = 2;
    wan.vlan = 3;
  };
}
