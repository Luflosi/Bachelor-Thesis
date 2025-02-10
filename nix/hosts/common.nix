# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ ... }: {
  imports = [
    ../modules/icmptx.nix
  ];
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.networks."40-lan".networkConfig.IPv6AcceptRA = false;
  systemd.network.networks."40-wan".networkConfig.IPv6AcceptRA = false;
  systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";
}
