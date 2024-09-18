#!/usr/bin/env python

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

import sys
import dpkt
import json
import hashlib

assert len(sys.argv) == 2


packets = []

with open(sys.argv[1], 'rb') as f:
    pcap = dpkt.pcap.Reader(f)

    for (frame_number, (timestamp, buf)) in enumerate(pcap):
        frame_time_epoch = int(timestamp * 1000 * 1000 * 1000)

        eth = dpkt.ethernet.Ethernet(buf)

        if isinstance(eth.data, dpkt.ip.IP) or isinstance(eth.data, dpkt.ip6.IP6):
            ip = eth.data
        else:
            print(f'Skipping non IP Packet type ({eth.data.__class__.__name__})', file=sys.stderr)

        digest = hashlib.blake2b(bytes(ip.data)).hexdigest()

        packet = {
            'frame_number': frame_number,
            'frame_time_epoch': frame_time_epoch,
            'blake2b': digest,
        }
        packets.append(packet)

print(len(packets), 'packets', file=sys.stderr)
json.dump(obj=packets, fp=sys.stdout, allow_nan=False, separators=(',', ':'))
