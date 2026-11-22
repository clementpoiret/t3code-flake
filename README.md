# T3 Code for NixOS

This flake packages the official [T3 Code](https://github.com/pingdotgg/t3code) Linux releases. `t3code` contains the
self-contained CLI, bundled web client, and native modules. `t3code-desktop` wraps the official AppImage and installs
its desktop entry and icons. Both packages support `x86_64-linux` and `aarch64-linux`.

The only release metadata is [sources.json](./sources.json). CLI archives are checked against upstream `SHA256SUMS`
before their Nix hashes are recorded. `flake.lock` pins two Nixpkgs inputs: stable `nixpkgs` builds the packages, and `nixpkgs-unstable` provides the runtime
tools and is refreshed with each T3 Code release.

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

The tools come from this flake's `nixpkgs-unstable` input rather than from the Nixpkgs that builds T3 Code, because
agent CLIs release far more often than a stable channel follows. To use your own Nixpkgs for them instead, set
`inputs.t3code.inputs.nixpkgs-unstable.follows = "nixpkgs";`, or replace a single tool with any package, including one
from another flake, for example `t3code.override { codex = inputs.other.packages.${pkgs.system}.codex; }`.

The direct flake packages allow the unfree `claude-code`, `kiro-cli`, and `antigravity-cli` only when their option is
enabled. With the overlay, the tools are evaluated under your package set's Nixpkgs `config`, so it must permit the
unfree tools you enable.

| Override            | Default | Program                                  |
| ------------------- | ------- | ---------------------------------------- |
| `enableCodex`       | `true`  | `codex`                                  |
| `enableClaude`      | `false` | `claude` from `claude-code` (unfree)     |
| `enableOpenCode`    | `false` | `opencode`                               |
| `enablePi`          | `false` | `pi` from `pi-coding-agent`              |
| `enableGrok`        | `false` | `grok` from `grok-cli`                   |
| `enableKiro`        | `false` | `kiro-cli` (unfree)                      |
| `enableAntigravity` | `false` | `agy` from `antigravity-cli` (unfree)    |
| `enableGit`         | `true`  | `git`                                    |
| `enableJujutsu`     | `false` | `jj` from `jujutsu`                      |
| `enableGitHub`      | `true`  | `gh`                                     |
| `enableGitLab`      | `true`  | `glab`                                   |
| `enableForgejo`     | `false` | `tea` and `fj` from `forgejo-cli`        |
| `enableAzureDevOps` | `false` | `az` with the Azure DevOps extension     |
| `enableCloudflared` | `false` | `cloudflared`, T3 Code's relay client    |
| `extraRuntimeTools` | `[ ]`   | any further packages to add to `PATH`    |

For desktop use, install `packages.${pkgs.system}.t3code-desktop` or run
`nix run github:OWNER/REPOSITORY#t3code-desktop`. Its app launcher is `$out/bin/t3code-desktop`; the upstream desktop
file and icons are placed under `$out/share/applications` and `$out/share/icons`. The package wraps the AppImage with
Nixpkgs' `appimageTools.wrapType2` and passes upstream's `--no-sandbox` launch flag. You can override its runtime tools
in the same way as the CLI.

## Update T3 Code

The scheduled [update workflow](./.github/workflows/update-t3code.yml) checks GitHub's latest stable release daily at
05:17 UTC. On a new version it verifies that all four Linux assets and `SHA256SUMS` exist, downloads both CLI archives,
checks each against `SHA256SUMS`, hashes the two AppImages, and atomically replaces `sources.json`. It then refreshes
the `nixpkgs-unstable` entry of `flake.lock` so the runtime tools keep pace with the release; the stable `nixpkgs` entry
is left alone. Native x64 and ARM64 jobs run flake checks, CLI smoke tests, and desktop builds; only when both pass are
`sources.json` and `flake.lock` committed and pushed directly to `main`, with no pull request. The push is refused if
`main` moved after validation, and the next run retries.

To run maintenance locally:

```sh
nix develop
./scripts/update-t3code
nix flake check
```

Pass an exact stable version such as `./scripts/update-t3code 0.1.11` to target that release. A version already recorded
in `sources.json` is a no-op and leaves `flake.lock` alone. Update stable Nixpkgs independently with
`nix flake update nixpkgs`, or refresh the runtime tools between releases with `nix flake update nixpkgs-unstable`.

Upstream provides `t3 update`, which downloads a mutable runtime under the user's T3 home and repoints launchers owned
by upstream's installer. The Nix store package is immutable, so update this flake's input after the update lands on
`main` instead. We found no documented upstream switch to disable the CLI self-update command and do not patch it.

Upstream's `t3 service install` also downloads a standalone archive into `~/.t3/runtime/versions` and creates a systemd
user unit on Linux. That service is separate from this Nix package and can enable user lingering. Its downloaded
executable is not Nix ELF-patched, so on NixOS it may require `nix-ld`. For a service managed by Nix, define a
declarative user unit that executes the packaged `$out/bin/t3` with your chosen server flags. Packaging checks never run
`service install`, start a server, or modify a user service.

## GitHub setup

The update workflow uses only `GITHUB_TOKEN`; its publish job receives `contents: write` to push the update commit to
`main`, while download and test jobs use read access. No personal access token is required.

`main` must accept direct pushes from GitHub Actions: a branch protection rule or ruleset that requires pull requests
or status checks will reject the push unless it lets `github-actions[bot]` bypass it.
[Pushes made with `GITHUB_TOKEN` do not trigger other workflows](https://docs.github.com/en/actions/concepts/security/github_token),
so the normal CI workflow does not run on update commits; the update workflow validates both architectures itself
before pushing.

The normal [CI workflow](./.github/workflows/ci.yml) runs on pushes to `main` and pull requests using native
`ubuntu-24.04` and `ubuntu-24.04-arm` runners.
The desktop flake check verifies the built launcher, desktop entry, and icon without running the AppImage. Its FHS
launcher uses `bwrap`, whose UID map setup is denied inside the ARM runner's Nix build sandbox. Both native CI jobs
still build the desktop package.

## Packaging notes

The CLI executable is at the top level of each `t3-<version>-linux-*.tar.gz` archive. The package preserves the
adjacent web client and native modules under `$out/libexec/t3code`, and its `$out/bin/t3` wrapper adds optional tools to
`PATH`. The executable needs a Nix store ELF interpreter and the GCC runtime's `libatomic` and `libstdc++`;
`autoPatchelfHook` patches the glibc executables and modules, resolving bundled sibling libraries (such as
transcribe-cpp's `libggml-*.so`) and its Vulkan backend's `libvulkan` from `vulkan-loader`. Since v0.1.x upstream
names the AppImages `T3-Code-<arch>.AppImage`; the updater also accepts the older versioned names. Stripping is disabled because Node's single executable
application embeds its payload in an ELF note that `strip -S` damages.
