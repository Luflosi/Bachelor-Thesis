# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ pkgs, ... }: {
  imports = [
    ./common.nix
  ];

  systemd.network.enable = false;
  environment.systemPackages = with pkgs; [
    lsof
    tcpdump
  ];

  # No IPv6 link-local addresses
  boot.kernel.sysctl = {
    "net.ipv6.conf.lan.autoconf" = 0;
    "net.ipv6.conf.lan.accept_ra" = 0;
    "net.ipv6.conf.lan.addr_gen_mode" = 1;
    "net.ipv6.conf.wan.autoconf" = 0;
    "net.ipv6.conf.wan.accept_ra" = 0;
    "net.ipv6.conf.wan.addr_gen_mode" = 1;
  };

  virtualisation.interfaces = {
    lan.vlan = 1;
    wan.vlan = 2;
  };
  # Set interface state to "up"
  networking.interfaces.lan.ipv4.addresses = [];
  networking.interfaces.wan.ipv4.addresses = [];

  virtualisation.cores = 3; # Give this VM more CPU cores so it can keep up with the incoming data
  virtualisation.memorySize = 1024 * 2 + 512;
  virtualisation.fileSystems."/ram" = {
    fsType = "tmpfs";
    options = [ "size=2G" ];
  };
}
