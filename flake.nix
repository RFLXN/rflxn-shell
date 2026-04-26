{
  description = "My Awesome Desktop Shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    ags = {
      url = "github:aylur/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ags,
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    mkAstalPackages = system:
      with ags.packages.${system}; [
        astal4 # or astal3 for gtk3
        io
        apps
        battery
        bluetooth
        hyprland
        mpris
        network
        notifd
        tray
        wireplumber
        powerprofiles
      ];

    mkRuntimePackages = system: pkgs:
      let
        astalPackages = mkAstalPackages system;
      in
      astalPackages
      ++ [
        pkgs.libadwaita
        pkgs.libsoup_3
        pkgs.gtk4
        pkgs.papirus-icon-theme
        pkgs.upower
      ];

    forEachSystem = f:
      nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          extraPackages = mkRuntimePackages system pkgs;
          agsPackage = ags.packages.${system}.default.override {
            inherit extraPackages;
          };
        in
          f {
            inherit
              system
              pkgs
              extraPackages
              agsPackage
              ;
          });
  in {
    packages = forEachSystem ({
      pkgs,
      ...
    }: rec {
      ags-shell = pkgs.callPackage ./nix/package.nix {
        layoutJson = ./layout.json;
      };

      default = ags-shell;
    });

    devShells = forEachSystem ({
      pkgs,
      agsPackage,
      ...
    }: {
      default = pkgs.mkShell {
        buildInputs = [ agsPackage ];
      };
    });

    homeManagerModules = rec {
      ags-shell = import ./nix/home-manager-module.nix {
        inherit ags mkRuntimePackages;
      };

      default = ags-shell;
    };

    nixosModules = {
      ags-shell = import ./nix/nixos-module.nix {
        inherit self;
      };
    };
  };
}
