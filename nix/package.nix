{
  lib,
  stdenvNoCC,
  layoutJson ? ../layout.json,
}:

let
  root = toString ../.;
  includedTopLevel = [
    "ScreenShell.qml"
    "components"
    "config"
    "shell.qml"
    "theme"
  ];

  relPath = path:
    let
      pathString = toString path;
    in
      if pathString == root then "" else lib.removePrefix "${root}/" pathString;

  topLevel = path: builtins.elemAt (lib.splitString "/" path) 0;
in
stdenvNoCC.mkDerivation {
  pname = "rflxn-shell";
  version = "0.1.0";

  src = lib.cleanSourceWith {
    src = ../.;
    filter = path: _type:
      let
        rel = relPath path;
      in
        rel == "" || builtins.elem (topLevel rel) includedTopLevel;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/rflxn-shell"
    cp -R \
      ScreenShell.qml \
      components \
      config \
      shell.qml \
      theme \
      "$out/share/rflxn-shell/"
    cp ${layoutJson} "$out/share/rflxn-shell/layout.json"

    runHook postInstall
  '';

  meta = {
    description = "Quickshell Hyprland shell source tree";
    platforms = lib.platforms.linux;
  };
}
