{
  "26.6" = {
    xcode = {
      version = "26.6";
      build = "17F113";
      developerDir = "/Applications/Xcode.app/Contents/Developer";
    };

    swift = {
      version = "6.3.3";
      distribution = {
        name = "ubuntu";
        version = "24.04";
        codename = "noble";
      };
      sources = {
        aarch64-linux = {
          url = "https://download.swift.org/swift-6.3.3-release/ubuntu2404-aarch64/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE-ubuntu24.04-aarch64.tar.gz";
          hash = "sha256-RxJjlUKWU/p2jTcGVYduwbaPapXHiE9eTxeXABQcm38=";
        };
        x86_64-linux = {
          url = "https://download.swift.org/swift-6.3.3-release/ubuntu2404/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE-ubuntu24.04.tar.gz";
          hash = "sha256-2oJypf3czWWxUp7Q5S4EUm4urdQjfVjWIg7+uXPGzRk=";
        };
      };
    };

    darwinSdk = {
      epoch = 3;
      darwinToolsVersion = "1.1.0";
      openAppleMacrosVersion = "1.3.0";
    };

    sdks = {
      driverkit = "25.5";
      macosx = "26.5";
      iphoneos = "26.5";
      iphonesimulator = "26.5";
      appletvos = "26.5";
      appletvsimulator = "26.5";
      watchos = "26.5";
      watchsimulator = "26.5";
      xros = "26.5";
      xrsimulator = "26.5";
    };

    xtool = {
      version = "1.21.0";
      sources = {
        aarch64-darwin = {
          url = "https://github.com/xtool-org/xtool/releases/download/1.21.0/xtool.app.zip";
          hash = "sha256-M7su8S3j8qz7Xrg4X8oN6d86mChi7AZxhaWeiuGLZOg=";
        };
        aarch64-linux = {
          url = "https://github.com/xtool-org/xtool/releases/download/1.21.0/xtool-aarch64.AppImage";
          hash = "sha256-Rw1ViAN53paWoEj0KToLBaf8Q766Qj/+bClKSXXc6/c=";
        };
        x86_64-linux = {
          url = "https://github.com/xtool-org/xtool/releases/download/1.21.0/xtool-x86_64.AppImage";
          hash = "sha256-4id+Wbsv2ptIfLx3rQgOorA3C7dArA8CzEL6KKJy06U=";
        };
      };
    };
  };
}
