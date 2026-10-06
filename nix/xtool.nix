{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  appimageTools,
  libusb1,
  release,
}:

let
  inherit (release.xtool) version;
  source =
    release.xtool.sources.${stdenvNoCC.hostPlatform.system}
      or (throw "xtool ${version} is unavailable for ${stdenvNoCC.hostPlatform.system}");
  src = fetchurl { inherit (source) url hash; };
  meta = {
    description = "Cross-platform Apple app build and deployment tool";
    homepage = "https://github.com/xtool-org/xtool";
    license = lib.licenses.mit;
    platforms = builtins.attrNames release.xtool.sources;
    mainProgram = "xtool";
  };
in
if stdenvNoCC.hostPlatform.isDarwin then
  stdenvNoCC.mkDerivation {
    pname = "xtool";
    inherit version src meta;
    nativeBuildInputs = [ unzip ];
    sourceRoot = ".";

    # The upstream app is signed. Mutating it during fixup makes Gatekeeper
    # report the bundle as damaged.
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications" "$out/bin"
      cp -R xtool.app "$out/Applications/xtool.app"
      ln -s "$out/Applications/xtool.app/Contents/Resources/bin/xtool" "$out/bin/xtool"
      runHook postInstall
    '';
  }
else
  appimageTools.wrapType2 {
    pname = "xtool";
    inherit version src meta;
    extraPkgs = _pkgs: [ libusb1 ];
  }
