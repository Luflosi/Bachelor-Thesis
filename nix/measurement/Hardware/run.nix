# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  callPackage,
  lib,
  openssh,
  parameters ? {},
  python3,
  replaceVars,
  rsync,
  stdenvNoCC,
  testers,
  writeTextFile,
}:
let
  py_env = python3.withPackages (
    p: with p; [
      colorama
      junit-xml
    ]
  );

  # The Nix setting auto-allocate-uids needs to be set to false,
  # otherwise the build user won't exist in /etc/passwd, which causes SSH to fail because of this code:
  # https://github.com/openssh/openssh-portable/blob/826483d51a9fee60703298bbf839d9ce37943474/ssh.c#L709-L714
  runDriver = testScriptDir: stdenvNoCC.mkDerivation {
    name = "hardware-test-run";
    __noChroot = true; # Disable the sandbox to allow SSHing into the machines
    strictDeps = true;

    # How to create a readable key:
    # sudo mkdir -p /persist/thesis-ssh/
    # sudo chmod o-rwx /persist/thesis-ssh/
    # sudo ssh-keygen -f /persist/thesis-ssh/key
    # sudo chgrp -R nixbld /persist/thesis-ssh/
    # sudo chmod g+r /persist/thesis-ssh/key

    # TODO: verify that the hosts are running the exact configuration of this repository?
    buildCommand = ''
      id
      ls -l /persist/
      ls -l /persist/thesis-ssh/

      mkdir -p "$out"
      cd '${testScriptDir}'
      '${lib.getExe py_env}' -m complete_test_script -o "$out"
    '';
  };
  complete-test-script-dir = stdenvNoCC.mkDerivation {
    name = "complete-test-script";
    strictDeps = true;
    buildCommand = let
      known_hosts = writeTextFile {
        name = "known_hosts";
        text = (import ../../constants/ssh.nix).hostKeys;
      };
      ssh_config = writeTextFile {
        name = "ssh_config";
        text = ''
          IdentityFile /persist/thesis-ssh/key
          IdentitiesOnly yes
          CheckHostIP no
          ChallengeResponseAuthentication no
          HostKeyAlgorithms ssh-ed25519
          PreferredAuthentications publickey
          PubkeyAuthentication yes
          UserKnownHostsFile ${known_hosts}
          ControlPath /persist/thesis-ssh/master-%r@%n:%p
          ControlPersist 30
        '';
      };
      machine-py = replaceVars ./lib/test-driver/src/test_driver/machine.py {
        ssh_bin = lib.getExe openssh;
        inherit ssh_config;
        rsync_bin = lib.getExe rsync;
      };
    in ''
      mkdir -p "$out"
      cat '${./lib/test-script-prepend.py}' '${test-script}' > "$out/complete_test_script.py"
      mkdir -p "$out/test_driver/"
      ln -s '${machine-py}' "$out/test_driver/machine.py"
      ln -s '${./lib/test-driver/src/test_driver/logger.py}' "$out/test_driver/logger.py"
    '';
  };
  test-script = callPackage (import ../create-test-script.nix parameters) { };
  measurement = runDriver complete-test-script-dir;
in
  measurement
