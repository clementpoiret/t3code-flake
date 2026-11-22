{
  lib,
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
  tools =
    lib.optionals enableCodex [ codex ]
    ++ lib.optionals enableClaude [ claude-code ]
    ++ lib.optionals enableOpenCode [ opencode ]
    ++ lib.optionals enablePi [ pi-coding-agent ]
    ++ lib.optionals enableGrok [ grok-cli ]
    ++ lib.optionals enableKiro [ kiro-cli ]
    ++ lib.optionals enableAntigravity [ antigravity-cli ]
    ++ lib.optionals enableGit [ git ]
    ++ lib.optionals enableJujutsu [ jujutsu ]
    ++ lib.optionals enableGitHub [ gh ]
    ++ lib.optionals enableGitLab [ glab ]
    # T3 Code's Forgejo/Gitea integration drives both CLIs.
    ++ lib.optionals enableForgejo [
      tea
      forgejo-cli
    ]
    ++ lib.optionals enableAzureDevOps [
      (azure-cli.withExtensions [ azure-cli-extensions.azure-devops ])
    ]
    # Relay client; without one on PATH upstream downloads an unpatched binary.
    ++ lib.optionals enableCloudflared [ cloudflared ]
    ++ extraRuntimeTools;
in
lib.makeBinPath tools
