# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ config, ... }: {
  systemd.network.networks."40-${config.services.icmptx.server.tun}" = {
    name = config.services.icmptx.server.tun;
    networkConfig = {
      DHCP = "no";
      Address = [
        "fdb1:f1ae:e1d5::3/64"
        "192.168.21.3/24"
      ];
    };
  };

  services.icmptx.server = {
    enable = true;
    serverIPv4 = "192.168.2.3";
  };
}
