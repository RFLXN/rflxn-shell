{
  description = "Quickshell development shell for Hyprland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    quickshell = {
      url = "github:quickshell-mirror/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      quickshell,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkQtModules =
        pkgs: with pkgs.qt6; [
          qtsvg
          qtimageformats
          qtmultimedia
          qt5compat
        ];
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          rflxn-shell = pkgs.callPackage ./nix/package.nix {
            layoutJson = ./layout.json;
          };

          default = rflxn-shell;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          module-contract = import ./nix/module-check.nix {
            inherit pkgs;
            defaultPackage = self.packages.${system}.default;
            homeManagerModule = self.homeManagerModules.default;
            namedPackage = self.packages.${system}.rflxn-shell;
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          quickshellPkg = quickshell.packages.${system}.default.withModules (mkQtModules pkgs);
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              quickshellPkg

              # QML language server and useful Qt inspection tools.
              qt6.qtdeclarative
              qt6.qttools

              # Hyprland and Wayland helpers commonly used while iterating on a shell.
              hyprland
              grim
              slurp
              wl-clipboard

              inotify-tools
              jq
              libnotify
              socat
            ];

            shellHook = ''
              echo "Quickshell dev shell"
              echo "  system: ${system}"
              echo "  quickshell: $(quickshell --version 2>/dev/null || echo unknown)"
              echo
              echo "Try: quickshell -p ./shell.qml"
            '';
          };
        }
      );

      homeManagerModules = rec {
        rflxn-shell = import ./nix/home-manager-module.nix {
          inherit nixpkgs quickshell;
        };

        default = rflxn-shell;
      };

      nixosModules = rec {
        rflxn-shell = import ./nix/nixos-module.nix {
          inherit self;
        };

        default = rflxn-shell;
      };
    };
}
