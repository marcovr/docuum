#!/bin/bash
# Make not silently ignore errors.
set -euo pipefail

# Load the Rust startup file, if it exists.
if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

# Use this wrapper for `cargo` if network access is needed.
cargo-online () { cargo --locked "$@"; }

# Use this wrapper for `cargo` unless network access is needed.
cargo-offline () { cargo --frozen --offline "$@"; }

# Use this wrapper for formatting code or checking that code is formatted. We use a nightly Rust
# version for the `trailing_comma` formatting option [tag:rust_fmt_nightly_2025-11-02]. The
# nightly version was chosen as the latest available release with all components present
# according to this page:
#   https://rust-lang.github.io/rustup-components-history/x86_64-unknown-linux-gnu.html
cargo-fmt () { cargo +nightly-2025-11-02 --frozen --offline fmt --all -- "$@"; }

# Make Bash log commands.
set -x

# Install the following packages:
#
# - build-essential       - Used to link some crates
# - ca-certificates       - Used for fetching Docker's GPG key
# - curl                  - Used for installing Docker, Tagref, and Rust
# - gcc-aarch64-linux-gnu - Used for linking the binary for AArch64
# - gcc-x86-64-linux-gnu  - Used for linking the binary for x86-64
# - gnupg                 - Used to install Docker's GPG key
# - lsb-release           - Used below to determine the Ubuntu release codename
# - ripgrep               - Used for various linting tasks
# - shellcheck            - Used for linting shell scripts
apt-get update
apt-get install --yes \
    build-essential \
    ca-certificates \
    curl \
    gcc-aarch64-linux-gnu \
    gcc-x86-64-linux-gnu \
    gnupg \
    lsb-release \
    ripgrep \
    shellcheck

# Install stable Rust [tag:rust_1.91.0].
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- \
    -y \
    --default-toolchain 1.91.0 \
    --profile minimal \
    --component clippy

# Add Rust tools to `$PATH`.
. "$HOME/.cargo/env"

# Install nightly Rust [ref:rust_fmt_nightly_2025-11-02].
rustup toolchain install nightly-2025-11-02 --profile minimal --component rustfmt


# Build the project with Cargo.
cargo-online build


# Run the tests with Cargo. The `NO_COLOR` variable is used to disable colored output for
# tests that make assertions regarding the output [tag:colorless_tests].
NO_COLOR=true cargo-offline test


# Add the targets.
rustup target add x86_64-unknown-linux-gnu
rustup target add x86_64-unknown-linux-musl
rustup target add aarch64-unknown-linux-gnu
rustup target add aarch64-unknown-linux-musl

# Set the linkers.
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=x86_64-linux-gnu-gcc
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=x86_64-linux-gnu-gcc
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER=aarch64-linux-gnu-gcc

# Build the project with Cargo for each Linux target.
cargo-online build --release --target x86_64-unknown-linux-gnu
cargo-online build --release --target x86_64-unknown-linux-musl
cargo-online build --release --target aarch64-unknown-linux-gnu
cargo-online build --release --target aarch64-unknown-linux-musl

# Move the binaries to a more conveniennt location for exporting.
mkdir artifacts
cp \
    target/x86_64-unknown-linux-gnu/release/docuum \
    artifacts/docuum-x86_64-unknown-linux-gnu
cp \
    target/x86_64-unknown-linux-musl/release/docuum \
    artifacts/docuum-x86_64-unknown-linux-musl
cp \
    target/aarch64-unknown-linux-gnu/release/docuum \
    artifacts/docuum-aarch64-unknown-linux-gnu
cp \
    target/aarch64-unknown-linux-musl/release/docuum \
    artifacts/docuum-aarch64-unknown-linux-musl

chmod -R 777 artifacts
