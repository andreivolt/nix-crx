{
  description = "CRX3 signing and packaging for Chrome extensions";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    # The packer/id scripts as runnable binaries, so consumers that sign outside
    # the build sandbox (e.g. nix-webext's activation-time signer reading the key
    # from sops) can `pack-crx3 <dir> <key.pem> <out.crx>` / `crx-id <key.pem>`
    # without depending on this flake's internal file paths.
    packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in {
        crx-tools = pkgs.runCommand "crx-tools" {
          nativeBuildInputs = [ pkgs.makeWrapper ];
        } ''
          mkdir -p $out/bin $out/libexec
          cp ${./pack-crx3.py} $out/libexec/pack-crx3.py
          cp ${./crx-id.py}    $out/libexec/crx-id.py
          makeWrapper ${pkgs.python3}/bin/python3 $out/bin/pack-crx3 \
            --add-flags $out/libexec/pack-crx3.py \
            --prefix PATH : ${pkgs.openssl}/bin
          makeWrapper ${pkgs.python3}/bin/python3 $out/bin/crx-id \
            --add-flags $out/libexec/crx-id.py \
            --prefix PATH : ${pkgs.openssl}/bin
        '';
        default = self.packages.${system}.crx-tools;
      });

    lib = {
      mkCrxPackage = { pkgs, extension, key, name ? extension.pname or "chrome-extension", extId ? null, version ? null }:
        let
          extId' = if extId != null then extId else
            builtins.readFile (pkgs.runCommand "${name}-ext-id" {
              nativeBuildInputs = [ pkgs.python3 pkgs.openssl ];
            } ''
              python3 ${./crx-id.py} ${key} > $out
            '');

          version' = if version != null then version else
            (builtins.fromJSON (builtins.readFile "${extension}/share/chromium-extension/manifest.json")).version;

          crx = pkgs.runCommand "${name}-crx" {
            nativeBuildInputs = [ pkgs.python3 pkgs.openssl ];
          } ''
            mkdir -p $out
            python3 ${./pack-crx3.py} ${extension}/share/chromium-extension ${key} $out/extension.crx
          '';
        in {
          extId = extId';

          json = pkgs.writeText "${extId'}.json" (builtins.toJSON {
            external_crx = "${crx}/extension.crx";
            external_version = version';
          });

          package = pkgs.linkFarm "${name}-crx" [
            { name = "share/chromium/extensions/${extId'}.json";
              path = pkgs.writeText "${extId'}.json" (builtins.toJSON {
                external_crx = "${crx}/extension.crx";
                external_version = version';
              });
            }
          ];
        };
    };
  };
}
