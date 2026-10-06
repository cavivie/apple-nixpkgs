{
  lib,
  stdenvNoCC,
  writeText,
  release,
  swiftToolchain,
  xtool,
}:

let
  expectedSdkVersion = "epoch=${toString release.darwinSdk.epoch},darwinTools=${release.darwinSdk.darwinToolsVersion},oam=${release.darwinSdk.openAppleMacrosVersion}";

  setupHook = writeText "apple-darwin-platform-setup-hook" ''
    if [ -n "''${XDG_CONFIG_HOME:-}" ]; then
      apple_swiftpm_dir="$XDG_CONFIG_HOME/swiftpm"
    else
      apple_swiftpm_dir="$HOME/.swiftpm"
    fi
    export APPLE_NIXPKGS_DARWIN_SDK="$apple_swiftpm_dir/swift-sdks/darwin.artifactbundle"
    export APPLE_NIXPKGS_CLANG="${swiftToolchain}/bin/clang"
    unset apple_swiftpm_dir
  '';

  doctor = writeText "apple-sdk-doctor-linux" ''
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

    if [ "$(uname -s)" != Linux ]; then
      echo "Linux Darwin SDK validation requires a Linux host." >&2
      exit 1
    fi

    swift_version="$(${swiftToolchain}/bin/swift --version 2>/dev/null | sed -n 's/.*Swift version \([^ ]*\).*/\1/p' | head -n 1)"
    check_equal "Swift" ${lib.escapeShellArg release.swift.version} "$swift_version"

    xtool_version="$(${xtool}/bin/xtool --version 2>/dev/null | sed -n 's/^xtool //p' | head -n 1)"
    check_equal "xtool" ${lib.escapeShellArg release.xtool.version} "$xtool_version"

    if [ -n "''${XDG_CONFIG_HOME:-}" ]; then
      swiftpm_dir="$XDG_CONFIG_HOME/swiftpm"
    else
      swiftpm_dir="$HOME/.swiftpm"
    fi
    sdk="$swiftpm_dir/swift-sdks/darwin.artifactbundle"

    if [ ! -d "$sdk" ]; then
      echo "Darwin SDK not found: $sdk" >&2
      echo "Install Xcode.xip or darwin.xtoolsdk with: nix run github:cavivie/apple-nixpkgs#install-sdk -- /path/to/archive" >&2
      exit 1
    fi

    sdk_version="$(sed -n '1p' "$sdk/darwin-sdk-version.txt" 2>/dev/null || true)"
    check_equal "Darwin SDK layout" ${lib.escapeShellArg expectedSdkVersion} "$sdk_version"

    if [ ! -x "${swiftToolchain}/bin/clang" ]; then
      echo "Linux clang is unavailable: ${swiftToolchain}/bin/clang" >&2
      fail=1
    fi
    if [ ! -x "$sdk/toolset/bin/ld64.lld" ]; then
      echo "Darwin linker is unavailable: $sdk/toolset/bin/ld64.lld" >&2
      fail=1
    fi

    check_sdk() {
      platform="$1"
      prefix="$2"
      expected="$3"
      sdk_dir="$sdk/Developer/Platforms/$platform.platform/Developer/SDKs"
      if [ -d "$sdk_dir/$prefix$expected.sdk" ]; then
        echo "$prefix SDK: $expected"
      else
        echo "$prefix SDK mismatch: expected $expected under $sdk_dir" >&2
        fail=1
      fi
    }

    check_sdk iPhoneOS iPhoneOS ${lib.escapeShellArg release.sdks.iphoneos}
    check_sdk iPhoneSimulator iPhoneSimulator ${lib.escapeShellArg release.sdks.iphonesimulator}
    check_sdk MacOSX MacOSX ${lib.escapeShellArg release.sdks.macosx}

    for required in info.json swift-sdk.json toolset.json toolset-swb.json; do
      if [ ! -f "$sdk/$required" ]; then
        echo "Darwin SDK is incomplete: missing $required" >&2
        fail=1
      fi
    done

    if ! ${swiftToolchain}/bin/swift sdk list 2>/dev/null | grep -qx darwin; then
      echo "SwiftPM does not discover the installed Darwin SDK." >&2
      fail=1
    fi

    if [ "$fail" -ne 0 ]; then
      exit 1
    fi
  '';
in
stdenvNoCC.mkDerivation {
  pname = "apple-darwin-platform";
  version = release.xcode.version;
  dontUnpack = true;
  dontFixup = true;

  installPhase = ''
    mkdir -p "$out/bin" "$out/nix-support"
    cp ${doctor} "$out/bin/apple-sdk-doctor"
    chmod +x "$out/bin/apple-sdk-doctor"
    cp ${setupHook} "$out/nix-support/setup-hook"
  '';

  passthru = { inherit release expectedSdkVersion; };

  meta = {
    description = "Validation policy for an xtool Darwin SDK installed on Linux";
    license = lib.licenses.mit;
    platforms = builtins.attrNames release.swift.sources;
  };
}
