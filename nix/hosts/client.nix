# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ pkgs, ... }: {
  imports = [
    ./common.nix
  ];

  environment.systemPackages = with pkgs; [
    iperf3
  ];

  networking.useNetworkd = true;
  networking.interfaces.lan.useDHCP = true;

  virtualisation.interfaces.lan.vlan = 1;
}
