# rflxn-qs

Quickshell-based Hyprland shell.

This repository exposes the shell as a Nix flake package and as a Home Manager
module. The module renders the configured layout into `layout.json`, packages
the QML source tree, links it into the user's Quickshell config directory, and
starts it with a user systemd service.

## Flake Outputs

```nix
packages.${system}.rflxn-shell
packages.${system}.default

homeManagerModules.rflxn-shell
homeManagerModules.default

nixosModules.rflxn-shell
nixosModules.default
```

The default package installs the QML source tree under:

```text
share/rflxn-shell
```

## Home Manager Usage

Import the Home Manager module directly when configuring a single Home Manager
user:

```nix
{
  imports = [
    inputs.rflxn-qs.homeManagerModules.default
  ];

  services.rflxn-shell = {
    enable = true;

    configs = {
      layouts = [
        {
          monitor = "DP-3";

          widgets = {
            left = [ "feed-hub" "window-title" ];
            center = [ "workspaces" "datetime" ];
            right = [ "system-controls" ];
          };

          menus = {
            app-launcher = {
              direction = "bottom";
              menuWidth = 640;
              menuHeight = 560;
              alignment = "center";
            };

            system-controls = {
              direction = "right";
              menuWidth = 420;
              programs = {
                volume = {
                  command = "pwvucontrol";
                  rules = "float; size 900 650; center";
                };
                bluetooth = {
                  command = "blueman-manager";
                  rules = "float; size 760 560; center";
                };
                network = {
                  command = "nm-connection-editor";
                  rules = "float; size 880 640; center";
                };
              };
            };
          };

          components = [
            "app-launcher-menu"
            "calendar-menu"
            "feed-hub-menu"
            "system-controls-menu"
            {
              id = "notification-popups";
              position = "top-right";
              timeoutMs = 6000;
              maxVisible = 3;
              margin = 8;
              popupWidth = 392;
            }
            "global-menu-close-layer"
          ];
        }
      ];
    };
  };
}
```

## NixOS Usage

When using Home Manager from NixOS, import the NixOS bridge module once:

```nix
{
  imports = [
    inputs.rflxn-qs.nixosModules.default
  ];

  home-manager.users.${username}.services.rflxn-shell = {
    enable = true;
    configs = {
      layouts = [
        {
          monitor = "DP-3";
          widgets.center = [ "workspaces" "datetime" ];
        }
      ];
    };
  };
}
```

The NixOS module only adds this repository's Home Manager module to
`home-manager.sharedModules`. The actual shell options live under each Home
Manager user at `services.rflxn-shell`.

## Module API

All options are under `services.rflxn-shell`.

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enable` | boolean | `false` | Enables the shell service. |
| `configs` | JSON-compatible attrset | repository `layout.json` | Layout and menu configuration rendered into the packaged `layout.json`. |
| `package` | `null` or package | `null` | Prebuilt shell package. When `null`, the module builds this repository with `configs` rendered as `layout.json`. |
| `quickshellPackage` | package | Quickshell with required Qt modules | Quickshell executable used by the service. |
| `runtimePackages` | list of packages | `blueman`, `hyprland`, `networkmanager`, `pwvucontrol`, `uwsm` | Runtime commands available to the user session. |
| `systemdTarget` | string | `"graphical-session.target"` | User systemd target that starts and owns the shell service. |

When enabled, the module configures:

```nix
home.packages = [
  services.rflxn-shell.quickshellPackage
  <generated shell package>
] ++ services.rflxn-shell.runtimePackages;

xdg.configFile."quickshell/rflxn-shell".source =
  "${package}/share/rflxn-shell";

systemd.user.services.rflxn-shell = { ... };
```

The generated service runs:

```text
quickshell --path ${package}/share/rflxn-shell/shell.qml --no-duplicate
```

## `configs` Schema

`configs` is rendered directly as JSON. The shell currently expects:

```nix
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
        # menu id -> menu config
      };

      components = [
        # overlay/component ids or attrsets with an `id`
      ];
    }
  ];
}
```

`bar` can be used instead of `widgets`, and `overlays` can be used instead of
`components`; both aliases are normalized by `config/Layouts.qml`.

Known widget ids:

- `datetime`
- `feed-hub`
- `system-controls`
- `window-title`
- `workspaces`

Known component / overlay ids:

- `app-launcher-menu`
- `calendar-menu`
- `feed-hub-menu`
- `global-menu-close-layer`
- `notification-popups`
- `system-controls-menu`

Common menu fields:

| Field | Example |
| --- | --- |
| `direction` | `"left"`, `"right"`, `"top"`, `"bottom"` |
| `menuWidth` | `420` |
| `menuHeight` | `560` |
| `menuMargin` | `6` |
| `menuTopOffset` | `0` |
| `contentPadding` | `18` |
| `cornerRadius` | `23` |
| `alignment` | `"left"`, `"center"`, `"right"` |

System control program launchers are configured under the `system-controls`
menu:

```nix
menus.system-controls.programs = {
  volume = {
    command = "pwvucontrol";
    rules = "float; size 900 650; center";
  };
  bluetooth = {
    command = "blueman-manager";
    rules = "float; size 760 560; center";
  };
  network = {
    command = "nm-connection-editor";
    rules = "float; size 880 640; center";
  };
};
```

`rules` are applied by the shell when launching the program, using Hyprland
dynamic window rules for that launch.

Notification popup placement can be configured as an overlay object:

```nix
{
  id = "notification-popups";
  position = "top-right";
  timeoutMs = 6000;
  maxVisible = 3;
  margin = 8;
  popupWidth = 392;
}
```

## Development

Run the shell from the repository:

```sh
nix develop --command quickshell --path ./shell.qml --no-duplicate
```

Validate the flake package and module outputs:

```sh
nix flake show --no-write-lock-file
nix build --no-write-lock-file .#packages.x86_64-linux.default
```
