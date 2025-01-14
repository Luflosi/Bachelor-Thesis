# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  encapsulation,
}:

assert builtins.elem encapsulation (builtins.attrNames (import ../../constants/protocols.nix));

{ lib, pkgs, ... }:
{
  name = "measurement";

  defaults = { ... }: {
    imports = [
      ../../profiles/virtual.nix
    ];
  };

  nodes = {
    client = { ... }: {
      imports = [
        ../../hosts/client
        ../../hosts/client/profiles/virtual.nix
        ../../hosts/client/protocols/${encapsulation}.nix
      ];
    };

    router = { ... }: {
      imports = [
        ../../hosts/router
        ../../hosts/router/profiles/virtual.nix
      ];
    };

    server = { ... }: {
      imports = [
        ../../hosts/server
        ../../hosts/server/profiles/virtual.nix
        ../../hosts/server/protocols/${encapsulation}.nix
      ];
    };

    # The virtual switch of the test setup acts like a hub.
    # This makes it easy to capture the packets in a separate VM.
    # See https://github.com/NixOS/nixpkgs/blob/69bee9866a4e2708b3153fdb61c1425e7857d6b8/nixos/lib/test-driver/test_driver/vlan.py#L43
    logger = { ... }: {
      imports = [
        ../../hosts/logger
        ../../hosts/logger/profiles/virtual.nix
      ];
    };
  };

  testScript = "";
}
