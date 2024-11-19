# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ ... }:
{
  networking.hostId = "0ccdfc22";

  # eno1 is the interface for capturing packets
  # enp0s20f0u2 is the management interface

  networking.interfaces.enp0s20f0u2.useDHCP = true;

  networking.interfaces.eno1.useDHCP = false;
  systemd.network.networks."40-eno1" = {
    name = "eno1";
    networkConfig = {
      LinkLocalAddressing = "no";
      IPv6AcceptRA = false;
    };
    linkConfig = {
      ARP = false;
      Multicast = false;
      AllMulticast = false;
    };
  };

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
