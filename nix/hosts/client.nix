# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ lib, pkgs, ... }: {
  imports = [
    ./common.nix
  ];

  environment.systemPackages = with pkgs; [
    my.iperf3
    wireguard-tools
  ];

  systemd.services.install-wg-key = {
    # This systemd service is needed to get the right permissions on our snakeoil key
    description = "Install the WireGuard key";
    wantedBy = [ "systemd-networkd.service" ];
    before = [ "systemd-networkd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Group = "systemd-network";
      UMask = "0227";
    };
    script = ''
      mkdir -p /etc/wireguard/
      umask 337
      echo 'EN7ilnHL7W64w4gkGBGeF+A8nqM0m5Xd5XRyf3A1qn8=' > /etc/wireguard/secret.key
    '';
  };

  systemd.network.netdevs = {
    "10-wg0" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = "wg0";
      };
      wireguardConfig = {
        PrivateKeyFile = "/etc/wireguard/secret.key";
        ListenPort = 54176;
      };
      wireguardPeers = lib.singleton {
        PublicKey = "M0VKYDPrwxpp8OLeiwKgdzNXdmt8yikO3jlsuFg1Axs=";
        AllowedIPs = [
          "fded:51e9:828f::3/128"
          "192.168.20.3/32"
        ];
        Endpoint = "192.168.2.3:63415";
      };
    };
  };

  systemd.network.networks."10-wg0" = {
    matchConfig.Name = "wg0";
    networkConfig.Address = [
      "fded:51e9:828f::1/64"
      "192.168.20.1/24"
    ];
  };

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
