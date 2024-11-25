#!/usr/bin/env python
# -*- coding: utf-8 -*-

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

import os
import json
import argparse
import numpy as np
import matplotlib.pyplot as plt

figsize = (16, 8)


parser = argparse.ArgumentParser(
                    prog='graph',
                    description='Render the statistical data into a throughput graph')

parser.add_argument('-i', '--inputs', required=True, nargs='+')
parser.add_argument('-o', '--write-out-path',
                    action='store_true')

args = parser.parse_args()


def calc_throughput(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    duration = data['duration']
    duration_unit = data['units']['duration']
    throughput_unit = data['units']['throughput']

    first_time = data['time_series'][0]['time']
    labels = []
    relative_times = []
    throughput_over_time = []
    for data_point in data['time_series']:
        relative_time = data_point['time'] - first_time + 1 # Start counting at 1
        relative_times.append(relative_time)
        labels.append(f'{relative_time:.0f}')
        throughput_over_time.append(data_point['throughput'])

    assert sorted(set(labels)) == sorted(labels), f'The labels are not unique: {labels}'

    return relative_times, labels, throughput_over_time, duration_unit, throughput_unit


labels = None
data = []
duration_unit = None
throughput_unit = None
for input in args.inputs:
    relative_times, new_labels, throughput_over_time, new_duration_unit, new_throughput_unit = calc_throughput(input)
    data.append((relative_times, throughput_over_time))
    if labels == None:
        labels = new_labels
    assert labels == new_labels, f'{labels} != {new_labels}'
    if duration_unit == None:
        duration_unit = new_duration_unit
    assert duration_unit == new_duration_unit, f'{duration_unit} != {new_duration_unit}'
    if throughput_unit == None:
        throughput_unit = new_throughput_unit
    assert throughput_unit == new_throughput_unit, f'{throughput_unit} != {new_throughput_unit}'


plt.style.use('_mpl-gallery')
plt.rcParams.update({'figure.autolayout': True})


fig, ax = plt.subplots(figsize=figsize)
ax.set_xlabel(f'Time ({duration_unit})')
ax.set_ylabel(f'Throughput ({throughput_unit})')
for relative_times, throughput_over_time in data:
    ax.plot(relative_times, throughput_over_time)
ax.set_ylim(bottom=0)

if args.write_out_path:
    out = os.environ['out']
    os.makedirs(out)
    plt.savefig(fname=os.path.join(out, 'throughput.svg'), transparent=False)
plt.show()
