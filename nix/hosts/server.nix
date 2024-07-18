# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ lib, ... }: {
  imports = [
    ./common.nix
  ];

  services.iperf3.enable = true;

  networking.interfaces.wan.ipv4 = {
    addresses = lib.singleton {
      address = "192.168.2.3";
      prefixLength = 24;
    };
    routes = lib.singleton {
      address = "192.168.0.0";
      prefixLength = 24;
      via = "192.168.2.2";
    };
  };

  networking.interfaces.wan.ipv6 = {
    addresses = lib.singleton {
      address = "fd9d:c839:3e89::3";
      prefixLength = 64;
    };
    routes = lib.singleton {
      address = "fd36:9509:c39c::";
      prefixLength = 64;
      via = "fd9d:c839:3e89::2";
    };
  };

  virtualisation.interfaces.wan.vlan = 2;
}
