{
  description = "Build a cargo project";
  # If there will be errors with building bevy through crane consider using https://github.com/ipetkov/crane/discussions/502

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    crane.url = "github:ipetkov/crane";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-analyzer-src.follows = "";
    };
    flake-utils.url = "github:numtide/flake-utils";
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, crane, fenix, flake-utils, advisory-db, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        inherit (pkgs) lib;

        craneLib = crane.mkLib pkgs;
        src = craneLib.cleanCargoSource ./.;

        # Common arguments can be set here to avoid repeating them later
        commonArgs = {
          inherit src;
          strictDeps = true;

          nativeBuildInputs = with pkgs; [
            pkg-config
            makeWrapper
          ];

          buildInputs = with pkgs; [
            alsa-lib
            libxkbcommon
            udev
            vulkan-loader
            wayland # To use the wayland feature
          ] ++ (with xorg; [
            libX11
            libXcursor
            libXi
            libXrandr # To use the x11 feature
          ]) ++ lib.optionals pkgs.stdenv.isDarwin [
            # Additional darwin specific inputs can be set here
            pkgs.libiconv
          ];

          # Additional environment variables can be set directly
          # MY_CUSTOM_VAR = "some value";
        };

        craneLibLLvmTools = craneLib.overrideToolchain
          (fenix.packages.${system}.complete.withComponents [
            "cargo"
            "rust-analyzer"
            "llvm-tools"
            "rustc"
          ]);

        # Build *just* the cargo dependencies, so we can reuse
        # all of that work (e.g. via cachix) when running in CI
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        # Build the actual crate itself, reusing the dependency
        # artifacts from above.
        minicrab = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
          pname = "minicrab";
          postInstall = ''
            wrapProgram $out/bin/minicrab \
              --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath commonArgs.buildInputs} \
              --prefix XCURSOR_THEME : "Adwaita"
            wrapProgram $out/bin/minicrab-server \
              --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath commonArgs.buildInputs} \
              --prefix XCURSOR_THEME : "Adwaita"
            mkdir -p $out/bin/assets
            cp -a assets $out/bin
          '';
        });
      in
      {
        checks = {
          # Build the crate as part of `nix flake check` for convenience
          inherit minicrab;

          # Run clippy (and deny all warnings) on the crate source,
          # again, reusing the dependency artifacts from above.
          #
          # Note that this is done as a separate derivation so that
          # we can block the CI if there are issues here, but not
          # prevent downstream consumers from building our crate by itself.
          minicrab-clippy = craneLib.cargoClippy (commonArgs // {
            inherit cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          });

          minicrab-doc = craneLib.cargoDoc (commonArgs // {
            inherit cargoArtifacts;
          });

          # Check formatting
          minicrab-fmt = craneLib.cargoFmt {
            inherit src;
          };

          minicrab-toml-fmt = craneLib.taploFmt {
            src = pkgs.lib.sources.sourceFilesBySuffices src [ ".toml" ];
            # taplo arguments can be further customized below as needed
            # taploExtraArgs = "--config ./taplo.toml";
          };

          # Audit dependencies
          minicrab-audit = craneLib.cargoAudit {
            inherit src advisory-db;
          };

          # Audit licenses
          minicrab-deny = craneLib.cargoDeny {
            inherit src;
          };

          # Run tests with cargo-nextest
          # Consider setting `doCheck = false` on `minicrab` if you do not want
          # the tests to run twice
          minicrab-nextest = craneLib.cargoNextest (commonArgs // {
            inherit cargoArtifacts;
            partitions = 1;
            partitionType = "count";
            cargoNextestPartitionsExtraArgs = "--no-tests=pass";
          });
        };

        packages = {
          default = minicrab;
        } // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
          minicrab-llvm-coverage = craneLibLLvmTools.cargoLlvmCov (commonArgs // {
            inherit cargoArtifacts;
          });
        };

        apps = {
          default = flake-utils.lib.mkApp {
            drv = minicrab;
          };
          minicrab-server = flake-utils.lib.mkApp {
            drv = minicrab;
            name = "minicrab-server";
            exePath = "/bin/minicrab-server";
          };
        };

        devShells.default = craneLib.devShell {
          # Inherit inputs from checks.
          checks = self.checks.${system};

          # Env var to fix rust-analyzer
          RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";

          # Fix libx11 errors
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath commonArgs.buildInputs}";
          XCURSOR_THEME = "Adwaita";

          packages = with pkgs; [
            rust-analyzer
          ];
        };
      });
}
