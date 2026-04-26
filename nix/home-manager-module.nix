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
  defaultRuntimePackages = mkRuntimePackages pkgs.system pkgs;
  defaultAgsPackage = ags.packages.${pkgs.system}.default.override {
    extraPackages = cfg.runtimePackages;
  };
  layoutJson = layoutFormat.generate "ags-shell-layout.json" cfg.layout;
  generatedPackage = pkgs.callPackage ./package.nix {
    inherit layoutJson;
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

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        Prebuilt shell source package to link to ~/.config/ags. When null, the
        module builds this flake's source package with programs.ags-shell.layout.
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
