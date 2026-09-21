{
  lib,
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
  tools =
    lib.optionals enableCodex [ codex ]
    ++ lib.optionals enableClaude [ claude-code ]
    ++ lib.optionals enableGit [ git ]
    ++ lib.optionals enableJujutsu [ jujutsu ]
    ++ lib.optionals enableGitHub [ gh ]
    ++ lib.optionals enableGitLab [ glab ]
    ++ lib.optionals enableAzureDevOps [
      (azure-cli.withExtensions [ azure-cli-extensions.azure-devops ])
    ];
in
lib.makeBinPath tools
