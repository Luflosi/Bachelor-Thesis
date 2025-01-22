# SPDX-FileCopyrightText: 2024 Lukas Zirpel <thesis+lukas@zirpel.de>
# SPDX-License-Identifier: GPL-3.0-only

{
  callPackage,
  measurementDrivers,
  allParameters,
  protocols,
  settings,
}:

assert builtins.isList allParameters;
assert builtins.elem settings.mode [ "VM" "Hardware" ];

let
  parameterToStatistic = parameters: let
    result = rec {
      measurement = if settings.mode == "VM"
        then callPackage ../../nix/measurement/VM/run.nix { inherit parameters settings; measurementDriver = measurementDrivers.${parameters.encapsulation}; }
        else callPackage ../../nix/measurement/Hardware/run.nix { inherit parameters settings; };
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
