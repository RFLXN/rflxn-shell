{
  ags,
  mkRuntimePackages,
}:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) literalExpression mkEnableOption mkIf mkOption types;

  cfg = config.programs.ags-shell;
  layoutFormat = pkgs.formats.json {};
  systemControlMenuFormat = pkgs.formats.json {};
  defaultRuntimePackages = mkRuntimePackages pkgs.system pkgs;
  defaultAgsPackage = ags.packages.${pkgs.system}.default.override {
    extraPackages = cfg.runtimePackages;
  };
  layoutJson = layoutFormat.generate "ags-shell-layout.json" cfg.layout;
  programType = types.nullOr (types.oneOf [
    types.package
    types.str
    types.path
  ]);
  programToCommand = program:
    if program == null
    then null
    else if lib.isDerivation program
    then lib.getExe program
    else toString program;
  systemControlMenuJson = systemControlMenuFormat.generate "ags-shell-system-control-menu.json" {
    volume = {
      program = programToCommand cfg.systemControlMenu.volume.program;
    };
    bluetooth = {
      program = programToCommand cfg.systemControlMenu.bluetooth.program;
    };
  };
  generatedPackage = pkgs.callPackage ./package.nix {
    inherit layoutJson systemControlMenuJson;
  };
  package = if cfg.package == null then generatedPackage else cfg.package;
in
{
  options.programs.ags-shell = {
    enable = mkEnableOption "the AGS Hyprland shell";

    layout = mkOption {
      type = layoutFormat.type;
      default = builtins.fromJSON (builtins.readFile ../layout.json);
      example = literalExpression ''
        {
          layouts = [
            {
              monitor = "DP-3";
              widgets = {
                left = [];
                center = [ "workspaces" ];
                right = [];
              };
              components = [ "app-launcher-menu" ];
            }
          ];
        }
      '';
      description = ''
        Layout JSON rendered to ~/.config/ags/layout.json. Widget and component
        identifiers are interpreted by layout.tsx at runtime.
      '';
    };

    systemControlMenu = {
      volume.program = mkOption {
        type = programType;
        default = null;
        example = literalExpression "pkgs.pwvucontrol";
        description = ''
          Program launched by the volume header button in the system controls
          menu. Package values are converted to their main executable with
          lib.getExe; string values are used as command lines.
        '';
      };

      bluetooth.program = mkOption {
        type = programType;
        default = null;
        example = literalExpression "pkgs.blueman";
        description = ''
          Program launched by the Bluetooth header button in the system controls
          menu. Package values are converted to their main executable with
          lib.getExe; string values are used as command lines.
        '';
      };
    };

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        Prebuilt shell source package to link to ~/.config/ags. When null, the
        module builds this flake's source package with programs.ags-shell.layout
        and programs.ags-shell.systemControlMenu.
      '';
    };

    agsPackage = mkOption {
      type = types.package;
      default = defaultAgsPackage;
      defaultText = literalExpression ''
        inputs.<this-flake>.inputs.ags.packages.''${pkgs.system}.default.override {
          extraPackages = config.programs.ags-shell.runtimePackages;
        }
      '';
      description = "AGS package installed for the user.";
    };

    runtimePackages = mkOption {
      type = types.listOf types.package;
      default = defaultRuntimePackages;
      defaultText = literalExpression "the same Astal/Gtk runtime package set used by this flake's devShell";
      description = "Runtime packages installed for the user alongside AGS.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ package cfg.agsPackage ] ++ cfg.runtimePackages;

    xdg.configFile."ags".source = "${package}/share/ags";
  };
}
