# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  hostKeys = ''
    client ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFcqQEPCKzMJOU8SQKUCp5q2eJ7+C5PfsVXsOm5DmWhF
    router ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINzou7ocX7s9qN5Eckoq7W04qOJ/gClrHF5nzqRz0zus
    server ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEMNViz08HZhrVaS0nG1ifpJFG298L/sJlVd3j0GZQSv
    logger ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAJWGdg2xR9N1NFI2Piz+PK8YcPaCdtYF+QUFTtzavR/
  '';
  rootKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBbO4k+Lp04sKW5HzyAIkBG4iFonQ42f7KThK+DG4Ha3 laptop"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICd5XtRXVq56O1GiJPh5g+SSlS+cwzNwSsHe8ybHNUka logger"
  ];
  userKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL280aidPimp3aTHGiLN99bQS8AIv/Dz4+YkfxE8fgsp key"
  ];
}
