# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ ... }: {
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.useDHCP = false;
  systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";
}
