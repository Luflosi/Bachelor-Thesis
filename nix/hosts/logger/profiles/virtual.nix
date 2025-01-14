# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ ... }:
{
  virtualisation = {
    interfaces = {
      lan.vlan = 2;
      wan.vlan = 3;
    };
    cores = 3; # Give this VM more CPU cores so it can keep up with the incoming data
    memorySize = 1024 * 2 + 512;
    fileSystems."/pcap" = {
      fsType = "tmpfs";
      options = [ "size=2G" ];
    };
  };
}
