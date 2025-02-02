# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

# Map each protocol to its overhead in bytes.
# Overheads are calculated for IPv4.
# So far all protocols have a fixed amount of overhead but this may not always be the case.
# If the overhead may vary for a protocol, I need to think of something else.

{
  "none" = 0;
  "WireGuard" = 8 + 32 + 20; # UDP + WireGuard + IPv4
  "icmptx" = 8 + 20; # ICMP + IPv4
  "iodine" = 0; # TODO
}
