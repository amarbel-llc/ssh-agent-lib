{
  description = "A collection of types for writing custom SSH agents";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/4590696c8693fea477850fe379a01544293ca4e2";
    nixpkgs-master.url = "github:NixOS/nixpkgs/d233902339c02a9c334e7e593de68855ad26c4cb";
    utils.url = "https://flakehub.com/f/numtide/flake-utils/0.1.102";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
      rust-overlay,
      ...
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };
        # Stable toolchain with the extensions the justfile lanes rely on:
        # clippy (lints), rustfmt (formatting), rust-src (rust-analyzer).
        # Note: `just formatting` shells out to `cargo +nightly fmt`, which
        # assumes a rustup-managed nightly and is not provided here.
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "rust-src"
            "rustfmt"
            "clippy"
          ];
        };
      in
      {
        # Devshell for the agent dev-loop: `cargo test --all` (just tests),
        # `cargo clippy` (just lints), `cargo deny check` (just dependencies),
        # `codespell` (just spelling), and `just` itself.
        devShells.default = pkgs.mkShell {
          packages = [
            rustToolchain
            pkgs.cargo-deny
            pkgs.rust-analyzer
            pkgs.just
            pkgs.codespell
            pkgs.pkg-config
          ];
        };
      }
    );
}
