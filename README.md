# T3 Code for NixOS

This flake packages the official [T3 Code](https://github.com/pingdotgg/t3code) Linux releases. `t3code` contains the
self-contained CLI, bundled web client, and native modules. `t3code-desktop` wraps the official AppImage and installs
its desktop entry and icons. Both packages support `x86_64-linux` and `aarch64-linux`.

The only release metadata is [sources.json](./sources.json). CLI archives are checked against upstream `SHA256SUMS`
before their Nix hashes are recorded. `flake.lock` pins Nixpkgs separately from T3 Code releases.

## Install

Add the flake as an input:

```nix
{
  inputs.t3code.url = "github:clementpoiret/t3code-flake";

  outputs = { nixpkgs, t3code, ... }: {
    # Use t3code.packages.${system}.t3code in your configuration.
  };
}
```

NixOS module example, with `inputs` passed to the module:

```nix
{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.t3code.packages.${pkgs.system}.t3code
  ];
}
```

Home Manager module example:

```nix
{ inputs, pkgs, ... }:
{
  home.packages = [
    (inputs.t3code.packages.${pkgs.system}.t3code.override {
      enableClaude = true;
      enableJujutsu = true;
    })
  ];
}
```

You can also apply `inputs.t3code.overlays.default` to Nixpkgs and use `pkgs.t3code` or `pkgs.t3code-desktop`. Without
installing, run `nix run github:OWNER/REPOSITORY -- --version`.

## Runtime tools

The `/bin/t3` launcher adds selected programs to its `PATH`. The desktop launcher uses the same options. Authentication
and provider settings stay in your user environment.

The direct flake packages allow Nixpkgs' unfree `claude-code` only when `enableClaude = true`; if you use the overlay
with your own Nixpkgs package set, that package set must also permit `claude-code`.

| Override            | Default | Program                              |
| ------------------- | ------- | ------------------------------------ |
| `enableCodex`       | `true`  | `codex`                              |
| `enableClaude`      | `false` | `claude-code`                        |
| `enableGit`         | `true`  | `git`                                |
| `enableJujutsu`     | `false` | `jj` from `jujutsu`                  |
| `enableGitHub`      | `true`  | `gh`                                 |
| `enableGitLab`      | `true`  | `glab`                               |
| `enableAzureDevOps` | `false` | `az` with the Azure DevOps extension |

For desktop use, install `packages.${pkgs.system}.t3code-desktop` or run
`nix run github:OWNER/REPOSITORY#t3code-desktop`. Its app launcher is `$out/bin/t3code-desktop`; the upstream desktop
file and icons are placed under `$out/share/applications` and `$out/share/icons`. The package wraps the AppImage with
Nixpkgs' `appimageTools.wrapType2` and passes upstream's `--no-sandbox` launch flag. You can override its runtime tools
in the same way as the CLI.

## Update T3 Code

The scheduled [update workflow](./.github/workflows/update-t3code.yml) checks GitHub's latest stable release daily at
05:17 UTC. On a new version it verifies that all four Linux assets and `SHA256SUMS` exist, downloads both CLI archives,
checks each against `SHA256SUMS`, hashes the two AppImages, and atomically replaces `sources.json`. It leaves
`flake.lock` untouched. Native x64 and ARM64 jobs run flake checks, CLI smoke tests, and desktop builds before a PR is
opened or updated on `automation/update-t3code`.

To run maintenance locally:

```sh
nix develop
./scripts/update-t3code
nix flake check
```

Pass an exact stable version such as `./scripts/update-t3code 0.0.42` to target that release. A version already recorded
in `sources.json` is a no-op. Update Nixpkgs independently with `nix flake update nixpkgs`; a T3 Code update does not
change the lock file.

Upstream provides `t3 update`, which downloads a mutable runtime under the user's T3 home and repoints launchers owned
by upstream's installer. The Nix store package is immutable, so update this flake's input after its release PR is merged
instead. We found no documented upstream switch to disable the CLI self-update command and do not patch it.

Upstream's `t3 service install` also downloads a standalone archive into `~/.t3/runtime/versions` and creates a systemd
user unit on Linux. That service is separate from this Nix package and can enable user lingering. Its downloaded
executable is not Nix ELF-patched, so on NixOS it may require `nix-ld`. For a service managed by Nix, define a
declarative user unit that executes the packaged `$out/bin/t3` with your chosen server flags. Packaging checks never run
`service install`, start a server, or modify a user service.

## GitHub setup

Enable
[**Settings → Actions → General → Allow GitHub Actions to create and approve pull requests**](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository).
The update workflow uses only `GITHUB_TOKEN`; its proposal job receives `contents: write` and `pull-requests: write`,
while download and test jobs use read access.
[GitHub may leave CI on a `GITHUB_TOKEN`-created PR waiting for approval](https://docs.github.com/en/actions/concepts/security/github_token),
so the update workflow validates both architectures before creating the PR. If branch protection requires the separate
PR CI check, a repository writer can approve that run from the PR. No personal access token is required.

The normal [CI workflow](./.github/workflows/ci.yml) runs on pushes to `main` and pull requests using native
`ubuntu-24.04` and `ubuntu-24.04-arm` runners.

## Packaging notes

The v0.0.42 CLI executable is at the top level of each `t3-<version>-linux-*.tar.gz` archive. The package preserves the
adjacent web client and native modules under `$out/libexec/t3code`, and its `$out/bin/t3` wrapper adds optional tools to
`PATH`. The executable needs a Nix store ELF interpreter and the GCC runtime's `libatomic` and `libstdc++`;
`autoPatchelfHook` patches the glibc executables and modules. Stripping is disabled because Node's single executable
application embeds its payload in an ELF note that `strip -S` damages.
