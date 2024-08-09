#!/usr/bin/env python

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

import os
import sys
import json
from collections import defaultdict


def read_json_file(file_path):
    with open(file_path, 'r') as f:
        return json.load(f)


assert 3 <= len(sys.argv) <= 4
lan_packets = read_json_file(sys.argv[1])
wan_packets = read_json_file(sys.argv[2])
out = None
if len(sys.argv) == 4:
    assert sys.argv[3] == '--write-out-path'
    out = os.environ['out']

lan_iperf3_sequence_to_frames_map = defaultdict(list)
for packet in lan_packets:
    frame_number = packet['frame_number']
    frame_time_epoch = packet['frame_time_epoch']
    iperf3_sequence = packet['iperf3_sequence']
    lan_iperf3_sequence_to_frames_map[iperf3_sequence].append((frame_number, frame_time_epoch))

wan_iperf3_sequence_to_frame_map = {}
for packet in wan_packets:
    frame_number = packet['frame_number']
    frame_time_epoch = packet['frame_time_epoch']
    iperf3_sequence = packet['iperf3_sequence']
    assert iperf3_sequence not in wan_iperf3_sequence_to_frame_map, f'iperf3_sequence number {iperf3_sequence} is already in map'
    wan_iperf3_sequence_to_frame_map[iperf3_sequence] = (frame_number, frame_time_epoch)


delta_t_count = 0
delta_t_sum = 0
for wan_iperf3_sequence, (wan_frame_time_epoch, wan_frame_time_epoch) in wan_iperf3_sequence_to_frame_map.items():
    packets = lan_iperf3_sequence_to_frames_map[wan_iperf3_sequence]
    # TODO: detect duplicates
    if len(packets) < 1:
        # TODO: count dropped packets
        continue
    (lan_frame_number, lan_frame_time_epoch) = packets[0]
    delta_t_sum += lan_frame_time_epoch - wan_frame_time_epoch
    delta_t_count += 1

latency_ns = delta_t_sum / delta_t_count
latency_ms = latency_ns / 1000 / 1000
print(latency_ms, 'ms')

if out != None:
    os.makedirs(out)
    with open(os.path.join(out, 'latency.txt'), 'w') as f:
        contents = str(latency_ms)
        f.write(contents)
