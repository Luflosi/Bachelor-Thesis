# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

final: prev: {
  my.iperf3 = prev.iperf3.overrideAttrs (old: {
    patches = old.patches ++ [
      # https://github.com/esnet/iperf/pull/1402 with conflicts resolved
      ./UDP_Connect_retry_mechanism.patch
    ];
  });
}
