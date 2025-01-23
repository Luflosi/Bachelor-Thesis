# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ lib, pkgs, ... }:
{
  networking.hostId = "0ccdfc22";

  # eno1 is the interface for capturing packets
  # enp0s20f0u2 is the management interface

  networking.interfaces.enp0s20f0u2.useDHCP = true;

  networking.interfaces.eno1.useDHCP = false;
  systemd.network.networks."40-eno1" = {
    name = "eno1";
    networkConfig = {
      LinkLocalAddressing = "no";
      IPv6AcceptRA = false;
    };
    linkConfig = {
      ARP = false;
      Multicast = false;
      AllMulticast = false;
    };
  };

  networking.vlans = {
    lan = {
      id = 2;
      interface = "eno1";
    };
    wan = {
      id = 3;
      interface = "eno1";
    };
  };

  systemd.tmpfiles.rules = [
    "d '/pcap' 0755 'root' 'root' - -"
  ];

  disko.devices.zpool.tank.datasets.nix = lib.mkForce {
    type = "zfs_fs";
    mountpoint = "/nix-old";
    options = {
      atime = "off";
      mountpoint = "legacy";
    };
  };

  fileSystems."/nix" = {
    label = "smr";
    fsType = "btrfs";
    neededForBoot = true;
    options = [
      "noatime" "compress-force=zstd" "discard=async" "autodefrag" "commit=300" "subvol=/@nix"
    ];
  };

  boot.initrd.availableKernelModules = [
    "uas"
  ];

  nix.settings.sandbox = "relaxed";

  environment.systemPackages = with pkgs; [
    tmux
    nix-output-monitor
  ];
}
