{
  description = "Nix package set for Apple platform development with xtool";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      xtoolSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      appleSystems = [ "aarch64-darwin" ];
      forXtoolSystems = nixpkgs.lib.genAttrs xtoolSystems;
      forAppleSystems = nixpkgs.lib.genAttrs appleSystems;
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
          xcodePlatform = pkgs.callPackage ./nix/xcode-platform.nix { inherit release; };
          sdkPackages = {
            inherit xtool;
            xcode-platform = xcodePlatform;
          };
          mkSdk = pkgs.callPackage ./nix/mk-sdk.nix { inherit release xtool; };
          sdk = componentsFn: mkSdk (componentsFn sdkPackages);
          fullSdk = sdk (components: builtins.attrValues components);
          versionSlug = builtins.replaceStrings [ "." ] [ "-" ] release.xcode.version;
        in
        {
          inherit
            pkgs
            release
            xtool
            xcodePlatform
            sdkPackages
            sdk
            fullSdk
            versionSlug
            ;
        };

      xtoolFor =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          release = releases.${latestVersion};
        in
        pkgs.callPackage ./nix/xtool.nix { inherit release; };
    in
    {
      lib = {
        inherit releases latestVersion;
        supportedAppleSystems = appleSystems;
        supportedXtoolSystems = xtoolSystems;
      };

      sdk = forAppleSystems (system: (packageSetFor system).sdk);

      overlays.default =
        final: _prev:
        {
          appleXtool = xtoolFor final.system;
        }
        // nixpkgs.lib.optionalAttrs (builtins.elem final.system appleSystems) {
          appleSdkPackages = (packageSetFor final.system).sdkPackages;
          appleSdk = (packageSetFor final.system).sdk;
        };

      packages = forXtoolSystems (
        system:
        let
          xtool = xtoolFor system;
        in
        {
          inherit xtool;
          default = xtool;
        }
        // nixpkgs.lib.optionalAttrs (builtins.elem system appleSystems) (
          let
            packageSet = packageSetFor system;
          in
          {
            sdk = packageSet.fullSdk;
            "sdk-${packageSet.versionSlug}" = packageSet.fullSdk;
            xcode-platform = packageSet.xcodePlatform;
            "xcode-platform-${packageSet.versionSlug}" = packageSet.xcodePlatform;
            default = packageSet.fullSdk;
          }
        )
      );

      apps = forAppleSystems (
        system:
        let
          packageSet = packageSetFor system;
          doctor = {
            type = "app";
            program = "${packageSet.xcodePlatform}/bin/apple-sdk-doctor";
            meta.description = "Validate the selected Xcode and Apple SDK BOM";
          };
        in
        {
          inherit doctor;
          "doctor-${packageSet.versionSlug}" = doctor;
        }
      );

      devShells = forAppleSystems (
        system:
        let
          packageSet = packageSetFor system;
        in
        {
          default = packageSet.pkgs.mkShellNoCC {
            packages = [ packageSet.fullSdk ];
            shellHook = ''
              apple-sdk-doctor
            '';
          };
        }
      );

      checks = forXtoolSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          xtool = xtoolFor system;
        in
        {
          xtool = pkgs.runCommand "check-xtool" { } ''
            ${xtool}/bin/xtool --version | grep -q '${releases.${latestVersion}.xtool.version}'
            touch "$out"
          '';
        }
        // nixpkgs.lib.optionalAttrs (builtins.elem system appleSystems) (
          let
            packageSet = packageSetFor system;
          in
          {
            sdk-layout = packageSet.pkgs.runCommand "check-apple-sdk-layout" { } ''
              test -x ${packageSet.fullSdk}/bin/xtool
              test -x ${packageSet.fullSdk}/bin/apple-sdk-doctor
              test -f ${packageSet.fullSdk}/nix-support/setup-hook
              touch "$out"
            '';
          }
        )
      );

      formatter = forXtoolSystems (system: (import nixpkgs { inherit system; }).nixfmt-tree);
    };
}
