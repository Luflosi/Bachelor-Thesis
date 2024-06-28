# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ lib, ... }:
let
  testTimeSec = 60;
in
{
  name = "test";

  nodes = let
    commonOptions = {
      virtualisation.graphics = false;
      virtualisation.memorySize = lib.mkDefault 512;
      virtualisation.restrictNetwork = true;
      virtualisation.diskSize = lib.mkDefault 256;
      networking.nftables.enable = true;
      networking.useDHCP = false;
      systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";
    };
  in {
    client = { lib, pkgs, ... }: lib.mkMerge [
      commonOptions
      {
        environment.systemPackages = with pkgs;[
          iperf3
        ];

        networking.useNetworkd = true;
        networking.interfaces.lan.useDHCP = true;

        virtualisation.interfaces.lan.vlan = 1;
      }
    ];

    router = { lib, pkgs, ... }: lib.mkMerge [
      commonOptions
      {
        networking.useNetworkd = true;
        networking.firewall.enable = false;
        systemd.network.networks."40-lan" = {
          name = "lan";
          networkConfig = {
            Address = "192.168.0.2/24";
            DHCPServer = true;
          };
          dhcpServerConfig = {
            PoolOffset = 100;
            PoolSize = 20;
          };
          # This does not yet provide all the options we need
          # See https://www.freedesktop.org/software/systemd/man/latest/systemd.network.html#%5BNetworkEmulator%5D%20Section%20Options
          /*networkEmulatorConfig = {
            DelaySec = 0.2;
            DelayJitterSec = 0.1;
            LossRate = "0.1%";
            DuplicateRate = "0.1%";
          };*/
        };
        systemd.services.NetworkEmulator = {
          description = "Set the Network Emulator options for interface lan via the tc command";
            wantedBy = [ "network-setup.service" "network.target" ];
            before = [ "network-setup.service" ];
            bindsTo = [ "sys-subsystem-net-devices-lan.device" ];
            after = [ "network-pre.target" "sys-subsystem-net-devices-lan.device" ];
            serviceConfig.Type = "oneshot";
            serviceConfig.RemainAfterExit = true;
            stopIfChanged = false;
            path = [ pkgs.iproute2 ];
            # https://stackoverflow.com/questions/614795/simulate-delayed-and-dropped-packets-on-linux
            # https://man7.org/linux/man-pages/man8/tc-netem.8.html
            script = ''
              tc qdisc add dev lan root netem \
              delay 200ms 100ms distribution normal \
              loss 0.5% 25% \
              corrupt 0.1% 10% \
              duplicate 0.2% 10% \
              reorder 0.1%
            '';
        };

        virtualisation.interfaces = {
          lan.vlan = 1;
          wan = {
            vlan = 2;
            assignIP = true;
          };
        };
        networking.nat.enable = true;
        networking.firewall.filterForward = true;
        networking.nat.internalIPs = [ "192.168.0.0/24" ];
        networking.nat.externalInterface = "wan";
      }
    ];

    server = { lib, ... }: lib.mkMerge [
      commonOptions
      {
        services.iperf3.enable = true;
        services.iperf3.openFirewall = true;

        virtualisation.interfaces.wan = {
          vlan = 2;
          assignIP = true;
        };
      }
    ];

    # The virtual switch of the test setup acts like a hub.
    # This makes it easy to capture the packets in a separate VM.
    # See https://github.com/NixOS/nixpkgs/blob/69bee9866a4e2708b3153fdb61c1425e7857d6b8/nixos/lib/test-driver/test_driver/vlan.py#L43
    logger = { lib, pkgs, ... }: lib.mkMerge [
      commonOptions
      {
        systemd.network.enable = false;
        networking.firewall.enable = false;
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
    ];
  };

  testScript = ''
    start_all()

    client.wait_for_unit("network.target")
    router.wait_for_unit("network.target")
    server.wait_for_unit("network.target")
    logger.wait_for_unit("network.target")
    client.wait_for_unit("network-online.target")
    logger.wait_for_unit("network-online.target")
    server.wait_for_unit("iperf3.service")

    client.succeed("ip a >&2")
    router.succeed("ip a >&2")
    server.succeed("ip a >&2")
    logger.succeed("ip a >&2")

    router.succeed("tc qdisc show dev lan >&2")

    logger.succeed("tcpdump -n -B 10240 -i lan -w /ram/lan.pcap 2>/ram/stderr-lan >/dev/null & echo $! >/ram/pid-lan")
    logger.succeed("tcpdump -n -B 10240 -i wan -w /ram/wan.pcap 2>/ram/stderr-wan >/dev/null & echo $! >/ram/pid-wan")

    # Wait for tcpdump to start recording
    client.succeed("sleep 1")

    client.succeed("ping -c 1 server >&2")
    # TODO: test in the other direction as well
    client.succeed("iperf -c server --time ${toString testTimeSec} >&2")
    client.succeed("ping -c 1 server >&2")

    # TODO: find a better way to wait for wireshark to be done capturing
    client.succeed("sleep 1")

    logger.succeed('kill -s INT "$(</ram/pid-lan)"')
    logger.succeed('kill -s INT "$(</ram/pid-wan)"')
    logger.succeed('tail --pid="$(</ram/pid-lan)" -f /dev/null')
    logger.succeed('tail --pid="$(</ram/pid-wan)" -f /dev/null')

    logger.succeed("cat /ram/stderr-lan >&2")
    logger.succeed("cat /ram/stderr-wan >&2")

    assert "0 packets dropped by kernel" in logger.succeed("cat /ram/stderr-lan").splitlines(), "The kernel dropped some packets"
    assert "0 packets dropped by kernel" in logger.succeed("cat /ram/stderr-wan").splitlines(), "The kernel dropped some packets"

    logger.succeed("lsof -t /ram/lan.pcap >&2 || true")
    logger.succeed("lsof -t /ram/wan.pcap >&2 || true")
    # TODO: find a better way to wait for the file to be done writing
    logger.succeed("sleep 1")

    logger.succeed("df -h >&2")
    usage_str = logger.succeed("df --output=pcent /ram | sed -e /^Use%/d").strip()
    usage = int(usage_str[:-1])
    assert usage < 90, f"The disk is too full ({usage_str}), please increase the size"

    logger.copy_from_vm("/ram/lan.pcap", "")
    logger.copy_from_vm("/ram/wan.pcap", "")

    # TODO: assert that the files are valid and have not been cut short
  '';
}
