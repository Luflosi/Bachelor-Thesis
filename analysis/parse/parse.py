#!/usr/bin/env python

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

import sys
import json


def parse_time_epoch(time_epoch_str):
    time_s_str, time_frac_str = time_epoch_str.split('.')
    assert len(time_frac_str) == 9
    time_s_int = int(time_s_str)
    time_ns_int = int(time_frac_str)
    assert time_s_int > 0
    time_epoch_ns = time_s_int * 1000 * 1000 * 1000 + time_ns_int
    return time_epoch_ns


def get_only_item(data, key, convert):
    values = data[key]
    assert len(values) == 1
    value = values[0]
    return convert(value)


packets = []

for line in sys.stdin:
    data = json.loads(line)
    if not 'timestamp' in data:
        assert list(data.keys()) == ['index']
        assert list(data['index'].keys()) == ['_index', '_type']
        assert data['index']['_type'] == 'doc'
        continue
    assert list(data.keys()) == ['timestamp', 'layers']
    data = data['layers']
    assert list(data.keys()) == ['frame_number', 'frame_time_epoch', 'iperf3_sequence', 'udp_length']
    packet = {
        'frame_number': get_only_item(data, 'frame_number', int),
        'frame_time_epoch': get_only_item(data, 'frame_time_epoch', parse_time_epoch),
        'iperf3_sequence': get_only_item(data, 'iperf3_sequence', int),
        'udp_length': get_only_item(data, 'udp_length', int)
    }
    packets.append(packet)

print(len(packets), 'packets', file=sys.stderr)
json.dump(obj=packets, fp=sys.stdout, allow_nan=False, separators=(',', ':'))
