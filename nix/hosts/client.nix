# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ lib, pkgs, ... }: {
  imports = [
    ./common.nix
  ];

  environment.systemPackages = with pkgs; [
    my.iperf3
  ];

  networking.interfaces.lan.ipv4 = {
    addresses = lib.singleton {
      address = "192.168.0.3";
      prefixLength = 24;
    };
    routes = lib.singleton {
      address = "192.168.2.0";
      prefixLength = 24;
      via = "192.168.0.2";
    };
  };

  networking.interfaces.lan.ipv6 = {
    addresses = lib.singleton {
      address = "fd36:9509:c39c::3";
      prefixLength = 64;
    };
    routes = lib.singleton {
      address = "fd9d:c839:3e89::";
      prefixLength = 64;
      via = "fd36:9509:c39c::2";
    };
  };

  virtualisation.interfaces.lan.vlan = 1;
}
