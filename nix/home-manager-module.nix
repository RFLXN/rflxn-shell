{
  quickshell,
  nixpkgs ? quickshell.inputs.nixpkgs,
}:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    literalExpression
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.services.rflxn-shell;
  system = pkgs.stdenv.hostPlatform.system;
  layoutFormat = pkgs.formats.json { };
  quickshellPkgs = nixpkgs.legacyPackages.${system};
  qtModules = with quickshellPkgs.qt6; [
    qtsvg
    qtimageformats
    qtmultimedia
    qt5compat
  ];
  defaultQuickshellPackage = quickshell.packages.${system}.default.withModules qtModules;
  defaultRuntimePackages = with pkgs; [
    blueman
    hyprland
    networkmanager
    pwvucontrol
    uwsm
  ];
  requiredRuntimePackages = with pkgs; [
    brightnessctl
    networkmanagerapplet
  ];
  symbolsFont = lib.attrByPath [ "nerd-fonts" "symbols-only" ] (pkgs.nerdfonts.override {
    fonts = [ "NerdFontsSymbolsOnly" ];
  }) pkgs;
  fontPackages = [
    pkgs.pretendard
    symbolsFont
  ];
  servicePathPackages = [
    pkgs.bash
    pkgs.coreutils
    pkgs.systemd
  ]
  ++ requiredRuntimePackages
  ++ cfg.runtimePackages;
  servicePath = lib.concatStringsSep ":" [
    (lib.makeBinPath servicePathPackages)
    "${config.home.profileDirectory}/bin"
    "/run/current-system/sw/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];
  layoutJson = layoutFormat.generate "rflxn-shell-layout.json" cfg.configs;
  generatedPackage = pkgs.callPackage ./package.nix {
    inherit layoutJson;
  };
  package = if cfg.package == null then generatedPackage else cfg.package;
  quickshellMainProgram = cfg.quickshellPackage.meta.mainProgram or null;
  quickshellExecutable = lib.getExe' cfg.quickshellPackage (
    if quickshellMainProgram == null then "quickshell" else quickshellMainProgram
  );
  shellConfigPath = "${config.xdg.configHome}/quickshell/rflxn-shell/shell.qml";
in
{
  _file = "rflxn-shell/home-manager-module.nix";
  key = "rflxn-shell/home-manager-module";

  options.services.rflxn-shell = {
    enable = mkEnableOption "the rflxn Quickshell Hyprland shell";

    configs = mkOption {
      type = layoutFormat.type;
      default = builtins.fromJSON (builtins.readFile ../layout.json);
      example = literalExpression ''
        {
          layouts = [
            {
              monitor = "DP-3";
              widgets = {
                left = [ "feed-hub" "window-title" ];
                center = [ "workspaces" "datetime" ];
                right = [ "system-controls" ];
              };
              menus = {
                system-controls = {
                  direction = "right";
                  menuWidth = 420;
                  programs = {
                    volume.command = "pwvucontrol";
                    bluetooth.command = "blueman-manager";
                    network.command = "nm-connection-editor";
                  };
                };
              };
              components = [
                "feed-hub-menu"
                "system-controls-menu"
                "global-menu-close-layer"
              ];
            }
          ];
        }
      '';
      description = ''
        Layout JSON rendered to layout.json for the shell package. The value is
        consumed by config/Layouts.qml at runtime and controls monitor-specific
        bar widgets, menu placement, overlay components, notification popups,
        and system-control program launch configuration.
      '';
    };

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        Prebuilt shell source package. When null, this module builds the current
        flake source with services.rflxn-shell.configs rendered as layout.json.
      '';
    };

    quickshellPackage = mkOption {
      type = types.package;
      default = defaultQuickshellPackage;
      defaultText = literalExpression ''
        let
          quickshellPkgs = inputs.<this-flake>.inputs.nixpkgs.legacyPackages.''${pkgs.stdenv.hostPlatform.system};
        in
        inputs.<this-flake>.inputs.quickshell.packages.''${pkgs.stdenv.hostPlatform.system}.default.withModules (
          with quickshellPkgs.qt6; [ qtsvg qtimageformats qtmultimedia qt5compat ]
        )
      '';
      description = "Quickshell package used to run the shell.";
    };

    runtimePackages = mkOption {
      type = types.listOf types.package;
      default = defaultRuntimePackages;
      defaultText = literalExpression ''
        with pkgs; [ blueman hyprland networkmanager pwvucontrol uwsm ]
      '';
      description = ''
        Runtime tools made available to the user session. The defaults cover
        nmcli, hyprctl, uwsm, pwvucontrol, and blueman-manager.
      '';
    };

    systemdTarget = mkOption {
      type = types.str;
      default = "graphical-session.target";
      description = "User systemd target that starts the rflxn-shell service.";
    };
  };

  config = mkIf cfg.enable {
    fonts.fontconfig.enable = mkDefault true;

    home.packages = [
      cfg.quickshellPackage
      (lib.hiPrio package)
    ]
    ++ requiredRuntimePackages
    ++ fontPackages
    ++ cfg.runtimePackages;

    xdg.configFile."quickshell/rflxn-shell".source = "${package}/share/rflxn-shell";

    systemd.user.services.rflxn-shell = {
      Unit = {
        Description = "rflxn Quickshell Hyprland shell";
        After = [ cfg.systemdTarget ];
        PartOf = [ cfg.systemdTarget ];
        X-Restart-Triggers = [ package ];
      };

      Service = {
        Environment = [ "PATH=${servicePath}" ];
        ExecStart = "${quickshellExecutable} --path ${shellConfigPath} --no-duplicate";
        Restart = "on-failure";
        RestartSec = 2;
      };

      Install.WantedBy = [ cfg.systemdTarget ];
    };
  };
}
