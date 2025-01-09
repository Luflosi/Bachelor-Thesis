# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

# To install: nix run github:nix-community/nixos-anywhere -- --flake .#client nixos@nixos.lan

{ lib, pkgs, ... }:
let
  constantsSSH = import ../constants/ssh.nix;
in {
  services.openssh = {
    enable = true;
    allowSFTP = false;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "yes";
      AllowTcpForwarding = false;
      X11Forwarding = false;
      AllowAgentForwarding = false;
      AllowStreamLocalForwarding = false;
      AuthenticationMethods = "publickey";
    };
  };

  users.users.u = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    group = "users";
    password = ""; # Allow login without a password
    openssh.authorizedKeys.keys = constantsSSH.userKeys;
  };
  users.users.root.openssh.authorizedKeys.keys = constantsSSH.rootKeys;

  programs.zsh.enable = true;

  security.sudo.wheelNeedsPassword = false;

  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "de-latin1";
  time.timeZone = "Europe/Berlin";

  boot.zfs.devNodes = lib.mkDefault "/dev/disk/by-partlabel";

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_6_12;

  boot.loader = {
    efi = {
      canTouchEfiVariables = false;
      efiSysMountPoint = "/boot";
    };
    grub.enable = false;
    systemd-boot.enable = true;
  };

  boot.initrd.systemd.enable = true;

  disko.devices = {
    disk = {
      ssd = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              label = "boot";
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "discard" ];
              };
            };
            zfs = {
              label = "tank";
              size = "100%";
              type = "BF01";
              content = {
                type = "zfs";
                pool = "tank";
              };
            };
          };
        };
      };
    };
    zpool = {
      tank = {
        type = "zpool";
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = {
          acltype = "posixacl";
          canmount = "off";
          compression = "off";
          dnodesize = "auto";
          mountpoint = "none";
          normalization = "formD";
          redundant_metadata = "some";
          relatime = "on";
          utf8only = "on";
          xattr = "sa";
        };
        datasets = {
          "reserved" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              refreservation = "1G";
            };
          };
          "root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options.mountpoint = "legacy";
            postCreateHook = "zfs list -t snapshot -H -o name tank/root | grep -E '^tank/root@blank$' || zfs snapshot tank/root@blank";
          };
          "persist" = {
            type = "zfs_fs";
            mountpoint = "/persist";
            options.mountpoint = "legacy";
          };
          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              atime = "off";
              mountpoint = "legacy";
            };
          };
          "tmp" = {
            type = "zfs_fs";
            mountpoint = "/tmp";
            options = {
              atime = "off";
              devices = "off";
              mountpoint = "legacy";
              normalization = "none";
              setuid = "off";
              sync = "disabled";
              utf8only = "off";
            };
            postCreateHook = "zfs list -t snapshot -H -o name tank/tmp | grep -E '^tank/tmp@blank$' || zfs snapshot tank/tmp@blank";
          };
          "var" = {
            type = "zfs_fs";
            options = {
              devices = "off";
              exec = "off";
              mountpoint = "none";
              setuid = "off";
            };
          };
          "var/lib" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "var/lib/systemd" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/systemd";
            options = {
              devices = "off";
              exec = "off";
              mountpoint = "legacy";
              setuid = "off";
            };
          };
          "var/log" = {
            type = "zfs_fs";
            mountpoint = "/var/log";
            options.mountpoint = "legacy";
          };
          "root-user" = {
            type = "zfs_fs";
            mountpoint = "/root";
            options.mountpoint = "legacy";
          };
          "home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options.mountpoint = "legacy";
          };
        };
      };
    };
  };
  fileSystems."/var/lib/systemd".neededForBoot = true;

  boot.initrd.systemd.services.rollback = {
    description = "Rollback root and tmp filesystems to a pristine state on boot";
    wantedBy = [
      "initrd.target"
    ];
    after = [ "zfs-import-tank.service" ];
    before = [ "sysroot.mount" ];
    path = with pkgs; [ zfs ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      zfs rollback -r tank/root@blank && echo "  >> >> root rollback complete << <<"
      zfs rollback -r tank/tmp@blank && echo "  >> >> tmp rollback complete << <<"
    '';
  };

  services.openssh.hostKeys = [
    {
      path = "/persist/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    {
      path = "/persist/etc/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

  environment.systemPackages = with pkgs; [
    git
    helix
    htop
    kitty.terminfo
    tree
  ];

  environment.shellAliases = {
    nrbb = "nixos-rebuild boot --keep-going --fast --use-remote-sudo --flake '.#'";
    nrbs = "nixos-rebuild switch --fast --use-remote-sudo --flake '.#'";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  networking.interfaces.eno1.useDHCP = lib.mkDefault true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?
}



/*
Connect Client to port FastEthernet 0/1
Connect Router to port FastEthernet 0/2
Connect Server to port FastEthernet 0/3
Connect Logger management port (USB interface) to port FastEthernet 0/4
Connect Logger monitoring port (built-in interface) to port GigabitEthernet 0/1

To configure the Cisco Switch:
> enable
# show vlan
# show interfaces
# configure terminal
(config)# no spanning-tree vlan 1
(config)# no spanning-tree vlan 2
(config)# no spanning-tree vlan 3
(config)# interface FastEthernet 0/1
(config-if)# switchport mode trunk
(config-if)# switchport trunk allowed vlan 1,2
(config-if)# switchport trunk native vlan 1
(config-if)# exit
(config)# interface FastEthernet 0/2
(config-if)# switchport mode trunk
(config-if)# switchport trunk allowed vlan 1,2,3
(config-if)# switchport trunk native vlan 1
(config-if)# exit
(config)# interface FastEthernet 0/3
(config-if)# switchport mode trunk
(config-if)# switchport trunk allowed vlan 1,3
(config-if)# switchport trunk native vlan 1
(config-if)# exit
(config)# interface FastEthernet 0/4
(config-if)# switchport mode trunk
(config-if)# switchport trunk allowed vlan 1
(config-if)# switchport trunk native vlan 1
(config-if)# exit
(config)# interface GigabitEthernet 0/1
(config-if)# switchport mode trunk
(config-if)# switchport nonegotiate
(config-if)# no ip address
(config-if)# exit
(config)# no monitor session 1
(config)# monitor session 1 source interface FastEthernet 0/2
(config)# monitor session 1 destination interface GigabitEthernet 0/1 encapsulation replicate
(config)# exit
# exit

Resources:
https://support.telosalliance.com/article/smctkhp4p3-how-to-setup-switched-port-analyzer-on-cisco-switches
https://www.cisco.com/c/de_de/support/docs/switches/catalyst-6500-series-switches/10570-41.html
*/
