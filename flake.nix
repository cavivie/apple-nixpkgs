{
  description = "Nix package set for Apple platform development with xtool";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forSupportedSystems = nixpkgs.lib.genAttrs supportedSystems;
      releases = import ./nix/releases.nix;
      latestVersion = "26.6";

      packageSetFor =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          release = releases.${latestVersion};
          xtool = pkgs.callPackage ./nix/xtool.nix { inherit release; };
          isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
          swiftToolchain =
            if isDarwin then null else pkgs.callPackage ./nix/swift-toolchain.nix { inherit release; };
          applePlatform =
            if isDarwin then
              pkgs.callPackage ./nix/xcode-platform.nix { inherit release; }
            else
              pkgs.callPackage ./nix/darwin-platform.nix {
                inherit release swiftToolchain xtool;
              };
          sdkPackages = {
            inherit xtool;
            apple-platform = applePlatform;
          }
          // nixpkgs.lib.optionalAttrs (!isDarwin) {
            swift-toolchain = swiftToolchain;
          };
          mkSdk = pkgs.callPackage ./nix/mk-sdk.nix { inherit release xtool; };
          sdk = componentsFn: mkSdk (componentsFn sdkPackages);
          toolchain = sdk (
            components:
            [
              components.xtool
              components.apple-platform
            ]
            ++ nixpkgs.lib.optional (!isDarwin) components.swift-toolchain
          );
          versionSlug = builtins.replaceStrings [ "." ] [ "-" ] release.xcode.version;
        in
        {
          inherit
            applePlatform
            isDarwin
            pkgs
            release
            sdkPackages
            sdk
            swiftToolchain
            toolchain
            versionSlug
            xtool
            ;
        };
    in
    {
      lib = {
        inherit releases latestVersion;
        inherit supportedSystems;
        supportedAppleSystems = supportedSystems;
        supportedXtoolSystems = supportedSystems;
      };

      sdk = forSupportedSystems (system: (packageSetFor system).sdk);

      overlays.default =
        final: _prev:
        nixpkgs.lib.optionalAttrs (builtins.elem final.system supportedSystems) {
          appleXtool = (packageSetFor final.system).xtool;
          appleSdkPackages = (packageSetFor final.system).sdkPackages;
          appleSdk = (packageSetFor final.system).sdk;
          appleToolchain = (packageSetFor final.system).toolchain;
        };

      packages = forSupportedSystems (
        system:
        let
          packageSet = packageSetFor system;
        in
        {
          inherit (packageSet) xtool toolchain;
          sdk = packageSet.toolchain;
          "sdk-${packageSet.versionSlug}" = packageSet.toolchain;
          default = packageSet.toolchain;
        }
        // nixpkgs.lib.optionalAttrs packageSet.isDarwin {
          xcode-platform = packageSet.applePlatform;
          "xcode-platform-${packageSet.versionSlug}" = packageSet.applePlatform;
        }
        // nixpkgs.lib.optionalAttrs (!packageSet.isDarwin) {
          darwin-platform = packageSet.applePlatform;
          swift-toolchain = packageSet.swiftToolchain;
        }
      );

      apps = forSupportedSystems (
        system:
        let
          packageSet = packageSetFor system;
          doctor = {
            type = "app";
            program = "${packageSet.toolchain}/bin/apple-sdk-doctor";
            meta.description = "Validate the selected Xcode and Apple SDK BOM";
          };
        in
        {
          inherit doctor;
          "doctor-${packageSet.versionSlug}" = doctor;
        }
        // nixpkgs.lib.optionalAttrs (!packageSet.isDarwin) (
          let
            installer = packageSet.pkgs.callPackage ./nix/install-sdk.nix {
              inherit (packageSet)
                release
                swiftToolchain
                xtool
                ;
              darwinPlatform = packageSet.applePlatform;
              system = system;
            };
          in
          {
            install-sdk = {
              type = "app";
              program = "${installer}/bin/apple-sdk-install";
              meta.description = "Install a user-provided Darwin SDK for xtool on Linux";
            };
          }
        )
      );

      devShells = forSupportedSystems (
        system:
        let
          packageSet = packageSetFor system;
        in
        {
          default = packageSet.pkgs.mkShellNoCC {
            packages = [ packageSet.toolchain ];
            shellHook = ''
              apple-sdk-doctor
            '';
          };
        }
      );

      checks = forSupportedSystems (
        system:
        let
          packageSet = packageSetFor system;
          inherit (packageSet) pkgs xtool;
        in
        {
          xtool = pkgs.runCommand "check-xtool" { } ''
            test -x ${xtool}/bin/xtool
            ${nixpkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
              ${xtool}/bin/xtool --version | grep -q '${releases.${latestVersion}.xtool.version}'
            ''}
            touch "$out"
          '';
        }
        // {
          sdk-layout = packageSet.pkgs.runCommand "check-apple-sdk-layout" { } ''
            test -x ${packageSet.toolchain}/bin/xtool
            test -x ${packageSet.toolchain}/bin/apple-sdk-doctor
            ${nixpkgs.lib.optionalString packageSet.isDarwin ''
              test -f ${packageSet.toolchain}/nix-support/setup-hook
            ''}
            ${nixpkgs.lib.optionalString (!packageSet.isDarwin) ''
              test -x ${packageSet.toolchain}/bin/swift
              test -f ${packageSet.toolchain}/nix-support/setup-hook
            ''}
            touch "$out"
          '';
        }
      );

      formatter = forSupportedSystems (system: (import nixpkgs { inherit system; }).nixfmt-tree);
    };
}
