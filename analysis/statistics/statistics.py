#!/usr/bin/env python
# -*- coding: utf-8 -*-

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

import os
import sys
import json
import argparse
from collections import defaultdict


BUCKET_DURATION_S = 1 # In Seconds


def read_json_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def time_ns_to_ms(time):
    return time / 1000 / 1000


def time_ns_to_s(time):
    return time_ns_to_ms(time) / 1000


def bytes_to_megabytes(bytes):
    return bytes / 1000 / 1000


def bytes_to_bits(bytes):
    return bytes * 8


parser = argparse.ArgumentParser(
                    prog='statistics',
                    description='Aggregate the data into one second chunks and compute statistics for each chunk')

parser.add_argument('-1', '--pre', required=True)
parser.add_argument('-2', '--post', required=True)
parser.add_argument('-a', '--overhead', required=True)
parser.add_argument('-o', '--write-out-path',
                    action='store_true')

args = parser.parse_args()

post_packets = read_json_file(args.post)
pre_packets = read_json_file(args.pre)
overhead = int(args.overhead)
out = None
if args.write_out_path:
    out = os.environ['out']
    os.makedirs(out)

post_hash_to_frames_map = defaultdict(list)
for packet in post_packets:
    frame_number = packet['frame_number']
    frame_time_epoch = packet['frame_time_epoch']
    hash = bytes.fromhex(packet['hash'])
    assert len(hash) == 32, f'Hash length was {len(hash)}'
    ip_payload_length = packet['ip_payload_length']
    assert ip_payload_length > 0, f'ip_payload_length is not greater than zero ({ip_payload_length})'
    post_hash_to_frames_map[hash].append((frame_number, frame_time_epoch, ip_payload_length))
    del(hash, frame_number, frame_time_epoch, ip_payload_length)


def validate_pre_packets(pre_packets):
    frames = []
    set_of_hashes = set()
    previous_frame_number = None
    previous_frame_time_epoch = None
    for packet in pre_packets:
        frame_number = packet['frame_number']
        frame_time_epoch = packet['frame_time_epoch']
        hash_str = packet['hash']
        hash = bytes.fromhex(hash_str)
        assert hash not in set_of_hashes, f'hash {hash_str} is not unique'
        assert len(hash) == 32, f'Hash length was {len(hash)}'
        assert previous_frame_number == None or frame_number > previous_frame_number, f'frame_number ({frame_number}) is not greater than the previous one ({previous_frame_number})'
        assert previous_frame_time_epoch == None or frame_time_epoch > previous_frame_time_epoch, f'frame_time_epoch ({frame_time_epoch}) is not greater than the previous one ({previous_frame_time_epoch})'
        ip_payload_length = packet['ip_payload_length']
        assert ip_payload_length > 0, f'ip_payload_length is not greater than zero ({ip_payload_length})'
        previous_frame_number = frame_number
        previous_frame_time_epoch = frame_time_epoch
        set_of_hashes.add(hash)
        frame = (hash, frame_number, frame_time_epoch, ip_payload_length)
        frames.append(frame)
    return frames


def split_into_buckets(pre_info):
    buckets = {}
    bucket = []
    bucket_start_time = None
    bucket_end_time = None
    for frame in pre_info:
        (_hash, _frame_number, frame_time_epoch, _ip_payload_length) = frame
        frame_time = time_ns_to_s(frame_time_epoch)
        if bucket_start_time == None:
            bucket_start_time = frame_time
        if bucket_end_time == None:
            bucket_end_time = bucket_start_time + BUCKET_DURATION_S
        if frame_time >= bucket_end_time:
            avg_time = (bucket_start_time + bucket_end_time) / 2
            buckets[avg_time] = bucket
            bucket = []
            del(avg_time)
            bucket_start_time = bucket_end_time
            bucket_end_time += BUCKET_DURATION_S
        bucket.append(frame)
    # We throw away a small amount of data at the end because the last bucket is incomplete
    return buckets


pre_info = validate_pre_packets(pre_packets)
del(pre_packets)

pre_buckets = split_into_buckets(pre_info)
del(pre_info)


time_series = []

for time, pre_bucket in pre_buckets.items():
    packet_count = 0
    dropped_packets = 0
    duplicate_packets = 0
    latencies = []
    payload_length_sum = 0
    for (pre_hash, pre_frame_number, pre_frame_time_epoch, pre_ip_payload_length) in pre_bucket:
        packets = post_hash_to_frames_map[pre_hash]
        number_of_packet_copies = len(packets)
        if number_of_packet_copies < 1:
            dropped_packets += 1
            continue
        duplicate_packets += number_of_packet_copies - 1
        first_arriving_copy_of_packet = None
        for packet in packets:
            if first_arriving_copy_of_packet == None:
                first_arriving_copy_of_packet = packet
                continue
            (_post_frame_number, post_first_frame_time_epoch, _post_ip_payload_length) = first_arriving_copy_of_packet
            if post_frame_time_epoch < post_first_frame_time_epoch:
                first_arriving_copy_of_packet = packet
        (post_frame_number, post_frame_time_epoch, post_ip_payload_length) = first_arriving_copy_of_packet
        latency = time_ns_to_ms(post_frame_time_epoch - pre_frame_time_epoch)
        if latency < 0:
            print(f'WARNING: packet arrived {-latency} ms before it was sent', file=sys.stderr)
        packet_count += 1
        payload_length = pre_ip_payload_length - overhead
        payload_length_sum += payload_length
        latencies.append(latency)
    throughput = bytes_to_bits(bytes_to_megabytes(payload_length_sum)) / BUCKET_DURATION_S
    statistics = {
        'time': time,
        'counts': {
            'packets': packet_count, # Packets which were sent and then received at least once, not counting duplicates (If two copies arrive, count only one)
            'dropped': dropped_packets, # Packets which were sent but not received
            'duplicate': duplicate_packets, # Packets which were received more than once
        },
        'throughput': throughput,
        'latencies': latencies,
    }
    time_series.append(statistics)


data = {
    'duration': BUCKET_DURATION_S,
    'units': {
        'duration': 's',
        'latency': 'ms',
        'throughput': 'MBit/s',
    },
    'time_series': time_series,
}

if out != None:
    d = open(os.path.join(out, 'statistics.json'), 'w', encoding='utf-8')
else:
    d = open(sys.stdout.fileno(), 'w', encoding='utf-8', closefd=False)

with d as f:
    json.dump(obj=data, fp=f, allow_nan=False, separators=(',', ':'))
