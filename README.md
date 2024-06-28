[SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>]::
[SPDX-License-Identifier: GPL-3.0-only]::

# Bachelor Thesis
## Comparing the Network Throughput of Censorship Circumvention Protocols under Constrained Resources

> [!IMPORTANT]
> This project is only in its infancy at the time of writing.


To try out the most basic experiment:
- You need Linux to be able to build the VMs
- [Install Nix](https://zero-to-nix.com/start/install)
- Execute `nix build`
- Look at the files in `./result`


## TODO:
- Test various combinations of network interference and transport protocols
- Split the configuration of the VMs into separate files
- Adapt the configuration to run on real hardware
- Write a script to analyze the packet captures
- Add a LATEX template and start writing


## License
The license is the GNU GPLv3 (GPL-3.0-only).
