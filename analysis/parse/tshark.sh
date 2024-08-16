#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: CC0-1.0

tshark \
 -Y '_ws.col.protocol=="iPerf3" && iperf3.sequence' \
 -t e \
 -T ek \
 -e frame.number \
 -e frame.time_epoch \
 -e iperf3.sequence \
 -e udp.length \
 -r -
