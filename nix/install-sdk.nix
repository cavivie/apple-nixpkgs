{
  lib,
  writeShellApplication,
  xtool,
  swiftToolchain,
  darwinPlatform,
  release,
  system,
}:

writeShellApplication {
  name = "apple-sdk-install";
  runtimeInputs = [
    xtool
    swiftToolchain
    darwinPlatform
  ];

  text = ''
    usage() {
      cat <<'EOF'
    Usage: apple-sdk-install <Xcode.xip|Xcode.app|darwin.xtoolsdk>

    Build or install the Darwin Swift SDK used by xtool on Linux. Xcode must be
    obtained directly from Apple; this command does not download licensed SDKs.
    EOF
    }

    case "''${1:-}" in
      -h|--help)
        usage
        exit 0
        ;;
    esac

    if [[ $# -ne 1 ]]; then
      usage >&2
      exit 2
    fi

    source_path=$1
    if [[ ! -e "$source_path" ]]; then
      echo "error: source does not exist: $source_path" >&2
      exit 1
    fi

    echo "Installing the Darwin SDK for ${system} with xtool ${release.xtool.version}"
    xtool sdk install --slim "$source_path"
    apple-sdk-doctor
  '';

  meta = {
    description = "Install and validate the licensed Darwin SDK used by xtool on Linux";
    license = lib.licenses.mit;
    platforms = builtins.attrNames release.swift.sources;
    mainProgram = "apple-sdk-install";
  };
}
