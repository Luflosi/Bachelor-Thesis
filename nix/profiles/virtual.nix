# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{ lib, ... }: {
  virtualisation.graphics = false;
  virtualisation.memorySize = lib.mkDefault 512;
  virtualisation.qemu.networkingOptions = lib.mkForce []; # Get rid of the default eth0 interface
  virtualisation.diskSize = lib.mkDefault 256;
}
