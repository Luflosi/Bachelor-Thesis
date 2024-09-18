#!/usr/bin/env python

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

import sys
import json
import decimal
import hashlib
import scapy.all as scapy
from scapy import layers

assert len(sys.argv) == 2


packets = []

for frame_number, frame in enumerate(scapy.rdpcap(sys.argv[1])):
    assert isinstance(frame, layers.l2.Ether), f'Frame is not an Ethernet frame ({type(frame)})'

    # Skip non-IP packets
    if not scapy.IP in frame:
        print('skipping', frame)
        continue

    assert isinstance(frame.time, decimal.Decimal), f'frame.time is not a Decimal ({type(frame.time)})'
    frame_time_epoch = int(frame.time * 1000 * 1000 * 1000)

    ip = frame[scapy.IP]

    digest = hashlib.blake2b(bytes(ip.payload)).hexdigest()

    packet = {
        'frame_number': frame_number,
        'frame_time_epoch': frame_time_epoch,
        'blake2b': digest,
    }
    packets.append(packet)

print(len(packets), 'packets', file=sys.stderr)
json.dump(obj=packets, fp=sys.stdout, allow_nan=False, separators=(',', ':'))
