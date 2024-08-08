# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: CC0-1.0

$pdf_mode = 4;
@default_files = ('thesis.tex');
$lualatex = "lualatex %O -shell-escape %S";
