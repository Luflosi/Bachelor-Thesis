[SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>]::
[SPDX-License-Identifier: GPL-3.0-only]::

# Bachelor Thesis
## Measuring the overhead of encryption and censorship evasion protocols over lossy links

> [!IMPORTANT]
> This project is only in its infancy at the time of writing.


## Dependencies:
- You need Linux to be able to build the VMs
- [Install Nix](https://zero-to-nix.com/start/install)

## To run the most basic measurement and then render some graphs:
- Execute `nix build github:Luflosi/Bachelor-Thesis` (no need to clone this repo)
- Look at the graphs in `./result`

## Build the report PDF:
- Execute `nix build github:Luflosi/Bachelor-Thesis#report` (no need to clone this repo)
- Look at the PDF in `./result`


## License
The license is the GNU GPLv3 (GPL-3.0-only).
