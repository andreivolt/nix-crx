{
  description = "CRX3 signing and packaging for Chrome extensions";

  outputs = { self, ... }: {
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
