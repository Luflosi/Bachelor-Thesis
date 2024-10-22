#!/usr/bin/env python

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
                    description='Render the statistical data into graphs')

parser.add_argument('-i', '--input', required=True)
parser.add_argument('-o', '--write-out-path',
                    action='store_true')

args = parser.parse_args()

with open(args.input, 'r', encoding='utf-8') as f:
    data = json.load(f)

out = None
if args.write_out_path:
    out = os.environ['out']
    os.makedirs(out)


duration = data['duration']
duration_unit = data['units']['duration']
latency_unit = data['units']['latency']
throughput_unit = data['units']['throughput']

first_time = data['time_series'][0]['time']
labels = []
relative_times = []
counts_packets_over_time = []
counts_dropped_over_time = []
counts_duplicate_over_time = []
throughput_over_time = []
latencies_over_time = []
for data_point in data['time_series']:
    relative_time = data_point['time'] - first_time
    relative_times.append(relative_time)
    labels.append(f'{relative_time:.0f}')
    counts_packets_over_time.append(data_point['counts']['packets'])
    counts_dropped_over_time.append(data_point['counts']['dropped'])
    counts_duplicate_over_time.append(data_point['counts']['duplicate'])
    throughput_over_time.append(data_point['throughput'])
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

if out != None:
    plt.savefig(fname=os.path.join(out, 'latencies.png'), transparent=False)
plt.show()


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

if out != None:
    plt.savefig(fname=os.path.join(out, 'packet_counts.png'), transparent=False)
plt.show()


fig, ax = plt.subplots(figsize=figsize)
ax.set_xlabel(f'Time ({duration_unit})')
ax.set_ylabel(f'Thriughput ({throughput_unit})')
ax.plot(relative_times, throughput_over_time)
ax.set_ylim(bottom=0)

if out != None:
    plt.savefig(fname=os.path.join(out, 'throughput.png'), transparent=False)
plt.show()
