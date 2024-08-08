[SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>]::
[SPDX-License-Identifier: GPL-3.0-only]::

# Bachelor Thesis
## Comparing the Network Throughput of Censorship Circumvention Protocols under Constrained Resources

> [!IMPORTANT]
> This project is only in its infancy at the time of writing.


## Dependencies:
- You need Linux to be able to build the VMs
- [Install Nix](https://zero-to-nix.com/start/install)


## To try out the most basic experiment:
- Execute `nix build github:Luflosi/Bachelor-Thesis` (no need to clone this repo)
- Look at the files in `./result`

## Build the report PDF:
- Execute `nix build github:Luflosi/Bachelor-Thesis#report` (no need to clone this repo)
- Look at the PDF in `./result`


## TODO:
- Test various combinations of network interference and transport protocols
- Adapt the configuration to run on real hardware
- Write a script to analyze the packet captures
- Try out [qperf](https://github.com/rbruenig/qperf)
- Test performance in both directions
- Try out https://github.com/esnet/iperf/pull/1402


## License
The license is the GNU GPLv3 (GPL-3.0-only).
