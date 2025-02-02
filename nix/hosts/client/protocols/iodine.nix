# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ ... }: {
  services.iodine.clients.testClient = {
    relay = "192.168.2.3";
    server = "example.com";
  };
}
