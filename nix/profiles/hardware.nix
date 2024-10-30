# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

# To install: nix run github:nix-community/nixos-anywhere -- --flake .#client nixos@nixos.lan

{ lib, pkgs, ... }: {
  services.openssh = {
    enable = true;
    allowSFTP = false;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
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
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL280aidPimp3aTHGiLN99bQS8AIv/Dz4+YkfxE8fgsp key"
    ];
  };

  programs.zsh.enable = true;

  security.sudo.wheelNeedsPassword = false;

  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "de-latin1";
  time.timeZone = "Europe/Berlin";

  boot.zfs.devNodes = lib.mkDefault "/dev/disk/by-partlabel";

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_6_10;

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

  networking.interfaces.eno1.useDHCP = true;

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
To configure the Cisco Switch:
enable
show vlan
show interfaces
configure terminal
interface fastethernet 0/1
switchport mode trunk
switchport trunk allowed vlan 1,2,3
switchport trunk native vlan 1
exit
interface fastethernet 0/2
switchport mode trunk
switchport trunk allowed vlan 1,2,3
switchport trunk native vlan 1
exit
interface fastethernet 0/3
switchport mode trunk
switchport trunk allowed vlan 1,2,3
switchport trunk native vlan 1
exit
interface fastethernet 0/4
switchport mode trunk
switchport trunk allowed vlan 1,2,3
switchport trunk native vlan 1
exit
exit
exit
*/
