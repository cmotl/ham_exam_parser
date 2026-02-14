{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
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
}
