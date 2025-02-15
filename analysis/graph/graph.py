#!/usr/bin/env python
# -*- coding: utf-8 -*-

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

import os
import json
import argparse
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as mtick

figsize = (16, 8)


parser = argparse.ArgumentParser(
                    prog='graph',
                    description='Render the statistical data into graphs')

parser.add_argument('-i', '--inputs', required=True, nargs='+')
parser.add_argument('-o', '--write-out-path',
                    action='store_true')

args = parser.parse_args()

nr_of_measurements = len(args.inputs)
if nr_of_measurements == 1:
    # Only a single measurement
    mode = 'single'
elif nr_of_measurements > 1:
    # Render multiple measurements per graph
    mode = 'multi'
else:
    raise Exception("No inputs")


def read_input(input_file):
    with open(os.path.join(input_file, 'statistics.json'), 'r', encoding='utf-8') as f:
        input = json.load(f)
    with open(os.path.join(input_file, 'parameters.json'), 'r', encoding='utf-8') as f:
        parameters = json.load(f)

    metadata = {
        'duration': input['duration'],
        'units': {
            'latency': input['units']['latency'],
            'duration': input['units']['duration'],
            'throughput': input['units']['throughput'],
        },
    }
    data = {
        'time': [],
        'labels': [],
        'latencies': [],
        'counts': {
            'packets': [],
            'dropped': [],
            'duplicate': [],
        },
        'throughput': {
            'without_overhead': [],
            'with_overhead': [],
        },
    }
    first_time = input['time_series'][0]['time']
    for data_point in input['time_series']:
        relative_time = data_point['time'] - first_time + 1 # Start counting at 1
        data['time'].append(relative_time)
        data['labels'].append(f'{relative_time:.0f}')
        data['latencies'].append(data_point['latencies'])
        data['counts']['packets'].append(data_point['counts']['packets'])
        data['counts']['dropped'].append(data_point['counts']['dropped'])
        data['counts']['duplicate'].append(data_point['counts']['duplicate'])
        data['throughput']['without_overhead'].append(data_point['throughput_without_overhead'])
        if 'throughput_with_overhead' in data_point:
            data['throughput']['with_overhead'].append(data_point['throughput_with_overhead'])

    assert sorted(set(data['labels'])) == sorted(data['labels']), f'The labels are not unique: {data['labels']}'
    assert data['throughput']['with_overhead'] == [] or len(data['throughput']['with_overhead']) == len(data['throughput']['without_overhead']), 'The two throughputs have inconsistent lengths'

    return metadata, data, parameters


def read_inputs(inputs):
    data_list = []
    metadata = None
    prev_parameters = None
    differing_parameters = set()
    parameters_per_input = []
    duration = None
    unit_latency = None
    unit_duration = None
    unit_throughput = None
    time = None
    labels = None
    latencies = []
    dropped_ratio = []
    duplicate_ratio = []
    throughput_over_time_with_overhead = []
    throughput_over_time_without_overhead = []

    for input_file in inputs:
        metadata, data, parameters = read_input(input_file)

        if prev_parameters != None:
            assert parameters.keys() == prev_parameters.keys(), f'{parameters.keys()} != {prev_parameters.keys()}'
            for key, value in parameters.items():
                if key == 'cacheID':
                    continue
                if value != prev_parameters[key]:
                    differing_parameters.add(key)
        prev_parameters = parameters
        parameters_per_input.append(parameters)

        if duration == None:
            duration = metadata['duration']
        assert duration == metadata['duration'], f'{duration} != {metadata['duration']}'
        if unit_latency == None:
            unit_latency = metadata['units']['latency']
        assert unit_latency == metadata['units']['latency'], f'{unit_latency} != {metadata['units']['latency']}'
        if unit_duration == None:
            unit_duration = metadata['units']['duration']
        assert unit_duration == metadata['units']['duration'], f'{unit_duration} != {metadata['units']['duration']}'
        if unit_throughput == None:
            unit_throughput = metadata['units']['throughput']
        assert unit_throughput == metadata['units']['throughput'], f'{unit_throughput} != {metadata['units']['throughput']}'
        if time == None:
            time = data['time']
        assert time == data['time'], f'{time} != {data['time']}'
        if labels == None:
            labels = data['labels']
        assert labels == data['labels'], f'{labels} != {data['labels']}'
        match mode:
            case 'single':
                # Grouped into seconds
                latencies = data['latencies']
                counts_packets = data['counts']['packets']
                counts_dropped = data['counts']['dropped']
                counts_duplicate = data['counts']['duplicate']
                throughput_over_time_with_overhead = data['throughput']['with_overhead']
                throughput_over_time_without_overhead = data['throughput']['without_overhead']
            case 'multi':
                # Grouped by measurement runs
                latencies_from_single_measurement = []
                for latencies_per_second in data['latencies']:
                    latencies_from_single_measurement += latencies_per_second
                latencies.append(latencies_from_single_measurement)
                del(latencies_from_single_measurement)
                dropped_ratio_from_single_measurement = []
                duplicate_ratio_from_single_measurement = []
                for count, dropped, duplicate in zip(data['counts']['packets'], data['counts']['dropped'], data['counts']['duplicate']):
                    dropped_ratio_from_single_measurement.append(dropped / count)
                    duplicate_ratio_from_single_measurement.append(duplicate / count)
                dropped_ratio.append(dropped_ratio_from_single_measurement)
                duplicate_ratio.append(duplicate_ratio_from_single_measurement)
                del(dropped_ratio_from_single_measurement)
                without_overhead = data['throughput']['without_overhead']
                throughput_over_time_without_overhead.append(without_overhead)
                with_overhead = data['throughput']['with_overhead']
                if with_overhead != []:
                    throughput_over_time_with_overhead.append(with_overhead)
                else:
                    throughput_over_time_with_overhead.append(without_overhead)
            case _:
                raise Exception("Invalid mode")

    plot = {
        'latencies': {},
    }

    match mode:
        case 'single':
            plot['x'] = time
            plot['x_labels'] = labels
        case 'multi':
            plot['x'] = [x for x in range(nr_of_measurements)]
            if len(differing_parameters) != 1:
                print(f'WARNING: Multiple parameters are different between graphs: {differing_parameters}', file=sys.stderr)
                plot['x_labels'] = [f'{x:.0f}' for x in range(nr_of_measurements)]
            else:
                (differing_parameter,) = differing_parameters
                plot['x_labels'] = [parameters[differing_parameter] for parameters in parameters_per_input]

                def parameter_name_to_human_readable(parameter):
                    match parameter:
                        case 'platform':
                            return 'Platform'
                        case 'test_duration_s':
                            return 'Test duration (s)'
                        case 'ip_payload_size':
                            return 'IP payload size (Bytes)'
                        case 'encapsulation':
                            return 'Encapsulation'
                        case 'delay_time_ms':
                            return 'Delay time (ms)'
                        case 'delay_jitter_ms':
                            return 'Delay jitter (ms)'
                        case 'delay_distribution':
                            return 'Delay distribution'
                        case 'loss_per_mille':
                            return 'Loss (‰)'
                        case 'loss_correlation':
                            return 'Loss correlation'
                        case 'duplicate_per_mille':
                            return 'Duplicate (‰)'
                        case 'duplicate_correlation':
                            return 'Duplicate correlation'
                        case 'reorder_per_mille':
                            return 'Reorder (‰)'
                        case _:
                            raise Exception("Invalid parameter name")

                plot['x_label'] = parameter_name_to_human_readable(differing_parameter)
        case _:
            raise Exception("Invalid mode")

    plot['latencies']['y'] = latencies

    match mode:
        case 'single':
            plot['counts'] = {
                'y1': np.vstack([counts_packets, counts_dropped]),
                'y2': counts_duplicate,
            }
        case 'multi':
            plot['dropped_ratio'] = {
                'y': dropped_ratio,
            }
            plot['duplicate_ratio'] = {
                'y': duplicate_ratio,
            }
        case _:
            raise Exception("Invalid mode")

    match mode:
        case 'single':
            plot['throughput'] = {}
            plot['throughput']['y_full'] = throughput_over_time_without_overhead
            plot['throughput']['y_dotted'] = throughput_over_time_with_overhead
        case 'multi':
            plot['throughput_without'] = {}
            plot['throughput_with'] = {}
            plot['throughput_without']['y'] = throughput_over_time_without_overhead
            if throughput_over_time_with_overhead != throughput_over_time_without_overhead:
                plot['throughput_with']['y'] = throughput_over_time_with_overhead
        case _:
            raise Exception("Invalid mode")

    assert metadata != None
    return metadata, plot


metadata, plot = read_inputs(args.inputs)


out = None
if args.write_out_path:
    with open('.attrs.json', 'r', encoding='utf-8') as f:
        out = json.load(f)['outputs']['out']
    os.makedirs(out)

plt.style.use('_mpl-gallery')
plt.rcParams.update({'figure.autolayout': True})


fig, ax = plt.subplots(figsize=figsize)
ax.set_ylabel(f'Latency ({metadata['units']['latency']})')
match mode:
    case 'single':
        ax.set_xlabel(f'Time ({metadata['units']['duration']})')
        ax.boxplot(plot['latencies']['y'], positions=plot['x'], patch_artist=True,
                   showmeans=False, showfliers=True,
                   medianprops={"color": "white", "linewidth": 0.5},
                   boxprops={"facecolor": "C0", "edgecolor": "white",
                             "linewidth": 0.5},
                   whiskerprops={"color": "C0", "linewidth": 1.5},
                   capprops={"color": "C0", "linewidth": 1.5})
        ax.set_xticks(plot['x'], labels=plot['x_labels'])
    case 'multi':
        ax.set_xlabel(plot['x_label'])
        ax.violinplot(plot['latencies']['y'], positions=plot['x'],
                      showextrema = True, showmedians = True, widths=1)
        ax.set_xticks(plot['x'], labels=plot['x_labels'])
    case _:
        raise Exception("Invalid mode")
ax.set_ylim(bottom=0)
if out != None:
    plt.savefig(fname=os.path.join(out, 'latencies.svg'), transparent=False)
plt.show()


match mode:
    case 'single':
        fig, ax = plt.subplots(figsize=figsize)
        ax.set_xlabel(f'Time ({metadata['units']['duration']})')
        ax.set_ylabel('Arrived/Dropped')
        ax.stackplot(plot['x'], plot['counts']['y1'])
        ax.set_ylim(bottom=0)
        ax2 = ax.twinx() # Instantiate a second Axes that shares the same x-axis
        ax2.yaxis.grid(False)
        ax2_color = 'red'
        ax2.set_ylabel('Duplicated', color=ax2_color)
        ax2.plot(plot['x'], plot['counts']['y2'], color=ax2_color)
        ax2.tick_params(axis='y', labelcolor=ax2_color)
        ax2.set_ylim(bottom=0)
        if out != None:
            plt.savefig(fname=os.path.join(out, 'packet_counts_all.svg'), transparent=False)
        plt.show()
    case 'multi':
        fig, ax = plt.subplots(figsize=figsize)
        ax.set_xlabel(plot['x_label'])
        ax.set_ylabel('Dropped')
        ax.violinplot(plot['dropped_ratio']['y'], positions=plot['x'],
                      showextrema = True, showmedians = True, widths=1)
        ax.set_xticks(plot['x'], labels=plot['x_labels'])
        ax.set_ylim(bottom=0)
        ax.yaxis.set_major_formatter(mtick.PercentFormatter(xmax=1.0, decimals=1))
        if out != None:
            plt.savefig(fname=os.path.join(out, 'packet_dropped.svg'), transparent=False)
        plt.show()

        fig, ax = plt.subplots(figsize=figsize)
        ax.set_xlabel(plot['x_label'])
        ax.set_ylabel('Duplicated')
        ax.violinplot(plot['duplicate_ratio']['y'], positions=plot['x'],
                      showextrema = True, showmedians = True, widths=1)
        ax.set_xticks(plot['x'], labels=plot['x_labels'])
        ax.set_ylim(bottom=0)
        ax.yaxis.set_major_formatter(mtick.PercentFormatter(xmax=1.0, decimals=1))
        if out != None:
            plt.savefig(fname=os.path.join(out, 'packet_duplicate.svg'), transparent=False)
        plt.show()
    case _:
        raise Exception("Invalid mode")


match mode:
    case 'single':
        fig, ax = plt.subplots(figsize=figsize)
        ax.set_ylabel(f'Throughput ({metadata['units']['throughput']})')
        ax.set_xlabel(f'Time ({metadata['units']['duration']})')
        if plot['throughput']['y_dotted'] != []:
            ax.plot(plot['x'], plot['throughput']['y_dotted'], dashes=[1, 3], dash_capstyle = 'round')
        ax.plot(plot['x'], plot['throughput']['y_full'])
        ax.set_ylim(bottom=0)

        if out != None:
            plt.savefig(fname=os.path.join(out, 'throughput.svg'), transparent=False)
        plt.show()
    case 'multi':
        fig, ax = plt.subplots(figsize=figsize)
        ax.set_ylabel(f'Throughput without overhead ({metadata['units']['throughput']})')
        ax.set_xlabel(plot['x_label'])
        ax.violinplot(plot['throughput_without']['y'], positions=plot['x'],
                      showextrema = True, showmedians = True, widths=1)
        ax.set_xticks(plot['x'], labels=plot['x_labels'])
        ax.set_ylim(bottom=0)

        if out != None:
            if plot['throughput_with'] != {}:
                filename = 'throughput_without.svg'
            else:
                filename = 'throughput.svg'
            plt.savefig(fname=os.path.join(out, filename), transparent=False)
        plt.show()

        if plot['throughput_with'] != {}:
            fig, ax = plt.subplots(figsize=figsize)
            ax.set_ylabel(f'Throughput with overhead ({metadata['units']['throughput']})')
            ax.set_xlabel(plot['x_label'])
            ax.violinplot(plot['throughput_with']['y'], positions=plot['x'],
                          showextrema = True, showmedians = True, widths=1)
            ax.set_xticks(plot['x'], labels=plot['x_labels'])
            ax.set_ylim(bottom=0)

            if out != None:
                plt.savefig(fname=os.path.join(out, 'throughput_with.svg'), transparent=False)
            plt.show()
    case _:
        raise Exception("Invalid mode")
