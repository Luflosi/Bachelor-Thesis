#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

# This file is only for testing the pipeline without Nix

# TODO: make work with split graph program

../parse/parse.py ../../result/pre.pcap > pre.json &
PID_PRE=$!
../parse/parse.py ../../result/post.pcap > post.json &
PID_POST=$!
wait "$PID_PRE" "$PID_POST"
../statistics/statistics.py pre.json post.json > statistics.json
../graph/graph.py statistics.json
