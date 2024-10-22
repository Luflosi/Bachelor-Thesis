#!/usr/bin/env python

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

import os
import sys
import dpkt
import json
import argparse
from blake3 import blake3

parser = argparse.ArgumentParser(
                    prog='parse',
                    description='Parse a packet capture file and convert it into a smaller and more useful form for our use-case')

parser.add_argument('-i', '--input', required=True)
parser.add_argument('-o', '--write-out-path')

args = parser.parse_args()

out = None
if args.write_out_path:
    out = os.environ['out']
    os.makedirs(out)

packets = []

with open(args.input, 'rb') as f:
    pcap = dpkt.pcap.Reader(f)

    found_beginning = False

    for (frame_number, (timestamp, buf)) in enumerate(pcap):
        frame_time_epoch = int(timestamp * 1000 * 1000 * 1000)

        eth = dpkt.ethernet.Ethernet(buf)

        if isinstance(eth.data, dpkt.ip.IP) or isinstance(eth.data, dpkt.ip6.IP6):
            ip = eth.data
        else:
            print(f'Skipping non IP Packet type ({eth.data.__class__.__name__})', file=sys.stderr)
            continue

        payload = bytes(ip.data)

        ip_payload_length = len(payload)

        # Heuristic to ignore the connection setup at the start
        if not found_beginning:
            if ip_payload_length > 400:
                found_beginning = True
            else:
                continue

        hash = blake3(payload).hexdigest()

        #if hash == '0565ac6f557ff24503dacb676fc51327eca7d04a097f878287f8d36003b93bae28168012a8a19a2b8e49db82d790fc1b6d1f04da1eca5f9769c75b29000c7db9':
        #    print(frame_number)

        packet = {
            'frame_number': frame_number,
            'frame_time_epoch': frame_time_epoch,
            'ip_payload_length': ip_payload_length,
            'hash': hash,
        }
        packets.append(packet)

print(len(packets), 'packets', file=sys.stderr)

if args.write_out_path:
    d = open(os.path.join(out, args.write_out_path), 'w', encoding='utf-8')
else:
    d = open(sys.stdout.fileno(), 'w', encoding='utf-8', closefd=False)

with d as f:
    json.dump(obj=packets, fp=f, allow_nan=False, separators=(',', ':'))
