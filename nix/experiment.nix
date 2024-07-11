# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ lib, ... }:
let
  testTimeSec = 60;
  useBBR = false;
  pingTimeout = 30;
  pingTimeoutStr = toString pingTimeout;
  iperfArgs = [
    "--time" (toString testTimeSec)
    "--udp"
    "--parallel" "1"
    "--length" "1300"
    "--bitrate" "100M"
    "--fq-rate" "100M"
    "--dont-fragment"
    "--udp-counters-64bit"
    "-R"
  ];
  iperfArgsStr = lib.concatStringsSep " " iperfArgs;
in
{
  name = "experiment";

  nodes = let
    commonOptions = {
      virtualisation.graphics = false;
      virtualisation.memorySize = lib.mkDefault 512;
      virtualisation.qemu.networkingOptions = lib.mkForce []; # Get rid of the default eth0 interface
      virtualisation.diskSize = lib.mkDefault 256;
      networking.nftables.enable = true;
      networking.useDHCP = false;
      systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";
    };
  in {
    client = { lib, pkgs, ... }: lib.mkMerge [
      commonOptions
      {
        environment.systemPackages = with pkgs; [
          iperf3
        ];

        boot.kernel.sysctl."net.ipv4.tcp_congestion_control" = lib.mkIf useBBR "bbr";

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
            Address = [
              "192.168.0.2/24"
              "fd36:9509:c39c::1/64"
            ];
            DHCPServer = true;
            IPv6SendRA = true;
          };
          dhcpServerConfig = {
            PoolOffset = 100;
            PoolSize = 20;
          };
          ipv6Prefixes = lib.singleton {
            Prefix = "fd36:9509:c39c::/64";
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
        systemd.network.networks."40-wan".networkConfig.IPv6AcceptRA = false;

        networking.interfaces.wan.ipv4.addresses = lib.singleton {
          address = "192.168.2.2";
          prefixLength = 24;
        };
        networking.interfaces.wan.ipv6.addresses = lib.singleton {
          address = "fd9d:c839:3e89::2";
          prefixLength = 64;
        };

        boot.kernel.sysctl = {
          "net.ipv4.conf.all.forwarding" = "1";
          "net.ipv6.conf.all.forwarding" = "1";
          "net.ipv6.conf.default.forwarding" = "1";
        };

        virtualisation.interfaces = {
          lan.vlan = 1;
          wan.vlan = 2;
        };
      }
    ];

    server = { config, lib, ... }: lib.mkMerge [
      commonOptions
      {
        services.iperf3.enable = true;
        services.iperf3.openFirewall = true;
        networking.firewall.allowedUDPPorts = lib.singleton config.services.iperf3.port;

        boot.kernel.sysctl."net.ipv4.tcp_congestion_control" = lib.mkIf useBBR "bbr";

        networking.interfaces.wan.ipv4 = {
          addresses = lib.singleton {
            address = "192.168.2.3";
            prefixLength = 24;
          };
          routes = lib.singleton {
            address = "192.168.0.0";
            prefixLength = 24;
            via = "192.168.2.2";
          };
        };

        networking.interfaces.wan.ipv6 = {
          addresses = lib.singleton {
            address = "fd9d:c839:3e89::3";
            prefixLength = 64;
          };
          routes = lib.singleton {
            address = "fd36:9509:c39c::";
            prefixLength = 64;
            via = "fd9d:c839:3e89::2";
          };
        };

        virtualisation.interfaces.wan.vlan = 2;
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

    client.wait_until_succeeds("ip a | grep '192.168.0'")
    client.wait_until_succeeds("ip a | grep 'fd36:9509:c39c:0:'")

    client.succeed("ip a >&2")
    client.succeed("(ip route && ip -6 route) >&2")
    router.succeed("ip a >&2")
    router.succeed("(ip route && ip -6 route) >&2")
    server.succeed("ip a >&2")
    server.succeed("(ip route && ip -6 route) >&2")
    logger.succeed("ip a >&2")
    logger.succeed("(ip route && ip -6 route) >&2")


    # https://stackoverflow.com/questions/614795/simulate-delayed-and-dropped-packets-on-linux
    # https://man7.org/linux/man-pages/man8/tc-netem.8.html
    router.succeed(
      'tc qdisc add dev lan root netem'
      ' delay 200ms 100ms distribution normal'
      ' loss 0.5% 25%'
      ' corrupt 0.1% 10%'
      ' duplicate 0.2% 10%'
      ' reorder 0.1%'
    )
    router.succeed("tc qdisc show dev lan >&2")

    logger.succeed("tcpdump -n -B 10240 -i lan -w /ram/lan.pcap 2>/ram/stderr-lan >/dev/null & echo $! >/ram/pid-lan")
    logger.succeed("tcpdump -n -B 10240 -i wan -w /ram/wan.pcap 2>/ram/stderr-wan >/dev/null & echo $! >/ram/pid-wan")

    # Wait for tcpdump to start recording
    client.succeed("sleep 1")

    client.wait_until_succeeds("ping -c 1 fd9d:c839:3e89::3 >&2", timeout=${pingTimeoutStr})
    client.wait_until_succeeds("ping -c 1 192.168.2.3 >&2", timeout=${pingTimeoutStr})
    # TODO: test in the other direction as well
    client.succeed("iperf -c 192.168.2.3 ${iperfArgsStr} >&2")
    client.wait_until_succeeds("ping -c 1 192.168.2.3 >&2", timeout=${pingTimeoutStr})

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
