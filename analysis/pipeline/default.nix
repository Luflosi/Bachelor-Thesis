# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  callPackage,
  measurementDrivers,
  allParameters,
  protocols,
}:

assert builtins.isList allParameters;

let
  parameterToStatistic = parameters:
    assert builtins.elem parameters.platform [ "VM" "PC" ];
  let
    result = rec {
      measurement = if parameters.platform == "VM"
        then callPackage ../../nix/measurement/VM/run.nix { inherit parameters; measurementDriver = measurementDrivers.${parameters.encapsulation}; }
        else callPackage ../../nix/measurement/Hardware/run.nix { inherit parameters; };
      parse = fileName: removeEnds: callPackage ../parse { inherit fileName removeEnds; packets = measurement; };
      parsed-pre = parse "pre" true;
      parsed-post = parse "post" false;
      statistic = callPackage ../statistics { pre = parsed-pre; post = parsed-post; overhead = protocols.${parameters.encapsulation}; };
    };
  in builtins.removeAttrs result [ "parse" ];
  intermediates = builtins.map parameterToStatistic allParameters;
  statistics = builtins.map (intermediate: intermediate.statistic) intermediates;
  graphs = callPackage ../graph { inherit statistics; };
in {
  inherit graphs intermediates;
}
