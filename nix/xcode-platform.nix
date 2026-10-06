{
  lib,
  stdenvNoCC,
  writeText,
  release,
}:

let
  sdkChecks = lib.concatMapStringsSep "\n" (
    sdk:
    let
      expected = release.sdks.${sdk};
    in
    ''
      actual_sdk="$(${"/usr/bin/xcrun"} --sdk ${lib.escapeShellArg sdk} --show-sdk-version 2>/dev/null || true)"
      check_equal "${sdk} SDK" ${lib.escapeShellArg expected} "$actual_sdk"
    ''
  ) (builtins.attrNames release.sdks);

  doctor = writeText "apple-sdk-doctor" ''
    #!/bin/sh
    set -eu

    fail=0
    check_equal() {
      label="$1"
      expected="$2"
      actual="$3"
      if [ "$actual" != "$expected" ]; then
        echo "$label mismatch: expected $expected, found ''${actual:-unavailable}" >&2
        fail=1
      else
        echo "$label: $actual"
      fi
    }

    if [ "$(uname -s)" != Darwin ]; then
      echo "Apple SDK validation requires macOS on Apple hardware." >&2
      exit 1
    fi

    : "''${APPLE_NIXPKGS_XCODE_PATH:=/Applications/Xcode.app}"
    : "''${DEVELOPER_DIR:=$APPLE_NIXPKGS_XCODE_PATH/Contents/Developer}"
    export DEVELOPER_DIR

    if [ ! -d "$DEVELOPER_DIR" ]; then
      echo "Xcode Developer directory not found: $DEVELOPER_DIR" >&2
      echo "Install Xcode, or set APPLE_NIXPKGS_XCODE_PATH to an Xcode.app path." >&2
      exit 1
    fi

    xcode_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APPLE_NIXPKGS_XCODE_PATH/Contents/Info.plist" 2>/dev/null || true)"
    xcode_build="$(/usr/libexec/PlistBuddy -c 'Print :ProductBuildVersion' "$APPLE_NIXPKGS_XCODE_PATH/Contents/version.plist" 2>/dev/null || true)"
    swift_version="$(/usr/bin/xcrun swift --version 2>/dev/null | sed -n 's/^Apple Swift version \([^ ]*\).*/\1/p')"

    check_equal "Xcode" ${lib.escapeShellArg release.xcode.version} "$xcode_version"
    check_equal "Xcode build" ${lib.escapeShellArg release.xcode.build} "$xcode_build"
    check_equal "Swift" ${lib.escapeShellArg release.swift.version} "$swift_version"

    ${sdkChecks}

    if [ "$fail" -ne 0 ]; then
      exit 1
    fi
  '';

  setupHook = writeText "apple-xcode-platform-setup-hook" ''
    if [ "$(uname -s)" = Darwin ]; then
      unset APPLE_NIXPKGS_DARWIN_SDK APPLE_NIXPKGS_CLANG
      : "''${APPLE_NIXPKGS_XCODE_PATH:=/Applications/Xcode.app}"
      export APPLE_NIXPKGS_XCODE_PATH
      export DEVELOPER_DIR="$APPLE_NIXPKGS_XCODE_PATH/Contents/Developer"
      export PATH="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH"
    fi
  '';
in
stdenvNoCC.mkDerivation {
  pname = "apple-xcode-platform";
  version = release.xcode.version;
  dontUnpack = true;
  dontFixup = true;

  installPhase = ''
    mkdir -p "$out/bin" "$out/nix-support"
    cp ${doctor} "$out/bin/apple-sdk-doctor"
    chmod +x "$out/bin/apple-sdk-doctor"
    cp ${setupHook} "$out/nix-support/setup-hook"
  '';

  passthru = { inherit release; };

  meta = {
    description = "Environment and BOM validation for an externally installed Xcode";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
  };
}
