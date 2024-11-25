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
                    description='Render the statistical data into a latency graph')

parser.add_argument('-i', '--input', required=True)
parser.add_argument('-o', '--write-out-path',
                    action='store_true')

args = parser.parse_args()

with open(args.input, 'r', encoding='utf-8') as f:
    data = json.load(f)

duration = data['duration']
duration_unit = data['units']['duration']
latency_unit = data['units']['latency']

first_time = data['time_series'][0]['time']
labels = []
relative_times = []
latencies_over_time = []
for data_point in data['time_series']:
    relative_time = data_point['time'] - first_time + 1 # Start counting at 1
    relative_times.append(relative_time)
    labels.append(f'{relative_time:.0f}')
    latencies_over_time.append(data_point['latencies'])

assert sorted(set(labels)) == sorted(labels), f'The labels are not unique: {labels}'

plt.style.use('_mpl-gallery')
plt.rcParams.update({'figure.autolayout': True})


fig, ax = plt.subplots(figsize=figsize)
ax.set_xlabel(f'Time ({duration_unit})')
ax.set_ylabel(f'Latency ({latency_unit})')
#plt.setp(ax.get_xticklabels(), rotation=30, horizontalalignment='right')
# ax.violinplot(latencies_over_time, positions=relative_times,
#               showextrema = True, showmedians = True, widths=1)
ax.boxplot(latencies_over_time, positions=relative_times, patch_artist=True,
           showmeans=False, showfliers=True,
           medianprops={"color": "white", "linewidth": 0.5},
           boxprops={"facecolor": "C0", "edgecolor": "white",
                     "linewidth": 0.5},
           whiskerprops={"color": "C0", "linewidth": 1.5},
           capprops={"color": "C0", "linewidth": 1.5})
ax.set_ylim(bottom=0)

ax.set_xticks(relative_times, labels=labels)

if args.write_out_path:
    out = os.environ['out']
    os.makedirs(out)
    plt.savefig(fname=os.path.join(out, 'latencies.svg'), transparent=False)
plt.show()
