# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  test_duration_s,
  ip_payload_size,
  encapsulation,
  delay_time_ms,
  delay_jitter_ms,
  delay_distribution,
  loss_per_mille,
  loss_correlation,
  duplicate_per_mille,
  duplicate_correlation,
  reorder_per_mille,
}@parameters:

assert test_duration_s > 0;
assert ip_payload_size > 0;
assert builtins.elem encapsulation [ "none" "WireGuard" ];
assert delay_time_ms >= 0;
assert delay_jitter_ms >= 0;
assert builtins.elem delay_distribution [ "experimental" "normal" "pareto" "paretonormal" ];
assert loss_per_mille >= 0;
assert duplicate_per_mille >= 0;
assert reorder_per_mille >= 0;
assert delay_time_ms == 0 -> reorder_per_mille == 0;

{ lib, pkgs, ... }:
let
  pingTimeout = 30;
  pingTimeoutStr = toString pingTimeout;
  udpPayloadSize = ip_payload_size - 8;
  iperfArgs = [
    "--time" (toString test_duration_s)
    "--udp"
    "--udp-retry" "100"
    "--parallel" "1"
    "--length" (toString udpPayloadSize)
    "--bitrate" "100M"
    "--fq-rate" "100M"
    "--dont-fragment"
    "--udp-counters-64bit"
    "-R"
  ];
  iperfArgsStr = lib.concatStringsSep " " iperfArgs;

  perMilleToPercentString = input: let
    int = input / 10;
    frac = input - (int * 10);
  in "${toString int}.${toString frac}%";

  parametersFile = pkgs.writeText "parameters.json" (builtins.toJSON parameters);
in
{
  name = "experiment";

  defaults = { ... }: {
    imports = [
      ./profiles/virtual.nix
    ];
  };

  nodes = {
    client = { ... }: {
      imports = [
        ./hosts/client
        ./hosts/client/protocols/${encapsulation}.nix
      ];
    };

    router = { ... }: {
      imports = [
        ./hosts/router
      ];
    };

    server = { ... }: {
      imports = [
        ./hosts/server
        ./hosts/server/protocols/${encapsulation}.nix
      ];
    };

    # The virtual switch of the test setup acts like a hub.
    # This makes it easy to capture the packets in a separate VM.
    # See https://github.com/NixOS/nixpkgs/blob/69bee9866a4e2708b3153fdb61c1425e7857d6b8/nixos/lib/test-driver/test_driver/vlan.py#L43
    logger = { ... }: {
      imports = [
        ./hosts/logger
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
      ${lib.optionalString (delay_time_ms > 0) "' delay ${toString delay_time_ms}ms ${toString delay_jitter_ms}ms distribution ${delay_distribution}'"}
      ${lib.optionalString (loss_per_mille > 0) "' loss ${perMilleToPercentString loss_per_mille} ${loss_correlation}'"}
      ${lib.optionalString (duplicate_per_mille > 0) "' duplicate ${perMilleToPercentString duplicate_per_mille} ${duplicate_correlation}'"}
      ${lib.optionalString (reorder_per_mille > 0) "' reorder ${perMilleToPercentString reorder_per_mille}'"}
    )
    router.succeed("tc qdisc show dev lan >&2")

    logger.succeed("tcpdump --list-time-stamp-types >&2") # See https://nanxiao.github.io/tcpdump-little-book/posts/set-timestamp-type-and-precision-during-capture.html
    logger.succeed("tcpdump -n -B 10240 -i lan -w /ram/post.pcap 2>/ram/stderr-lan >/dev/null & echo $! >/ram/pid-lan")
    logger.succeed("tcpdump -n -B 10240 -i wan -w /ram/pre.pcap 2>/ram/stderr-wan >/dev/null & echo $! >/ram/pid-wan")

    # Wait for tcpdump to start recording
    client.succeed("sleep 1")

    client.wait_until_succeeds("ping -c 1 fd9d:c839:3e89::3 >&2", timeout=${pingTimeoutStr})
    client.wait_until_succeeds("ping -c 1 192.168.2.3 >&2", timeout=${pingTimeoutStr})
    ${lib.optionalString (encapsulation != "none") ''client.wait_until_succeeds("ping -c 1 fded:51e9:828f::3 >&2", timeout=${pingTimeoutStr})''}
    ${lib.optionalString (encapsulation != "none") ''client.wait_until_succeeds("ping -c 1 192.168.20.3 >&2", timeout=${pingTimeoutStr})''}
    # TODO: test in the other direction as well
    client.succeed("iperf -c ${if encapsulation == "none" then "192.168.2.3" else "192.168.20.3"} ${iperfArgsStr} >&2")
    ${lib.optionalString (encapsulation != "none") ''client.wait_until_succeeds("ping -c 1 192.168.20.3 >&2", timeout=${pingTimeoutStr})''}
    client.wait_until_succeeds("ping -c 1 192.168.2.3 >&2", timeout=${pingTimeoutStr})

    # TODO: find a better way to wait for wireshark to be done capturing
    client.succeed("sleep 1")

    ${lib.optionalString (encapsulation == "WireGuard") ''client.succeed("wg show >&2")''}
    ${lib.optionalString (encapsulation == "WireGuard") ''server.succeed("wg show >&2")''}

    logger.succeed('kill -s INT "$(</ram/pid-lan)"')
    logger.succeed('kill -s INT "$(</ram/pid-wan)"')
    logger.succeed('tail --pid="$(</ram/pid-lan)" -f /dev/null')
    logger.succeed('tail --pid="$(</ram/pid-wan)" -f /dev/null')

    logger.succeed("cat /ram/stderr-lan >&2")
    logger.succeed("cat /ram/stderr-wan >&2")

    assert "0 packets dropped by kernel" in logger.succeed("cat /ram/stderr-lan").splitlines(), "The kernel dropped some packets"
    assert "0 packets dropped by kernel" in logger.succeed("cat /ram/stderr-wan").splitlines(), "The kernel dropped some packets"

    logger.succeed("lsof -t /ram/pre.pcap >&2 || true")
    logger.succeed("lsof -t /ram/post.pcap >&2 || true")
    # TODO: find a better way to wait for the file to be done writing
    logger.succeed("sleep 1")

    usage_str = logger.succeed("df --output=pcent /ram | sed -e /^Use%/d").strip()
    usage = int(usage_str[:-1])
    assert usage < 90, f"The disk is too full ({usage_str}), please increase the size"

    logger.copy_from_vm("/ram/pre.pcap")
    logger.copy_from_vm("/ram/post.pcap")
    import os
    os.symlink("${parametersFile}", logger.out_dir / "parameters.json")

    # TODO: assert that the files are valid and have not been cut short
  '';
}
