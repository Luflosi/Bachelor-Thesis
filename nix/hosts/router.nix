# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ lib, ... }: {
  imports = [
    ./common.nix
  ];

  systemd.network.networks."40-lan" = {
    name = "lan";
    networkConfig = {
      Address = [
        "192.168.0.2/24"
        "fd36:9509:c39c::1/64"
      ];
      DHCPServer = true;
      IPv6SendRA = true;
    };
    dhcpServerConfig = {
      PoolOffset = 100;
      PoolSize = 20;
    };
    ipv6Prefixes = lib.singleton {
      Prefix = "fd36:9509:c39c::/64";
    };
    # This does not yet provide all the options we need
    # See https://www.freedesktop.org/software/systemd/man/latest/systemd.network.html#%5BNetworkEmulator%5D%20Section%20Options
    /*networkEmulatorConfig = {
      DelaySec = 0.2;
      DelayJitterSec = 0.1;
      LossRate = "0.1%";
      DuplicateRate = "0.1%";
    };*/
  };
  systemd.network.networks."40-wan".networkConfig.IPv6AcceptRA = false;

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

  virtualisation.interfaces = {
    lan.vlan = 1;
    wan.vlan = 2;
  };
}
