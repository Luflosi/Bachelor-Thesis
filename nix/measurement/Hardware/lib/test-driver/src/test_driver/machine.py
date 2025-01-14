#!/usr/bin/env python
# -*- coding: utf-8 -*-

# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

import os
import re
import subprocess
import time
from collections.abc import Callable, Iterable
from contextlib import _GeneratorContextManager
from pathlib import Path
from typing import Any

from test_driver.logger import AbstractLogger

ssh_bin = "@ssh_bin@"
ssh_config = "@ssh_config@"
rsync_bin = "@rsync_bin@"

def make_command(args: list) -> str:
    return " ".join(map(shlex.quote, (map(str, args))))

def retry(fn: Callable, timeout: int = 900) -> None:
    """Call the given function repeatedly, with 1 second intervals,
    until it returns True or a timeout is reached.
    """

    for _ in range(timeout):
        if fn(False):
            return
        time.sleep(1)

    if not fn(True):
        raise Exception(f"action timed out after {timeout} seconds")

class Machine:
    name: str
    out_dir: Path
    logger: AbstractLogger # TODO: upstream this line to Nixpkgs?

    def __init__(
        self,
        out_dir: Path,
        logger: AbstractLogger,
        name: str,
    ) -> None:
        self.out_dir = out_dir
        self.logger = logger
        self.name = name
        self.succeed("echo 'Hello world!'")

    def log(self, msg: str) -> None:
        self.logger.log(msg, {"machine": self.name})

    def nested(self, msg: str, attrs: dict[str, str] = {}) -> _GeneratorContextManager:
        my_attrs = {"machine": self.name}
        my_attrs.update(attrs)
        return self.logger.nested(msg, my_attrs)

    def wait_for_unit(
        self, unit: str, user: str | None = None, timeout: int = 900
    ) -> None:
        """
        Wait for a systemd unit to get into "active" state.
        Throws exceptions on "failed" and "inactive" states as well as after
        timing out.
        """

        def check_active(_: Any) -> bool:
            state = self.get_unit_property(unit, "ActiveState", user)
            if state == "failed":
                raise Exception(f'unit "{unit}" reached state "{state}"')

            if state == "inactive":
                status, jobs = self.systemctl("list-jobs --full 2>&1", user)
                if "No jobs" in jobs:
                    info = self.get_unit_info(unit, user)
                    if info["ActiveState"] == state:
                        raise Exception(
                            f'unit "{unit}" is inactive and there are no pending jobs'
                        )

            return state == "active"

        with self.nested(
            f"waiting for unit {unit}"
            + (f" with user {user}" if user is not None else "")
        ):
            retry(check_active, timeout)

    def get_unit_property(
        self,
        unit: str,
        property: str,
        user: str | None = None,
    ) -> str:
        status, lines = self.systemctl(
            f'--no-pager show "{unit}" --property="{property}"',
            user,
        )
        if status != 0:
            raise Exception(
                f'retrieving systemctl property "{property}" for unit "{unit}"'
                + ("" if user is None else f' under user "{user}"')
                + f" failed with exit code {status}"
            )

        invalid_output_message = (
            f'systemctl show --property "{property}" "{unit}"'
            f"produced invalid output: {lines}"
        )

        line_pattern = re.compile(r"^([^=]+)=(.*)$")
        match = line_pattern.match(lines)
        assert match is not None, invalid_output_message

        assert match[1] == property, invalid_output_message
        return match[2]

    def systemctl(self, q: str, user: str | None = None) -> tuple[int, str]:
        """
        Runs `systemctl` commands with optional support for
        `systemctl --user`

        ```py
        # run `systemctl list-jobs --no-pager`
        machine.systemctl("list-jobs --no-pager")

        # spawn a shell for `any-user` and run
        # `systemctl --user list-jobs --no-pager`
        machine.systemctl("list-jobs --no-pager", "any-user")
        ```
        """
        if user is not None:
            q = q.replace("'", "\\'")
            return self.execute(
                f"su -l {user} --shell /bin/sh -c "
                "$'XDG_RUNTIME_DIR=/run/user/`id -u` "
                f"systemctl --user {q}'"
            )
        return self.execute(f"systemctl {q}")

    def execute(
        self,
        command: str,
        check_return: bool = True,
        check_output: bool = True,
        timeout: int | None = 900,
    ) -> tuple[int, str]:
        """
        Execute a shell command, returning a list `(status, stdout)`.

        Commands are run with `set -euo pipefail` set:

        -   If several commands are separated by `;` and one fails, the
            command as a whole will fail.

        -   For pipelines, the last non-zero exit status will be returned
            (if there is one; otherwise zero will be returned).

        -   Dereferencing unset variables fails the command.

        -   It will wait for stdout to be closed.

        Takes an optional parameter `check_return` that defaults to `True`.
        Setting this parameter to `False` will not check for the return code
        and return -1 instead. This can be used for commands that shut down
        the VM and would therefore break the pipe that would be used for
        retrieving the return code.

        A timeout for the command can be specified (in seconds) using the optional
        `timeout` parameter, e.g., `execute(cmd, timeout=10)` or
        `execute(cmd, timeout=None)`. The default is 900 seconds.
        """

        # Always run command with shell opts
        command = f"set -euo pipefail; {command}"

        res = subprocess.run([ssh_bin, "-F", ssh_config, f"root@{self.name}", command], capture_output=True, timeout=timeout)

        if res.stderr != b"":
            print(res.stderr.decode("utf-8"))

        if not check_output:
            return (-2, "")

        # Get the output
        output = res.stdout

        if not check_return:
            return (-1, output.decode("utf-8"))

        # Get the return code
        rc = res.returncode

        return (rc, output.decode("utf-8", errors="replace"))

    def succeed(self, *commands: str, timeout: int | None = None) -> str:
        """
        Execute a shell command, raising an exception if the exit status is
        not zero, otherwise returning the standard output. Similar to `execute`,
        except that the timeout is `None` by default. See `execute` for details on
        command execution.
        """
        output = ""
        for command in commands:
            with self.nested(f"must succeed: {command}"):
                (status, out) = self.execute(command, timeout=timeout)
                if status != 0:
                    self.log(f"output: {out}")
                    raise Exception(f"command `{command}` failed (exit code {status})")
                output += out
        return output

    def wait_until_succeeds(self, command: str, timeout: int = 900) -> str:
        """
        Repeat a shell command with 1-second intervals until it succeeds.
        Has a default timeout of 900 seconds which can be modified, e.g.
        `wait_until_succeeds(cmd, timeout=10)`. See `execute` for details on
        command execution.
        Throws an exception on timeout.
        """
        output = ""

        def check_success(_: Any) -> bool:
            nonlocal output
            status, output = self.execute(command, timeout=timeout)
            return status == 0

        with self.nested(f"waiting for success: {command}"):
            retry(check_success, timeout)
            return output

    def copy_from_vm(self, source: str, target_dir: str = "") -> None:
        """Copy a file from the VM (specified by an in-VM source path) to a path
        relative to `$out`. The file is copied via rsync.
        """
        vm_src = Path(source)
        abs_target = self.out_dir / target_dir / vm_src.name
        abs_target.parent.mkdir(exist_ok=True, parents=True)
        with self.nested(f"copying file"):
            subprocess.run([rsync_bin, "-a", "-e", f"{ssh_bin} -F {ssh_config}", f"root@{self.name}:{source}", abs_target], check=True)
