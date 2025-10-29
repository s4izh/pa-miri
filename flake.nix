{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
  };
  outputs = { nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      python-pkgs = with pkgs; [
        (python312.withPackages (ps: [
          ps.argcomplete
        ]))
      ];

    in rec {
      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [
          gnumake
          libgcc
          zlib
          iverilog
          verilator
          gtkwave
          surfer
          svls
          universal-ctags
          python-pkgs
          sv-lang
          ninja
          lua
        ];
      };
    }
  );
}
