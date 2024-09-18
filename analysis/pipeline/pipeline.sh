#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

# This file is only for testing the pipeline without Nix

../parse/parse.py ../../result/lan.pcap > lan.json &
PID_LAN=$!
../parse/parse.py ../../result/wan.pcap > wan.json &
PID_WAN=$!
wait "$PID_LAN" "$PID_WAN"
../statistics/statistics.py lan.json wan.json > statistics.json
../graph/graph.py statistics.json
