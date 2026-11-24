{
  description = "Harbor for Linux (stable and beta binary packages)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      versions = builtins.fromJSON (builtins.readFile ./nix/version.json);
      mkHarbor = pname: info: pkgs.callPackage ./nix/package.nix { inherit pname info; };
    in {
      packages.${system} = rec {
        beta = mkHarbor "harbor-stremio-beta" versions.beta;
        stable = mkHarbor "harbor-stremio" versions.stable;
        default = beta;
      };
      apps.${system} = {
        default = self.apps.${system}.beta;
        beta = {
          type = "app";
          program = "${self.packages.${system}.beta}/bin/harbor";
        };
        stable = {
          type = "app";
          program = "${self.packages.${system}.stable}/bin/harbor";
        };
      };
    };
}
