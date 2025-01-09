# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ lib, pkgs, ... }: {
  imports = [
    ../common.nix
  ];

  systemd.network.networks."40-lan".networkConfig.LinkLocalAddressing = "no";
  systemd.network.networks."40-wan".networkConfig.LinkLocalAddressing = "no";

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

  # Set interface state to "up"
  networking.interfaces.lan.ipv4.addresses = [];
  networking.interfaces.wan.ipv4.addresses = [];

  systemd.services = let
    mkUnit = interface: filename: {
      "tcpdump-${interface}" = {
        description = "Service that captures network traffic on the ${interface} interface";
        after = [ "network.target" ];
        startLimitBurst = 1;
        serviceConfig = {
          ExecStart = "${lib.getExe pkgs.tcpdump} -n -B 10240 -i ${interface} -w /ram/${filename}.pcap";
        };
      };
    };
  in
    (mkUnit "lan" "post")
    //
    (mkUnit "wan" "pre")
  ;
}
