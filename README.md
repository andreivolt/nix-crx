# nix-crx

Nix flake library for signing and packaging Chrome extensions as CRX3 files. Derives the extension ID from a PEM key at build time and produces Chromium's [external extension JSON](https://developer.chrome.com/docs/extensions/how-to/distribute/install-extensions#preferences) for automatic installation.

## Usage

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-crx.url = "github:andreivolt/nix-crx";
  };

  outputs = { self, nixpkgs, nix-crx }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      extension = pkgs.stdenv.mkDerivation {
        pname = "my-extension";
        version = "1.0.0";
        src = ./extension;
        installPhase = ''
          mkdir -p $out/share/chromium-extension
          cp -r * $out/share/chromium-extension/
        '';
      };

      crxPkg = nix-crx.lib.mkCrxPackage {
        inherit pkgs extension;
        key = ./keys/signing.pem;
      };
    in {
      packages.x86_64-linux.default = crxPkg.package;
    };
}
```

## `mkCrxPackage`

### Inputs

| Parameter | Type | Description |
|-----------|------|-------------|
| `pkgs` | pkgset | Nixpkgs package set |
| `extension` | derivation | Must have extension files at `$out/share/chromium-extension/` |
| `key` | path | RSA private key (PEM) for signing |
| `name` | string | Package name prefix (default: `extension.pname`) |

### Outputs

| Attribute | Type | Description |
|-----------|------|-------------|
| `package` | derivation | `linkFarm` with `share/chromium/extensions/${extId}.json` |
| `extId` | string | Extension ID derived from the PEM key |
| `json` | derivation | The external extension JSON file |

### Native messaging

For extensions with a native messaging host, use `extId` to set `allowed_origins`:

```nix
crxPkg = nix-crx.lib.mkCrxPackage { inherit pkgs extension; key = ./keys/signing.pem; };

default = pkgs.symlinkJoin {
  name = "my-extension";
  paths = [
    extension
    crxPkg.package
    (pkgs.linkFarm "my-extension-native" [
      { name = "etc/chromium/native-messaging-hosts/com.example.host.json";
        path = pkgs.writeText "com.example.host.json" (builtins.toJSON {
          name = "com.example.host";
          description = "My native messaging host";
          path = "${extension}/bin/host";
          type = "stdio";
          allowed_origins = [ "chrome-extension://${crxPkg.extId}/" ];
        });
      }
    ])
  ];
};
```

## Generating a signing key

```sh
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out keys/signing.pem
```

The extension ID is deterministically derived from this key. Keep the same key to preserve the extension ID across rebuilds.
