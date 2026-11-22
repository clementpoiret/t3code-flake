{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  vulkan-loader,
  sources,
  codex,
  claude-code,
  opencode,
  pi-coding-agent,
  grok-cli,
  kiro-cli,
  antigravity-cli,
  git,
  jujutsu,
  gh,
  glab,
  tea,
  forgejo-cli,
  azure-cli,
  azure-cli-extensions,
  cloudflared,
  enableCodex ? true,
  enableClaude ? false,
  enableOpenCode ? false,
  enablePi ? false,
  enableGrok ? false,
  enableKiro ? false,
  enableAntigravity ? false,
  enableGit ? true,
  enableJujutsu ? false,
  enableGitHub ? true,
  enableGitLab ? true,
  enableForgejo ? false,
  enableAzureDevOps ? false,
  enableCloudflared ? false,
  extraRuntimeTools ? [ ],
}:
let
  system = stdenv.hostPlatform.system;
  asset = sources.cli.${system};
  runtimePath = import ./runtime-tools.nix {
    inherit
      lib
      codex
      claude-code
      opencode
      pi-coding-agent
      grok-cli
      kiro-cli
      antigravity-cli
      git
      jujutsu
      gh
      glab
      tea
      forgejo-cli
      azure-cli
      azure-cli-extensions
      cloudflared
      enableCodex
      enableClaude
      enableOpenCode
      enablePi
      enableGrok
      enableKiro
      enableAntigravity
      enableGit
      enableJujutsu
      enableGitHub
      enableGitLab
      enableForgejo
      enableAzureDevOps
      enableCloudflared
      extraRuntimeTools
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
  buildInputs = [
    stdenv.cc.cc.lib
    # Needed by the bundled transcribe-cpp Vulkan backend.
    vulkan-loader
  ];

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
    nativeModules=()
    while IFS= read -r -d ''' file; do
      nativeModules+=("$file")
      # Bundled libraries (e.g. libggml-*.so) link against their siblings.
      addAutoPatchelfSearchPath --no-recurse "$(dirname "$file")"
    done < <(find "$out/libexec/t3code/node_modules" -type f \
      \( -name '*.node' -o -name '*.so' \) ! -path '*musl*' -print0)
    autoPatchelf "$out/libexec/t3code/t3"
    autoPatchelf "$out/libexec/t3code/resource-monitor"
    for file in "''${nativeModules[@]}"; do
      autoPatchelf "$file"
    done
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
