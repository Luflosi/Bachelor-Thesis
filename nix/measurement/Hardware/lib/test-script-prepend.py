#!/usr/bin/env python
# -*- coding: utf-8 -*-

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

import os
from pathlib import Path
from test_driver.machine import Machine
from test_driver.logger import (
    CompositeLogger,
    TerminalLogger,
)

out_dir = Path(os.environ['out'])

logger = CompositeLogger([TerminalLogger()])

def start_all():
    print("start_all() called")

client = Machine(out_dir = out_dir, logger = logger, name = "client")
router = Machine(out_dir = out_dir, logger = logger, name = "router")
server = Machine(out_dir = out_dir, logger = logger, name = "server")
logger = Machine(out_dir = out_dir, logger = logger, name = "logger")

# Other code will be copied below
