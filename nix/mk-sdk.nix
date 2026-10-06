{
  lib,
  runCommand,
  lndir,
  stdenvNoCC,
  release,
  xtool,
}:

components:

let
  componentList = lib.unique components;
  componentPaths = lib.concatMapStringsSep " " lib.escapeShellArg componentList;
  includesXtool = builtins.elem xtool componentList;
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

    ${lib.optionalString (includesXtool && stdenvNoCC.hostPlatform.isDarwin) ''
      rm "$out/bin/xtool"
      cat > "$out/bin/xtool" <<'EOF'
      #!/bin/sh
      : "''${APPLE_NIXPKGS_XCODE_PATH:=/Applications/Xcode.app}"
      export APPLE_NIXPKGS_XCODE_PATH
      export DEVELOPER_DIR="$APPLE_NIXPKGS_XCODE_PATH/Contents/Developer"
      export PATH="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH"
      exec ${xtool}/bin/xtool "$@"
      EOF
      chmod +x "$out/bin/xtool"
    ''}
  ''
