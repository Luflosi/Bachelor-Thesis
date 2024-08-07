# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ lib, ... }:
let
  testTimeSec = 60;
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

  nodes = {
    client =  { ... }: {
      imports = [
        ./profiles/virtual.nix
        ./hosts/client.nix
      ];
    };

    router =  { ... }: {
      imports = [
        ./profiles/virtual.nix
        ./hosts/router.nix
      ];
    };

    server =  { ... }: {
      imports = [
        ./profiles/virtual.nix
        ./hosts/server.nix
      ];
    };

    # The virtual switch of the test setup acts like a hub.
    # This makes it easy to capture the packets in a separate VM.
    # See https://github.com/NixOS/nixpkgs/blob/69bee9866a4e2708b3153fdb61c1425e7857d6b8/nixos/lib/test-driver/test_driver/vlan.py#L43
    logger =  { ... }: {
      imports = [
        ./profiles/virtual.nix
        ./hosts/logger.nix
      ];
    };
  };

  testScript = ''
    start_all()

    client.wait_for_unit("network.target")
    router.wait_for_unit("network.target")
    server.wait_for_unit("network.target")
    logger.wait_for_unit("network.target")
    client.wait_for_unit("network-online.target")
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

    usage_str = logger.succeed("df --output=pcent /ram | sed -e /^Use%/d").strip()
    usage = int(usage_str[:-1])
    assert usage < 90, f"The disk is too full ({usage_str}), please increase the size"

    logger.copy_from_vm("/ram/lan.pcap", "")
    logger.copy_from_vm("/ram/wan.pcap", "")

    # TODO: assert that the files are valid and have not been cut short
  '';
}
