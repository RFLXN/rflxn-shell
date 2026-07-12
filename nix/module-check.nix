{
  defaultPackage,
  homeManagerModule,
  namedPackage,
  pkgs,
}:

let
  inherit (pkgs) lib;
  moduleEvaluation = lib.evalModules {
    specialArgs = { inherit pkgs; };
    modules = [
      homeManagerModule
      homeManagerModule
      (
        { lib, ... }:
        {
          options = {
            fonts.fontconfig.enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            home.packages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
            };
            home.profileDirectory = lib.mkOption {
              type = lib.types.str;
            };
            systemd.user.services = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
            };
            xdg.configFile = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
            };
            xdg.configHome = lib.mkOption {
              type = lib.types.str;
            };
          };

          config = {
            home.profileDirectory = "/home/module-check/.nix-profile";
            services.rflxn-shell = {
              enable = true;
              runtimePackages = [ ];
              configs.layouts = [
                {
                  monitor = "MODULE-CHECK";
                  widgets.center = [ "datetime" ];
                  components = [ "calendar-menu" ];
                }
              ];
            };
            xdg.configHome = "/home/module-check/.config";
          };
        }
      )
    ];
  };
  moduleOptions = moduleEvaluation.options.services.rflxn-shell;
  moduleConfig = moduleEvaluation.config;
  service = moduleConfig.systemd.user.services.rflxn-shell;
  generatedPackages = builtins.filter (
    package: (package.pname or "") == "rflxn-shell"
  ) moduleConfig.home.packages;
  generatedPackage = builtins.head generatedPackages;
  homePackagePaths = map toString moduleConfig.home.packages;
  profilePackage = pkgs.buildEnv {
    name = "rflxn-shell-module-profile";
    paths = moduleConfig.home.packages ++ [ namedPackage ];
  };
  renamedQuickshell = (pkgs.writeShellScriptBin "quickshell" "exit 0").overrideAttrs (_: {
    pname = "renamed-quickshell-runtime";
    name = "renamed-quickshell-runtime";
    meta = { };
  });
  customQuickshellEvaluation = moduleEvaluation.extendModules {
    modules = [
      {
        services.rflxn-shell.quickshellPackage = renamedQuickshell;
      }
    ];
  };
  customQuickshellExecStart =
    customQuickshellEvaluation.config.systemd.user.services.rflxn-shell.Service.ExecStart;
  expectedRuntimePackageNames = [
    "blueman"
    "hyprland"
    "networkmanager"
    "pwvucontrol"
    "uwsm"
  ];
in
assert defaultPackage.drvPath == namedPackage.drvPath;
assert moduleOptions.enable.default == false;
assert moduleOptions.configs.type.description == "JSON value";
assert moduleOptions.package.default == null;
assert moduleOptions.systemdTarget.default == "graphical-session.target";
assert
  map (package: package.pname) moduleOptions.runtimePackages.default == expectedRuntimePackageNames;
assert builtins.length generatedPackages == 1;
assert moduleConfig.fonts.fontconfig.enable;
assert builtins.elem (toString pkgs.brightnessctl) homePackagePaths;
assert builtins.elem (toString pkgs.networkmanagerapplet) homePackagePaths;
assert builtins.elem (toString pkgs.pretendard) homePackagePaths;
assert lib.hasInfix (builtins.unsafeDiscardStringContext "${pkgs.brightnessctl}/bin") (
  builtins.head service.Service.Environment
);
assert lib.hasInfix (builtins.unsafeDiscardStringContext "${pkgs.networkmanagerapplet}/bin") (
  builtins.head service.Service.Environment
);
assert lib.hasInfix "--path /home/module-check/.config/quickshell/rflxn-shell/shell.qml"
  service.Service.ExecStart;
assert lib.hasPrefix "${renamedQuickshell}/bin/quickshell " customQuickshellExecStart;
assert service.Unit.X-Restart-Triggers == [ generatedPackage ];
pkgs.runCommand "rflxn-shell-module-contract" { nativeBuildInputs = [ pkgs.jq ]; } ''
  test -f ${generatedPackage}/share/rflxn-shell/shell.qml
  test -f ${generatedPackage}/share/rflxn-shell/components/state/BrightnessState.qml
  test -f ${generatedPackage}/share/rflxn-shell/components/state/HyprlandState.qml
  test -f ${generatedPackage}/share/rflxn-shell/components/widgets/systemcontrols/SystemControlsBrightnessPanel.qml
  test -x ${pkgs.brightnessctl}/bin/brightnessctl
  test -x ${pkgs.networkmanagerapplet}/bin/nm-connection-editor
  test -x ${renamedQuickshell}/bin/quickshell
  jq -e '.layouts[0].monitor == "MODULE-CHECK"' \
    ${generatedPackage}/share/rflxn-shell/layout.json >/dev/null
  jq -e '.layouts[0].monitor == "MODULE-CHECK"' \
    ${profilePackage}/share/rflxn-shell/layout.json >/dev/null
  touch "$out"
''
