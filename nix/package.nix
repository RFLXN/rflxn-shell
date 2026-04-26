{
  lib,
  stdenvNoCC,
  layoutJson ? ../layout.json,
}:

let
  root = toString ../.;
  includedTopLevel = [
    "app.tsx"
    "assets"
    "components"
    "env.d.ts"
    "ipc"
    "layout.tsx"
    "package.json"
    "style.scss"
    "styles"
    "tsconfig.json"
    "utils"
  ];

  relPath = path:
    let
      pathString = toString path;
    in
      if pathString == root then "" else lib.removePrefix "${root}/" pathString;

  topLevel = path:
    builtins.elemAt (lib.splitString "/" path) 0;
in
stdenvNoCC.mkDerivation {
  pname = "ags-shell-config";
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

    mkdir -p "$out/share/ags"
    cp -R \
      app.tsx \
      assets \
      components \
      env.d.ts \
      ipc \
      layout.tsx \
      package.json \
      style.scss \
      styles \
      tsconfig.json \
      utils \
      "$out/share/ags/"
    cp ${layoutJson} "$out/share/ags/layout.json"

    runHook postInstall
  '';

  meta = {
    description = "AGS Hyprland shell source tree";
    platforms = lib.platforms.linux;
  };
}
