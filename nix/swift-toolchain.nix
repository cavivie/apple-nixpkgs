{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  curl,
  icu,
  libedit,
  libuuid,
  libxml2,
  ncurses,
  python3,
  sqlite,
  z3,
  zlib,
  zstd,
  release,
}:

let
  source =
    release.swift.sources.${stdenv.hostPlatform.system}
      or (throw "Swift ${release.swift.version} is unavailable for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "apple-swift-toolchain";
  version = release.swift.version;

  src = fetchurl { inherit (source) url hash; };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    stdenv.cc.cc.lib
    curl
    icu
    libedit
    libuuid
    libxml2
    ncurses
    python3
    sqlite
    z3
    zlib
    zstd
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R usr/. "$out/"
    runHook postInstall
  '';

  # The official bundle contains optional debugger and plugin binaries whose
  # distro-specific dependencies are not required by xtool builds.
  autoPatchelfIgnoreMissingDeps = true;

  passthru = { inherit release; };

  meta = {
    description = "Swift.org host toolchain matched to the selected Xcode release";
    homepage = "https://www.swift.org/install/linux/";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames release.swift.sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
