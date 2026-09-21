{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  sources,
  codex,
  claude-code,
  git,
  jujutsu,
  gh,
  glab,
  azure-cli,
  azure-cli-extensions,
  enableCodex ? true,
  enableClaude ? false,
  enableGit ? true,
  enableJujutsu ? false,
  enableGitHub ? true,
  enableGitLab ? true,
  enableAzureDevOps ? false,
}:
let
  system = stdenv.hostPlatform.system;
  asset = sources.cli.${system};
  runtimePath = import ./runtime-tools.nix {
    inherit
      lib
      codex
      claude-code
      git
      jujutsu
      gh
      glab
      azure-cli
      azure-cli-extensions
      enableCodex
      enableClaude
      enableGit
      enableJujutsu
      enableGitHub
      enableGitLab
      enableAzureDevOps
      ;
  };
in
stdenv.mkDerivation {
  pname = "t3code";
  version = sources.version;

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${sources.version}/${asset.asset}";
    hash = asset.hash;
  };
  sourceRoot = lib.removeSuffix ".tar.gz" asset.asset;

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];
  buildInputs = [ stdenv.cc.cc.lib ];

  dontBuild = true;
  dontAutoPatchelf = true;
  # Node's SEA payload lives in an ELF note; strip -S corrupts the executable.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec/t3code" "$out/bin"
    cp -R . "$out/libexec/t3code/"
    makeWrapper "$out/libexec/t3code/t3" "$out/bin/t3" \
      --prefix PATH : ${lib.escapeShellArg runtimePath}
    runHook postInstall
  '';

  postFixup = ''
    # The archive also has musl modules, which are not used on NixOS.
    autoPatchelf "$out/libexec/t3code/t3"
    autoPatchelf "$out/libexec/t3code/resource-monitor"
    while IFS= read -r -d ''' file; do
      autoPatchelf "$file"
    done < <(find "$out/libexec/t3code/node_modules" -type f \
      \( -name '*.node' -o -name '*.so' \) ! -path '*musl*' -print0)
  '';

  meta = {
    description = "T3 Code CLI and bundled web client";
    homepage = "https://github.com/pingdotgg/t3code";
    license = lib.licenses.mit;
    mainProgram = "t3";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
