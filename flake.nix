# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This source code is licensed under both the MIT license found in the
# LICENSE-MIT file in the root directory of this source tree and the Apache
# License, Version 2.0 found in the LICENSE-APACHE file in the root directory
# of this source tree.
{
  description = "A flake for hacking on and building buck2";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ (import rust-overlay) ];
      };

    rust-version = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain;
    my-rust-bin = rust-version.override {
      extensions = [ "rust-analyzer" "rust-src" ];
    };

    in {
      devShells.default = pkgs.mkShell {
        buildInputs = pkgs.lib.optionals pkgs.stdenv.isDarwin (with pkgs.darwin.apple_sdk.frameworks; [
          Foundation
          CoreFoundation
          CoreServices
          DiskArbitration
          IOKit
          Security
        ]);
        packages = [ pkgs.cargo-bloat my-rust-bin pkgs.mold-wrapped pkgs.reindeer pkgs.lld_16 pkgs.clang_16 pkgs.libiconv];
        shellHook = 
          ''
            export BUCK2_BUILD_PROTOC=${pkgs.protobuf}/bin/protoc
            export BUCK2_BUILD_PROTOC_INCLUDE=${pkgs.protobuf}/include
            export LDFLAGS="$LDFLAGS -L${pkgs.libiconv}/lib"
            export RUSTFLAGS="$RUSTFLAGS -L${pkgs.libiconv}/lib -F${pkgs.darwin.apple_sdk.frameworks.Foundation}/Library/Frameworks -framework Foundation -F${pkgs.darwin.apple_sdk.frameworks.CoreFoundation}/Library/Frameworks -framework CoreFoundation -F${pkgs.darwin.apple_sdk.frameworks.CoreServices}/Library/Frameworks -framework CoreServices -F${pkgs.darwin.apple_sdk.frameworks.IOKit}/Library/Frameworks -framework IOKit -F${pkgs.darwin.apple_sdk.frameworks.Security}/Library/Frameworks -framework Security"
            # Should use NIX_LDFLAGS for other stuff?
            export NIX_LDFLAGS="-F${pkgs.darwin.apple_sdk.frameworks.DiskArbitration}/Library/Frameworks -framework DiskArbitration -F${pkgs.darwin.apple_sdk.frameworks.Foundation}/Library/Frameworks -framework Foundation -F${pkgs.darwin.apple_sdk.frameworks.CoreFoundation}/Library/Frameworks -framework CoreFoundation -F${pkgs.darwin.apple_sdk.frameworks.CoreServices}/Library/Frameworks -framework CoreServices -F${pkgs.darwin.apple_sdk.frameworks.IOKit}/Library/Frameworks -framework IOKit -F${pkgs.darwin.apple_sdk.frameworks.Security}/Library/Frameworks -framework Security $NIX_LDFLAGS";
          ''
          # enable mold for linux users, for more tolerable link times
          + pkgs.lib.optionalString pkgs.stdenv.isLinux ''
            export RUSTFLAGS="-C linker=clang -C link-arg=-fuse-ld=mold $RUSTFLAGS"
          '';
      };
    });
}
