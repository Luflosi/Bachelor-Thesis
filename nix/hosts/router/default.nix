# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ lib, ... }: {
  imports = [
    ../common.nix
  ];

  networking.interfaces.lan.ipv4.addresses = lib.singleton {
    address = "192.168.0.2";
    prefixLength = 24;
  };
  networking.interfaces.lan.ipv6.addresses = lib.singleton {
    address = "fd36:9509:c39c::2";
    prefixLength = 64;
  };
  networking.interfaces.wan.ipv4.addresses = lib.singleton {
    address = "192.168.2.2";
    prefixLength = 24;
  };
  networking.interfaces.wan.ipv6.addresses = lib.singleton {
    address = "fd9d:c839:3e89::2";
    prefixLength = 64;
  };

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = "1";
    "net.ipv6.conf.all.forwarding" = "1";
    "net.ipv6.conf.default.forwarding" = "1";
  };
}
