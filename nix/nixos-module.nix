{ self }:

{
  ...
}:

{
  _file = "rflxn-shell/nixos-module.nix";
  key = "rflxn-shell/nixos-module";

  config.home-manager.sharedModules = [ self.homeManagerModules.default ];
}
