# Apple Nixpkgs

Reproducible host tools and release policy for Apple platform development with
[xtool](https://github.com/xtool-org/xtool).

Apple Nixpkgs exposes one composable SDK interface on every supported host. Host
differences remain internal to the package set:

| Host | Nix-managed components | User-provided Apple component |
| --- | --- | --- |
| Apple Silicon macOS | xtool and environment policy | Xcode.app |
| x86-64 Linux | xtool and matching Swift.org toolchain | Darwin SDK built from Xcode |
| ARM64 Linux | xtool and matching Swift.org toolchain | Darwin SDK built from Xcode |

The repository never downloads or redistributes Xcode or Apple SDK contents.
It records the compatible Xcode, Swift, platform SDK and xtool versions, then
validates the external Apple component before a build.

## Use as a Flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    apple-nixpkgs = {
      url = "github:cavivie/apple-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, apple-nixpkgs, ... }:
    let
      system = builtins.currentSystem;
      pkgs = import nixpkgs { inherit system; };
      appleSdk = apple-nixpkgs.sdk.${system} (
        sdkPkgs: with sdkPkgs; [
          xtool
          apple-platform
        ]
      );
    in {
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [ appleSdk ];
      };
    };
}
```

Consumers select logical components through `sdk.<system>`. Selecting
`apple-platform` automatically adds the matching Swift.org host toolchain on
Linux, so the same component list works on every supported host. This keeps
host-specific dependencies and the compatibility contract inside Apple
Nixpkgs.

## Platform setup

### macOS

The SDK environment selects `/Applications/Xcode.app` by default. A different Xcode
installation can be selected without modifying the package set:

```bash
export APPLE_NIXPKGS_XCODE_PATH=/Applications/Xcode-beta.app
nix run github:cavivie/apple-nixpkgs#doctor
```

The setup hook exports `DEVELOPER_DIR` and places the selected Xcode toolchain
on `PATH`. It deliberately does not export `SDKROOT`; xtool or an individual
`xcrun --sdk` invocation must select the target SDK.

### Linux

Linux requires both the Swift host toolchain and a Darwin Swift SDK. The former
is supplied by Nix and matches the Swift release embedded in the selected
Xcode. The latter must be produced from an Xcode download obtained by the user
from Apple Developer.

Swift.org publishes host binaries against named Linux distributions rather
than as a distribution-neutral archive. The release manifest therefore records
Ubuntu 24.04 (`noble`) as the upstream binary baseline. The package patches its
ELF loader and runtime library paths to Nix store dependencies; consumers do
not need Ubuntu or an FHS installation.

Install directly from `Xcode.xip`, `Xcode.app`, or a prebuilt
`darwin.xtoolsdk`:

```bash
nix run github:cavivie/apple-nixpkgs#install-sdk -- ~/Downloads/Xcode.xip
nix run github:cavivie/apple-nixpkgs#doctor
```

The installer delegates SDK construction and post-processing to the pinned
xtool version. It installs the result at xtool's standard SwiftPM location:
`$XDG_CONFIG_HOME/swiftpm/swift-sdks/darwin.artifactbundle`, or
`~/.swiftpm/swift-sdks/darwin.artifactbundle` when `XDG_CONFIG_HOME` is unset.
This is external developer state, analogous to the selected Xcode.app on
macOS. Missing or incompatible state is an error; the SDK environment never degrades
to a standalone xtool environment.

SDK construction is architecture-specific. A `.xtoolsdk` prepared for an
x86-64 Linux host must not be reused on ARM64 Linux, or conversely.

## Package model

- `sdk.<system>` is the primary component interface;
- `packages.<system>.sdk` is the complete SDK preset;
- `packages.<system>.toolchain` is a compatibility alias for the complete SDK;
- `packages.<system>.xtool` is a leaf package for SDK maintenance and
  diagnostics;
- `packages.<linux-system>.swift-toolchain` is the Swift.org host toolchain;

`nix run .#doctor` validates the complete release contract. On macOS it checks
Xcode version and build, Swift, and all declared platform SDKs. On Linux it
checks the Swift host compiler, xtool SDK layout epoch, required metadata, and
the iPhoneOS, iPhoneSimulator, and macOS SDK versions.

Authentication, signing identities, provisioning profiles, registered devices
and xtool account state remain outside Nix derivations and source control.

## Release model

`main` tracks the newest verified stable bill of materials. Consumers pin its
exact revision in `flake.lock`. [`nix/releases.nix`](nix/releases.nix) is the
source of truth and records:

- Xcode marketing version and build number;
- Swift version, upstream Linux distribution baseline, and official archives;
- Apple platform SDK versions;
- xtool version, sources, and Darwin SDK layout dependencies.

Changing any member requires a complete compatibility validation. In
particular, upgrading xtool can invalidate an installed Linux Darwin SDK even
when the Xcode version is unchanged.

## Licensing boundary

The MIT license covers only this repository's Nix expressions, scripts and
documentation. xtool and Swift retain their upstream licenses. Xcode and Apple
SDKs remain subject to Apple's agreements and are neither redistributed nor
admitted to a public binary cache by this project.
