{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
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
  asset = sources.desktop.${stdenv.hostPlatform.system};
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${sources.version}/${asset.asset}";
    hash = asset.hash;
  };
  extracted = appimageTools.extract {
    pname = "t3code-desktop";
    version = sources.version;
    inherit src;
  };
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
appimageTools.wrapType2 {
  pname = "t3code-desktop";
  version = sources.version;
  inherit src;

  extraInstallCommands = ''
    mkdir -p "$out/share/applications" "$out/share/icons"
    cp ${extracted}/t3code.desktop "$out/share/applications/t3code.desktop"
    substituteInPlace "$out/share/applications/t3code.desktop" \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=t3code-desktop %U'
    cp -R ${extracted}/usr/share/icons/hicolor "$out/share/icons/"

    mv "$out/bin/t3code-desktop" "$out/bin/t3code-desktop-unwrapped"
    cat > "$out/bin/t3code-desktop" <<EOF
    #!${stdenv.shell}
    export PATH=${lib.escapeShellArg runtimePath}:\$PATH
    if [ "\$ELECTRON_RUN_AS_NODE" = "1" ]; then
      exec "$out/bin/t3code-desktop-unwrapped" "\$@"
    fi
    exec "$out/bin/t3code-desktop-unwrapped" --no-sandbox "\$@"
    EOF
    chmod +x "$out/bin/t3code-desktop"
  '';

  meta = {
    description = "T3 Code desktop application";
    homepage = "https://github.com/pingdotgg/t3code";
    license = lib.licenses.mit;
    mainProgram = "t3code-desktop";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
