{
  description = "T3 Code official Linux release packages";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      sources = builtins.fromJSON (builtins.readFile ./sources.json);
      packagePkgs =
        system:
        import nixpkgs {
          inherit system;
          # Claude Code is unfree; only permit it when an override selects it.
          config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "claude-code";
          overlays = [ self.overlays.default ];
        };
    in
    {
      overlays.default = final: prev: {
        t3code = final.callPackage ./package.nix { inherit sources; };
        t3code-desktop = final.callPackage ./desktop.nix { inherit sources; };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = packagePkgs system;
        in
        {
          inherit (pkgs) t3code t3code-desktop;
          default = pkgs.t3code;
        }
      );

      apps = forAllSystems (
        system:
        let
          packages = self.packages.${system};
        in
        {
          default = self.apps.${system}.t3code;
          t3code = {
            type = "app";
            program = "${packages.t3code}/bin/t3";
            meta.description = "Run the T3 Code CLI";
          };
          t3code-desktop = {
            type = "app";
            program = "${packages.t3code-desktop}/bin/t3code-desktop";
            meta.description = "Run the T3 Code desktop application";
          };
        }
      );

      formatter = forAllSystems (system: (import nixpkgs { inherit system; }).nixfmt);

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nix
              gh
              jq
              curl
              coreutils
              git
              gnused
              gnutar
            ];
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = packagePkgs system;
        in
        {
          package = pkgs.t3code;
          cli = pkgs.runCommand "t3code-cli-check" { nativeBuildInputs = [ pkgs.t3code ]; } ''
            HOME="$(mktemp -d)"
            export HOME
            test -x ${pkgs.t3code}/bin/t3
            version="$(t3 --version)"
            test "$version" = "t3 v${sources.version}"
            t3 --help > /dev/null
            touch "$out"
          '';
          desktop = pkgs.runCommand "t3code-desktop-check" { } ''
            test -x ${pkgs.t3code-desktop}/bin/t3code-desktop
            test -x ${pkgs.t3code-desktop}/bin/t3code-desktop-unwrapped
            ${pkgs.bash}/bin/bash -n ${pkgs.t3code-desktop}/bin/t3code-desktop
            grep -Fx 'Exec=t3code-desktop %U' ${pkgs.t3code-desktop}/share/applications/t3code.desktop > /dev/null
            test -f ${pkgs.t3code-desktop}/share/icons/hicolor/512x512/apps/t3code.png
            touch "$out"
          '';
        }
      );
    };
}
