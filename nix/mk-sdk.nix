{
  lib,
  runCommand,
  lndir,
  release,
}:

components:

let
  componentList = lib.unique components;
  componentPaths = lib.concatMapStringsSep " " lib.escapeShellArg componentList;
in
runCommand "apple-sdk-${release.xcode.version}"
  {
    nativeBuildInputs = [ lndir ];
    preferLocalBuild = true;
    passthru = {
      inherit release;
      components = componentList;
    };
  }
  ''
    mkdir -p "$out"
    for component in ${componentPaths}; do
      lndir -silent "$component" "$out"
    done
  ''
