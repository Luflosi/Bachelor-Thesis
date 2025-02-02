# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ ... }: {
  services.iodine.server = {
    enable = true;
    ip = "192.168.22.3/24";
    domain = "example.com";
  };
}
