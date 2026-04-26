{ self }:

{
  ...
}:

{
  home-manager.sharedModules = [
    self.homeManagerModules.default
  ];
}
