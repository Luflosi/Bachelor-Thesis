# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

# Build a reproducible latex document with latexmk, based on:
# https://flyx.org/nix-flakes-latex/

{ lib
, pkgs
, rfc-bib

# Name of the final pdf file
, name ? "document.pdf"

# Use -shell-escape
, shellEscape ? false

# Use minted (requires shellEscape)
, minted ? false

# Additional flags for latexmk
, extraFlags ? []

# texlive packages needed to build the document
# you can also include other packages as a list.
, texlive ? [ pkgs.texlive.combined.scheme-full ]

# Pygments package to use (needed for minted)
, pygments ? pkgs.python3Packages.pygments

# Add system fonts
# you can specify one font directly with: pkgs.fira-code
# of join multiple fonts using symlinJoin:
#   pkgs.symlinkJoin { name = "fonts"; paths = with pkgs; [ fira-code souce-code-pro ]; }
, fonts ? null

# Date for the document in unix time. You can change it
# to "$(date -r . +%s)" , "$(date -d "2022/02/22" +%s)", toString
# self.lastModified
, SOURCE_DATE_EPOCH
}:

let
  fs = lib.fileset;
  defaultFlags = [
    "-interaction=nonstopmode"
    "-pdf"
    "-lualatex"
    "-pretex='\\pdfvariable suppressoptionalinfo 512\\relax'"
    "-usepretex"
  ];
  flags = lib.concatLists [
    defaultFlags
    extraFlags
    (lib.optional shellEscape "-shell-escape")
  ];
  report-src = fs.toSource {
    root = ./.;
    fileset = fs.unions [
      ./.latexmkrc
      (fs.fileFilter (file: file.hasExt "tex" || file.hasExt "eps" || file.hasExt "sty" || file.hasExt "bib" || file.hasExt "dbx") ./.)
    ];
  };
  rfc-bib-src = pkgs.linkFarm "rfc.bib-src" [{
    name = "rfc.bib";
    path = rfc-bib;
  }];
in

assert minted -> shellEscape;

pkgs.stdenvNoCC.mkDerivation rec {
  inherit name;
  src = pkgs.symlinkJoin {
    name = "combined-report-src";
    paths = [
      report-src
      rfc-bib-src
    ];
  };

  nativeBuildInputs = texlive ++
    lib.optionals minted [ pkgs.which pygments ];

  env.TEXMFHOME = "./cache";
  env.TEXMFVAR = "./cache/var";
  env.OSFONTDIR = lib.optionalString (fonts != null) "${fonts}/share/fonts";
  env.SOURCE_DATE_EPOCH = SOURCE_DATE_EPOCH;
  env.max_print_line = 19999;

  buildPhase = ''
    runHook preBuild

    latexmk ${lib.concatStringsSep " " flags}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -m644 -D 'thesis.pdf' "$out/${name}"

    runHook postInstall
  '';

  strictDeps = true;
  __structuredAttrs = true;
}
