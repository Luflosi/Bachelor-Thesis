[SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>]::
[SPDX-License-Identifier: GPL-3.0-only]::

# Bachelor Thesis
## Measuring the overhead of encryption and censorship evasion protocols over lossy links

## Dependencies:
- You need Linux to be able to build the VMs
- [Install Nix](https://zero-to-nix.com/start/install)

## To run the most basic measurement and then render some graphs:
- Execute `nix build github:Luflosi/Bachelor-Thesis` (no need to clone this repo)
- Look at the graphs in `./result`

## Build the report PDF:
- Execute `nix build github:Luflosi/Bachelor-Thesis#report` (no need to clone this repo)
- Look at the PDF in `./result`

## Run measurements on real hardware
- Have the correct hardware
- Install NixOS on the system, see comment in `nix/profiles/hardware.nix`
- Connect network cables
- Configure switch
- Make sure the Nix setting `auto-allocate-uids` is set to false
- Edit `test-matrix/parameters.json`
- Set the "platform" to "PC" instead of "VM"
- Only have one element in "encapsulation"
- Change other parameters as desired
- If encapsulation is not `none`, run `sudo /run/current-system/specialisation/encapsulation here/bin/switch-to-configuration test` on the client and server
- Run `nix build .#measurements --max-jobs 1 --option sandbox relaxed --print-build-logs --keep-going` to run all measurements
- Run `nix build .#graphsMulti` to analyze the data and render graphs (`result` symlink)

## License
The license is the GNU GPLv3 (GPL-3.0-only).
