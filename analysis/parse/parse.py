#!/usr/bin/env python
# -*- coding: utf-8 -*-

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

import os
import sys
import dpkt
import json
import argparse
from blake3 import blake3


def time_to_epoch(timestamp):
    return int(timestamp * 1000 * 1000 * 1000)

def epoch_to_time(epoch):
    return epoch / 1000 / 1000 / 1000

parser = argparse.ArgumentParser(
                    prog='parse',
                    description='Parse a packet capture file and convert it into a smaller and more useful form for our use-case')

parser.add_argument('-i', '--input', required=True)
parser.add_argument('-m', '--metadata')
parser.add_argument('-o', '--write-out-path')
parser.add_argument('-e', '--remove-ends',
                    action='store_true')

args = parser.parse_args()

out = None
if args.write_out_path:
    with open('.attrs.json', 'r', encoding='utf-8') as f:
        out = json.load(f)['outputs']['out']
    os.makedirs(out)

packets = []

if args.remove_ends:
    assert args.metadata, 'CLI option --remove-ends requires --metadata'
    with open(args.metadata, 'rb') as f:
        metadata = json.load(f)
    test_duration_s = metadata['test_duration_s']

with open(args.input, 'rb') as f:
    pcap = dpkt.pcap.Reader(f)

    found_beginning = False
    potential_end_buffer = []
    end_timestamp = None

    for (frame_number, (timestamp, buf)) in enumerate(pcap):
        frame_time_epoch = time_to_epoch(timestamp)

        eth = dpkt.ethernet.Ethernet(buf)

        if isinstance(eth.data, dpkt.ip.IP) or isinstance(eth.data, dpkt.ip6.IP6):
            ip = eth.data
        else:
            print(f'Skipping non IP Packet type ({eth.data.__class__.__name__})', file=sys.stderr)
            continue

        payload = bytes(ip.data)

        ip_payload_length = len(payload)

        # Heuristic to ignore the connection setup at the start
        if args.remove_ends:
            if not found_beginning:
                if ip_payload_length <= 400:
                    continue
                found_beginning = True
                end_timestamp = timestamp + test_duration_s + 1 # Add one second, because in statistics.py the last partial second will be removed again
            elif timestamp >= end_timestamp:
                break

        hash = blake3(payload).hexdigest()

        #if hash == '0565ac6f557ff24503dacb676fc51327eca7d04a097f878287f8d36003b93bae28168012a8a19a2b8e49db82d790fc1b6d1f04da1eca5f9769c75b29000c7db9':
        #    print(frame_number)

        packet = {
            'frame_number': frame_number,
            'frame_time_epoch': frame_time_epoch,
            'ip_payload_length': ip_payload_length,
            'hash': hash,
        }

        # Heuristic to ignore the connection teardown at the end
        if args.remove_ends:
            if ip_payload_length <= 400:
                potential_end_buffer.append(packet)
                continue
            if potential_end_buffer != []: # It was not actually the end
                packets += potential_end_buffer
                potential_end_buffer = []
        packets.append(packet)

    if args.remove_ends:
        last_epoch = packets[-1]['frame_time_epoch']
        first_epoch = packets[0]['frame_time_epoch']
        delta_epoch = last_epoch - first_epoch
        min_allowed_time = test_duration_s
        max_allowed_time = min_allowed_time + 1
        assert time_to_epoch(min_allowed_time) <= delta_epoch < time_to_epoch(max_allowed_time), f'The packet capture does not have the expected length, was {epoch_to_time(delta_epoch)}, not between {min_allowed_time} and {max_allowed_time}'

print(len(packets), 'packets', file=sys.stderr)

if args.write_out_path:
    d = open(os.path.join(out, args.write_out_path), 'w', encoding='utf-8')
else:
    d = open(sys.stdout.fileno(), 'w', encoding='utf-8', closefd=False)

with d as f:
    json.dump(obj=packets, fp=f, allow_nan=False, sort_keys=True, separators=(',', ':'))
