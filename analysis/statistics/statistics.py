#!/usr/bin/env python

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

parser.add_argument('-l', '--lan', required=True)
parser.add_argument('-w', '--wan', required=True)
parser.add_argument('-o', '--write-out-path',
                    action='store_true')

args = parser.parse_args()

lan_packets = read_json_file(args.lan)
wan_packets = read_json_file(args.wan)
out = None
if args.write_out_path:
    out = os.environ['out']
    os.makedirs(out)

lan_hash_to_frames_map = defaultdict(list)
for packet in lan_packets:
    frame_number = packet['frame_number']
    frame_time_epoch = packet['frame_time_epoch']
    hash = bytes.fromhex(packet['hash'])
    assert len(hash) == 32, f'Hash length was {len(hash)}'
    ip_payload_length = packet['ip_payload_length']
    assert ip_payload_length > 0, f'ip_payload_length is not greater than zero ({ip_payload_length})'
    lan_hash_to_frames_map[hash].append((frame_number, frame_time_epoch, ip_payload_length))
    del(hash, frame_number, frame_time_epoch, ip_payload_length)


def validate_wan_packets(wan_packets):
    frames = []
    hash_to_frame_set = set()
    previous_frame_number = None
    previous_frame_time_epoch = None
    for packet in wan_packets:
        frame_number = packet['frame_number']
        frame_time_epoch = packet['frame_time_epoch']
        hash = bytes.fromhex(packet['hash'])
        assert hash not in hash_to_frame_set, f'hash {hash} is not unique'
        assert len(hash) == 32, f'Hash length was {len(hash)}'
        assert previous_frame_number == None or frame_number > previous_frame_number, f'frame_number ({frame_number}) is not greater than the previous one ({previous_frame_number})'
        assert previous_frame_time_epoch == None or frame_time_epoch > previous_frame_time_epoch, f'frame_time_epoch ({frame_time_epoch}) is not greater than the previous one ({previous_frame_time_epoch})'
        ip_payload_length = packet['ip_payload_length']
        assert ip_payload_length > 0, f'ip_payload_length is not greater than zero ({ip_payload_length})'
        previous_frame_number = frame_number
        previous_frame_time_epoch = frame_time_epoch
        hash_to_frame_set.add(hash)
        frame = (hash, frame_number, frame_time_epoch, ip_payload_length)
        frames.append(frame)
    return frames


def split_into_buckets(wan_info):
    buckets = {}
    bucket = []
    bucket_start_time = None
    bucket_end_time = None
    for frame in wan_info:
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


wan_info = validate_wan_packets(wan_packets)
del(wan_packets)

wan_buckets = split_into_buckets(wan_info)
del(wan_info)


time_series = []

for time, wan_bucket in wan_buckets.items():
    packet_count = 0
    dropped_packets = 0
    duplicate_packets = 0
    latencies = []
    ip_payload_length_sum = 0
    for (wan_hash, wan_frame_number, wan_frame_time_epoch, wan_ip_payload_length) in wan_bucket:
        packets = lan_hash_to_frames_map[wan_hash]
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
            (_lan_frame_number, lan_first_frame_time_epoch, _lan_ip_payload_length) = first_arriving_copy_of_packet
            if lan_frame_time_epoch < lan_first_frame_time_epoch:
                first_arriving_copy_of_packet = packet
        (lan_frame_number, lan_frame_time_epoch, lan_ip_payload_length) = first_arriving_copy_of_packet
        latency = time_ns_to_ms(lan_frame_time_epoch - wan_frame_time_epoch)
        if latency < 0:
            print(f'WARNING: packet arrived {-latency} ms before it was sent', file=sys.stderr)
        packet_count += 1
        ip_payload_length_sum += wan_ip_payload_length
        latencies.append(latency)
    throughput = bytes_to_bits(bytes_to_megabytes(ip_payload_length_sum)) / BUCKET_DURATION_S
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
