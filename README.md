# Apple Nixpkgs

Reproducible Nix packages and version policy for Apple platform development
with [xtool](https://github.com/xtool-org/xtool).

The package set pins xtool and declares a tested bill of materials for Xcode,
Swift and the Apple platform SDKs. Apple-proprietary Xcode and SDK files remain
in the Xcode installation obtained by each developer from Apple; this repository
does not download, copy, publish or cache them.

## Supported hosts

- Apple SDK environment: Apple Silicon macOS (`aarch64-darwin`)
- Standalone xtool package: Apple Silicon macOS, x86-64 Linux and ARM64 Linux

Linux xtool packages are provided because xtool itself supports those hosts.
The composed Apple SDK is intentionally restricted to Apple hardware running
macOS, matching the execution boundary in Apple's Xcode and SDK agreement.

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
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
      appleSdk = apple-nixpkgs.sdk.${system} (sdkPkgs: with sdkPkgs; [
        xtool
        xcode-platform
      ]);
    in {
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [ appleSdk ];
      };
    };
}
```

The setup hook selects `/Applications/Xcode.app` by default. Select another
installation without changing the package set:

```bash
export APPLE_NIXPKGS_XCODE_PATH=/Applications/Xcode-beta.app
nix develop
apple-sdk-doctor
```

The hook exports `DEVELOPER_DIR` and adds the selected Xcode toolchain to
`PATH`. It deliberately does not export `SDKROOT`; callers should select an SDK
for an individual command through xtool or `xcrun --sdk`.

## Package model

- `xtool`: the signed upstream application on macOS and official AppImage on
  Linux;
- `xcode-platform`: environment setup and validation for an external Xcode;
- `sdk`: the composed Apple development environment.

`nix run .#doctor` validates the selected installation against the release
manifest, including Xcode version and build, Swift version, and every declared
platform SDK. This separates reproducible policy from licensed payload:

```text
Nix store                          External developer state
-------------------------------    ----------------------------------
xtool binary                       /Applications/Xcode.app
version manifest                   Apple Account authentication
environment and validation logic   certificates and private keys
                                   provisioning profiles and devices
```

Authentication, signing identities, provisioning profiles, registered devices
and xtool account state must not be placed in a derivation or committed to this
repository.

## Release model

`main` tracks the newest verified stable BOM. Consumers pin its exact revision
with `flake.lock`. The manifest in [`nix/releases.nix`](nix/releases.nix) is the
source of truth; README prose is not a version registry.

Each release records:

- Xcode marketing version and build number;
- Swift compiler version;
- Apple platform SDK versions;
- xtool version and official release hashes.

Adding a release requires validating both `apple-sdk-doctor` and an actual
xtool application build. A successful `xtool --version` check alone is not a
sufficient compatibility test.

## Licensing boundary

The MIT license covers only this repository's Nix expressions, scripts and
documentation. xtool retains its upstream license. Xcode and Apple SDKs remain
subject to Apple's agreements and are neither redistributed nor admitted to a
public binary cache by this project.
