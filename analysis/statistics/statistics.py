#!/usr/bin/env python
# -*- coding: utf-8 -*-

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

import os
import sys
import json
import math
import argparse
from collections import defaultdict


BUCKET_DURATION_S = 1 # In Seconds
MAX_LATENCY_MS = 5000
MIN_LATENCY_MS = -100


def read_json_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def time_ns_to_ms(time):
    return time / 1000 / 1000


def time_ns_to_s(time):
    return time_ns_to_ms(time) / 1000


def time_ms_to_ns(time):
    return time * 1000 * 1000


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

post_packets = read_json_file(os.path.join(args.post, 'post.json'))
pre_packets = read_json_file(os.path.join(args.pre, 'pre.json'))

def read_metadata():
    post_metadata = read_json_file(os.path.join(args.post, 'parameters.json'))
    pre_metadata = read_json_file(os.path.join(args.pre, 'parameters.json'))
    assert post_metadata == pre_metadata, f'pre and post metadata differs: {pre_metadata} != {post_metadata}'
    return pre_metadata

metadata = read_metadata()

overhead = int(args.overhead)
out = None
if args.write_out_path:
    with open('.attrs.json', 'r', encoding='utf-8') as f:
        out = json.load(f)['outputs']['out']
    os.makedirs(out)

post_hash_to_frames_map = defaultdict(list)
for packet in post_packets:
    frame_number = packet['frame_number']
    frame_time_epoch = packet['frame_time_epoch']
    hash_str = packet['hash']
    assert len(hash_str) == 64, f'Hash string length is {len(hash_str)}'
    hash = bytes.fromhex(hash_str)
    assert len(hash) == 32, f'Hash length was {len(hash)}'
    ip_payload_length = packet['ip_payload_length']
    assert ip_payload_length > 0, f'ip_payload_length is not greater than zero ({ip_payload_length})'
    post_hash_to_frames_map[hash].append((frame_number, frame_time_epoch, ip_payload_length))
    del(hash, frame_number, frame_time_epoch, ip_payload_length)


def validate_pre_packets(pre_packets):
    frames = []
    hash_to_pre_time_epochs_map = defaultdict(list)
    previous_frame_number = None
    previous_frame_time_epoch = None
    duplicate_count = 0
    for packet in pre_packets:
        frame_number = packet['frame_number']
        frame_time_epoch = packet['frame_time_epoch']
        hash_str = packet['hash']
        assert len(hash_str) == 64, f'Hash string length is {len(hash_str)}'
        hash = bytes.fromhex(hash_str)
        assert len(hash) == 32, f'Hash length is {len(hash)}'
        assert previous_frame_number is None or frame_number > previous_frame_number, f'frame_number ({frame_number}) is not greater than the previous one ({previous_frame_number})'
        assert previous_frame_time_epoch is None or frame_time_epoch >= previous_frame_time_epoch, f'frame_time_epoch ({frame_time_epoch}) is not greater than the previous one ({previous_frame_time_epoch})'
        ip_payload_length = packet['ip_payload_length']
        assert ip_payload_length > 0, f'ip_payload_length is not greater than zero ({ip_payload_length})'
        if hash in hash_to_pre_time_epochs_map:
            duplicate_count += 1
            for other_frame_time_epoch in hash_to_pre_time_epochs_map[hash]:
                diff = abs(frame_time_epoch - other_frame_time_epoch)
                assert diff > time_ms_to_ns(MIN_LATENCY_MS + MAX_LATENCY_MS), f'The pre packet capture contains duplicate packets close together ({time_ns_to_ms(diff)} ms)'
        hash_to_pre_time_epochs_map[hash].append(frame_time_epoch)
        frame = (hash, frame_number, frame_time_epoch, ip_payload_length)
        frames.append(frame)
        previous_frame_number = frame_number
        previous_frame_time_epoch = frame_time_epoch

    assert duplicate_count >= 0, f'duplicate_count is {duplicate_count}'
    if duplicate_count > 0:
        print(f'WARNING: {duplicate_count} pre packets were not unique', file=sys.stderr)
    return frames, hash_to_pre_time_epochs_map


def split_into_buckets(pre_info):
    buckets = {}
    bucket = []
    bucket_start_time = None
    bucket_end_time = None
    for frame in pre_info:
        (_hash, _frame_number, frame_time_epoch, _ip_payload_length) = frame
        frame_time = time_ns_to_s(frame_time_epoch)
        if bucket_start_time is None:
            bucket_start_time = frame_time
        if bucket_end_time is None:
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


pre_info, hash_to_pre_time_epochs_map = validate_pre_packets(pre_packets)
del(pre_packets)

pre_buckets = split_into_buckets(pre_info)
del(pre_info)


time_series = []
min_latency = math.inf
time_traveling_packet_count = 0

for time, pre_bucket in pre_buckets.items():
    packet_count = 0
    dropped_packets = 0
    duplicate_packets = 0
    latencies = []
    ip_payload_lengths = []
    payload_length_sum_with_overhead = 0
    payload_length_sum_without_overhead = 0
    for (pre_hash, pre_frame_number, pre_frame_time_epoch, pre_ip_payload_length) in pre_bucket:
        packets = post_hash_to_frames_map[pre_hash]

        def filter_post_packets_by_duplicate_pre_packets(post_packets):
            if len(hash_to_pre_time_epochs_map[pre_hash]) <= 1:
                return post_packets
            new_packets = []
            for post_packet in post_packets:
                (_, post_frame_time_epoch, _) = post_packet
                latency_ms = time_ns_to_ms(post_frame_time_epoch - pre_frame_time_epoch)
                if MIN_LATENCY_MS <= latency_ms <= MAX_LATENCY_MS:
                    new_packets.append(post_packet)
            return new_packets
        packets = filter_post_packets_by_duplicate_pre_packets(packets)

        number_of_packet_copies = len(packets)
        if number_of_packet_copies < 1:
            dropped_packets += 1
            continue
        duplicate_packets += number_of_packet_copies - 1
        first_arriving_copy_of_packet = None
        for packet in packets:
            if first_arriving_copy_of_packet is None:
                first_arriving_copy_of_packet = packet
                continue
            (_post_frame_number, post_frame_time_epoch, _post_ip_payload_length) = packet
            (_post_frame_number, post_first_frame_time_epoch, _post_ip_payload_length) = first_arriving_copy_of_packet
            if post_frame_time_epoch < post_first_frame_time_epoch:
                first_arriving_copy_of_packet = packet
        (post_frame_number, post_frame_time_epoch, post_ip_payload_length) = first_arriving_copy_of_packet
        latency = time_ns_to_ms(post_frame_time_epoch - pre_frame_time_epoch)
        if latency < min_latency:
          min_latency = latency
        if latency < 0:
            time_traveling_packet_count += 1
        packet_count += 1
        payload_length_sum_with_overhead += pre_ip_payload_length
        payload_length_sum_without_overhead += pre_ip_payload_length - overhead
        latencies.append(latency)
        ip_payload_lengths.append(pre_ip_payload_length)
    throughput_with_overhead = bytes_to_bits(bytes_to_megabytes(payload_length_sum_with_overhead)) / BUCKET_DURATION_S
    throughput_without_overhead = bytes_to_bits(bytes_to_megabytes(payload_length_sum_without_overhead)) / BUCKET_DURATION_S
    statistics = {
        'time': time,
        'counts': {
            'packets': packet_count, # Packets which were sent and then received at least once, not counting duplicates (If two copies arrive, count only one)
            'dropped': dropped_packets, # Packets which were sent but not received
            'duplicate': duplicate_packets, # Packets which were received more than once
        },
        'ip_payload_lengths': ip_payload_lengths,
        'throughput_without_overhead': throughput_without_overhead,
        'latencies': latencies,
    }
    if overhead != 0:
        statistics['throughput_with_overhead'] = throughput_with_overhead
    time_series.append(statistics)

if time_traveling_packet_count > 0:
    print(f'WARNING: {time_traveling_packet_count} packets arrived before they were sent, with one packet arriving {-min_latency:.1f} ms earlier', file=sys.stderr)

data = {
    'duration': BUCKET_DURATION_S,
    'units': {
        'duration': 's',
        'latency': 'ms',
        'ip_payload_length': 'Bytes',
        'throughput': 'Mbit/s',
    },
    'time_series': time_series,
}

if out is not None:
    with open(os.path.join(out, 'parameters.json'), 'w', encoding='utf-8') as f:
        json.dump(obj=metadata, fp=f, allow_nan=False, sort_keys=True, separators=(',', ':'))
    d = open(os.path.join(out, 'statistics.json'), 'w', encoding='utf-8')
else:
    d = open(sys.stdout.fileno(), 'w', encoding='utf-8', closefd=False)

with d as f:
    json.dump(obj=data, fp=f, allow_nan=False, sort_keys=True, separators=(',', ':'))
