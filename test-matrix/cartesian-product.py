#!/usr/bin/env python

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

import os
import sys
import json

with open('test-matrix/parameters.json', 'r', encoding='utf-8') as f:
    parameters = json.load(f)

assert isinstance(parameters, dict)
for _parameter_name, parameter_values in parameters.items():
    assert isinstance(parameter_values, list)


tests = []

def test_combinations(parameters):
    result = []
    parameter_name, parameter_values = next(iter(parameters.items()))
    del parameters[parameter_name]
    for parameter_value in parameter_values:
        if (parameters == {}):
            result.append({parameter_name: parameter_value})
        else:
            new_tests = test_combinations(parameters.copy())
            for new_test in new_tests:
                result.append({parameter_name: parameter_value} | new_test)
    return result

tests = test_combinations(parameters)
print(f'Generated {len(tests)} test cases')


with open('test-matrix/tests.json', 'w', encoding='utf-8') as f:
    json.dump(obj=tests, fp=f, allow_nan=False, sort_keys=True, indent=4)
