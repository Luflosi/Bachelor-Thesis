# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  cacheID,
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

assert builtins.isInt cacheID;
assert test_duration_s > 0;
assert ip_payload_size > 0;
assert builtins.elem encapsulation (builtins.attrNames (import ../constants/protocols.nix));
assert delay_time_ms >= 0;
assert delay_jitter_ms >= 0;
assert builtins.elem delay_distribution [ "experimental" "normal" "pareto" "paretonormal" ];
assert loss_per_mille >= 0;
assert duplicate_per_mille >= 0;
assert reorder_per_mille >= 0;
assert delay_time_ms == 0 -> reorder_per_mille == 0;

{
  lib,
  settings,
  writeText,
  ...
}:
let
  pingTimeout = 30;
  pingTimeoutStr = toString pingTimeout;
  udpPayloadSize = ip_payload_size - 8;
  iperfArgs = [
    "-c" (if encapsulation == "none" then "192.168.2.3" else "192.168.20.3")
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

  parametersFile = writeText "parameters.json" (builtins.toJSON parameters);
in writeText "test-script" (''
  # Comment to allow invalidating the cache to rerun specific tests:
  # ${toString cacheID}

  start_all()

  configuration_revisions = {
'' + (lib.optionalString (settings.mode == "Hardware") ''
    "client": client.succeed("nixos-version --configuration-revision"),
    "router": router.succeed("nixos-version --configuration-revision"),
    "server": server.succeed("nixos-version --configuration-revision"),
    "logger": logger.succeed("nixos-version --configuration-revision"),
'') + ''
  }

  client.wait_for_unit("network.target")
  router.wait_for_unit("network.target")
  server.wait_for_unit("network.target")
  logger.wait_for_unit("network.target")
  client.succeed("systemctl start network-online.target")
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

  # Delete any queueing disciplines that may be left from previous tests on the hardware
  router.succeed("tc qdisc del dev lan root || true")

  # https://stackoverflow.com/questions/614795/simulate-delayed-and-dropped-packets-on-linux
  # https://man7.org/linux/man-pages/man8/tc-netem.8.html
  router.succeed(
    'tc qdisc add dev lan root netem'
    ${lib.optionalString (delay_time_ms > 0) "' delay ${toString delay_time_ms}ms${lib.optionalString (delay_jitter_ms > 0) " ${toString delay_jitter_ms}ms distribution ${delay_distribution}"}'"}
    ${lib.optionalString (loss_per_mille > 0) "' loss ${perMilleToPercentString loss_per_mille} ${loss_correlation}'"}
    ${lib.optionalString (duplicate_per_mille > 0) "' duplicate ${perMilleToPercentString duplicate_per_mille} ${duplicate_correlation}'"}
    ${lib.optionalString (reorder_per_mille > 0) "' reorder ${perMilleToPercentString reorder_per_mille}'"}
  )
  router.succeed("tc qdisc show dev lan >&2")

  logger.succeed("tcpdump --list-time-stamp-types >&2") # See https://nanxiao.github.io/tcpdump-little-book/posts/set-timestamp-type-and-precision-during-capture.html
  logger.succeed("systemctl restart tcpdump-lan.service")
  logger.succeed("systemctl restart tcpdump-wan.service")
  lan_id = logger.succeed("systemctl show -p InvocationID --value tcpdump-lan.service").strip()
  wan_id = logger.succeed("systemctl show -p InvocationID --value tcpdump-wan.service").strip()
  assert len(lan_id) > 10, "The lan InvocationID is too short"
  assert len(wan_id) > 10, "The wan InvocationID is too short"

  # Wait for tcpdump to start recording
  client.succeed("sleep 1")

  client.wait_until_succeeds("ping -c 1 fd9d:c839:3e89::3 >&2", timeout=${pingTimeoutStr})
  client.wait_until_succeeds("ping -c 1 192.168.2.3 >&2", timeout=${pingTimeoutStr})
  ${lib.optionalString (encapsulation != "none") ''client.wait_until_succeeds("ping -c 1 fded:51e9:828f::3 >&2", timeout=${pingTimeoutStr})''}
  ${lib.optionalString (encapsulation != "none") ''client.wait_until_succeeds("ping -c 1 192.168.20.3 >&2", timeout=${pingTimeoutStr})''}
  # TODO: test in the other direction as well
  client.succeed("iperf ${iperfArgsStr} >&2")
  ${lib.optionalString (encapsulation != "none") ''client.wait_until_succeeds("ping -c 1 192.168.20.3 >&2", timeout=${pingTimeoutStr})''}
  client.wait_until_succeeds("ping -c 1 192.168.2.3 >&2", timeout=${pingTimeoutStr})

  # TODO: find a better way to wait for wireshark to be done capturing
  client.succeed("sleep 1")

  ${lib.optionalString (encapsulation == "WireGuard") ''client.succeed("wg show >&2")''}
  ${lib.optionalString (encapsulation == "WireGuard") ''server.succeed("wg show >&2")''}

  logger.succeed("systemctl stop tcpdump-lan.service")
  logger.succeed("systemctl stop tcpdump-wan.service")

  logger.succeed(f"journalctl _SYSTEMD_INVOCATION_ID={lan_id} >&2")
  logger.succeed(f"journalctl _SYSTEMD_INVOCATION_ID={wan_id} >&2")

  def assert_no_dropped_packets(interface, id):
    log = logger.succeed(f"journalctl _SYSTEMD_INVOCATION_ID={id}")
    lines = log.splitlines()
    messages = [line.split(": ")[1] for line in lines]
    assert "0 packets dropped by kernel" in messages, f"The kernel dropped some packets on the {interface} interface"

  assert_no_dropped_packets("lan", lan_id)
  assert_no_dropped_packets("wan", wan_id)

  logger.succeed("lsof -t /pcap/pre.pcap >&2 || true")
  logger.succeed("lsof -t /pcap/post.pcap >&2 || true")
  # TODO: find a better way to wait for the file to be done writing
  logger.succeed("sleep 1")

  usage_str = logger.succeed("df --output=pcent /pcap | sed -e /^Use%/d").strip()
  usage = int(usage_str[:-1])
  assert usage < 90, f"The disk is too full ({usage_str}), please increase the size"

  logger.copy_from_vm("/pcap/pre.pcap")
  logger.copy_from_vm("/pcap/post.pcap")
  import os
  os.symlink("${parametersFile}", logger.out_dir / "parameters.json")
  if configuration_revisions != {}:
    import json
    with open(logger.out_dir / 'configuration_revisions.json', 'w', encoding='utf-8') as f:
      json.dump(obj=configuration_revisions, fp=f, allow_nan=False)

  # TODO: assert that the files are valid and have not been cut short
'')
