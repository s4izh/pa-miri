{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    izumi = {
      url = "git+https://github.com/Izumi-visualizer/izumi?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, flake-utils, izumi, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      python-pkgs = with pkgs; [
        (python312.withPackages (ps: [
          ps.argcomplete
        ]))
      ];

      konata-bin = pkgs.stdenv.mkDerivation rec {
        pname = "konata";
        version = "0.39";

        src = pkgs.fetchzip {
          url = "https://github.com/shioyadan/Konata/releases/download/v${version}/konata-linux-x64.tar.gz";
          hash = "sha256-lwOFdDAs9pEceIyyCZYk2LSI53ti+j7GL/5nrmoyW1Y="; 
          stripRoot = false;
        };

        nativeBuildInputs = [ pkgs.makeWrapper ];

        # installPhase = ''
        #   mkdir -p $out/bin $out/share/konata
        #   cp -r konata-linux-x64/resources/app.asar $out/share/konata/
        #   makeWrapper ${pkgs.electron}/bin/electron $out/bin/konata \
        #     --add-flags "$out/share/konata/app.asar" \
        #     --add-flags "--no-sandbox"
        # '';

        installPhase = ''
          mkdir -p $out/opt/konata
          cp -r * $out/opt/konata/
          chmod +x $out/opt/konata/konata-linux-x64/konata
        '';
      };

      konata = pkgs.buildFHSEnv {
        name = "konata";
        targetPkgs = pkgs: (pkgs.appimageTools.defaultFhsEnvArgs.targetPkgs pkgs) ++ (with pkgs; [
          udev
          libxshmfence
          glib
          nss
          nspr
          at-spi2-atk
          at-spi2-core
          atk
          cups
          dbus
          libdrm
          pango
          cairo
          gtk3
          xorg.libX11
          xorg.libXcomposite
          alsa-lib
          expat
        #   fontconfig
        #   freetype
        #   gdk-pixbuf
        #   glib
          libxkbcommon
          xorg.libXdamage
          xorg.libXext
          xorg.libXfixes
        #   xorg.libXi
          xorg.libXrandr
        #   xorg.libXrender
        #   xorg.libXScrnSaver
        #   xorg.libXtst
          xorg.libxcb
          libgbm
        ]);
        runScript = "${konata-bin}/opt/konata/konata-linux-x64/konata";
      };

      riscv-pkgs = pkgs.pkgsCross.riscv32-embedded.buildPackages;

    in rec {
      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [
          gnumake
          libgcc
          zlib
          iverilog
          verilator
          # gtkwave -- let engineers use their own version
          surfer # --- let engineers use their own version
          svls
          universal-ctags
          python-pkgs
          sv-lang
          ninja
          lua

          konata
          izumi.packages.${system}.default

          cargo
          rustc

          riscv-pkgs.gcc
        ];
        shellHook = ''
          source set_env.sh
          alias harness-dev="cd $PROJ_DIR/harness && cargo build && cd .. && ./harness/target/debug/harness"
          alias harness="cd $PROJ_DIR && ./harness/target/debug/harness"
        '';
      };
    }
  );
}
