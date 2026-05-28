# Nix Integration

Last updated: 2026-04-24

This flake exposes the shell as both a source package and a Home Manager module.

## Outputs

- `packages.<system>.ags-shell`: source package containing the AGS app under
  `share/ags`.
- `packages.<system>.default`: alias of `ags-shell`.
- `homeManagerModules.ags-shell`: Home Manager module.
- `homeManagerModules.default`: alias of `ags-shell`.
- `nixosModules.ags-shell`: NixOS helper module that adds the Home Manager
  module to `home-manager.sharedModules`.
- `devShells.<system>.default`: development shell with the same AGS runtime
  package set used by the module.

## NixOS Usage

If Home Manager is managed from NixOS, import the NixOS helper module once and
then enable the program under the user:

```nix
{
  inputs.new-shell.url = "path:/home/rflxn/development/new-shell";

  outputs = { nixpkgs, home-manager, new-shell, ... }: {
    nixosConfigurations.<hostname> = nixpkgs.lib.nixosSystem {
      modules = [
        home-manager.nixosModules.home-manager
        new-shell.nixosModules.ags-shell

        {
          home-manager.users.<username>.programs.ags-shell = {
            enable = true;
          };
        }
      ];
    };
  };
}
```

## Home Manager Usage

If the module is imported directly in a Home Manager user config:

```nix
{
  imports = [ inputs.new-shell.homeManagerModules.default ];

  programs.ags-shell.enable = true;
}
```

When enabled, the module:

- Installs the AGS package with the same Astal/Gtk runtime package set as the
  devShell.
- Installs those runtime packages, including `papirus-icon-theme` and `xprop`,
  into `home.packages`.
- Builds this shell source tree into the Nix store.
- Symlinks `~/.config/ags` to the packaged source tree.

## Layout Configuration

The default layout lives at the repository root as `layout.json`. The Home
Manager module exposes the same shape as `programs.ags-shell.layout`:

```nix
programs.ags-shell = {
  enable = true;

  layout = {
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
  };
};
```

The configured value is rendered as `layout.json` inside the packaged AGS source
tree, so the runtime still reads one root-level JSON file.

## System Controls Menu Programs

The system controls menu can launch external control panels from its header
buttons. Configure them under `programs.ags-shell.systemControlMenu`:

```nix
programs.ags-shell = {
  enable = true;

  systemControlMenu = {
    volume.program = pkgs.pwvucontrol;
    bluetooth.program = pkgs.blueman;
  };
};
```

Package values are converted to their main executable with `lib.getExe`.
String values are also accepted when a custom command line is needed:

```nix
programs.ags-shell.systemControlMenu.bluetooth.program =
  "${pkgs.blueman}/bin/blueman-manager";
```

The configured value is rendered as `system-control-menu.json` inside the
packaged AGS source tree.
