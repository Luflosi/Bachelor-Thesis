# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ lib, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
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
}
