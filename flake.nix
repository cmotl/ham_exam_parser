{
  description = "Ham Exam Parser - ARRL question pool parser";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            git
            neovim
            ruby_3_3
            pkg-config
            libxml2
            libxslt
            zlib
            librsvg
          ];

          shellHook = ''
            export GEM_HOME="$PWD/vendor/bundle"
            export GEM_PATH="$GEM_HOME"
            export PATH="$GEM_HOME/bin:$PATH"
            export BUNDLE_PATH="$GEM_HOME"
          '';
        };
      });
}
