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
                    description='Render the statistical data into a packet count graph')

parser.add_argument('-i', '--input', required=True)
parser.add_argument('-o', '--write-out-path',
                    action='store_true')

args = parser.parse_args()

with open(args.input, 'r', encoding='utf-8') as f:
    data = json.load(f)

duration = data['duration']
duration_unit = data['units']['duration']

first_time = data['time_series'][0]['time']
labels = []
relative_times = []
counts_packets_over_time = []
counts_dropped_over_time = []
counts_duplicate_over_time = []
for data_point in data['time_series']:
    relative_time = data_point['time'] - first_time + 1 # Start counting at 1
    relative_times.append(relative_time)
    labels.append(f'{relative_time:.0f}')
    counts_packets_over_time.append(data_point['counts']['packets'])
    counts_dropped_over_time.append(data_point['counts']['dropped'])
    counts_duplicate_over_time.append(data_point['counts']['duplicate'])

assert sorted(set(labels)) == sorted(labels), f'The labels are not unique: {labels}'

plt.style.use('_mpl-gallery')
plt.rcParams.update({'figure.autolayout': True})


fig, ax = plt.subplots(figsize=figsize)
ax.set_xlabel(f'Time ({duration_unit})')
y = np.vstack([counts_packets_over_time, counts_dropped_over_time])
ax.set_ylabel('Arrived/Dropped')
ax.stackplot(relative_times, y)
ax.set_ylim(bottom=0)
ax2 = ax.twinx() # Instantiate a second Axes that shares the same x-axis
ax2.yaxis.grid(False)
ax2_color = 'red'
ax2.set_ylabel('Duplicated', color=ax2_color)
ax2.plot(relative_times, counts_duplicate_over_time, color=ax2_color)
ax2.tick_params(axis='y', labelcolor=ax2_color)
ax2.set_ylim(bottom=0)

if args.write_out_path:
    out = os.environ['out']
    os.makedirs(out)
    plt.savefig(fname=os.path.join(out, 'packet_counts.svg'), transparent=False)
plt.show()
