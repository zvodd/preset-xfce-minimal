{
  description = "preset-xfce-minimal: minimal XFCE4 preset";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in {
      packages = forAll (pkgs: {
        default = pkgs.writeShellScriptBin "preset-xfce-minimal" (builtins.readFile ./preset-xfce-minimal.sh);
      });
      apps = forAll (pkgs: {
        default = { type = "app"; program = "${self.packages.${pkgs.system}.default}/bin/preset-xfce-minimal"; };
      });
    };
}
