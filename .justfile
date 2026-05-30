#!/usr/bin/env -S just --working-directory . --justfile
# Load project-specific properties (e.g. UBUNTU_PACKAGES) from the `.env` file.
set dotenv-load

default: validate lint build test

[group("pre-build")]
validate: validate-deps

# Advisory, license, and ban-policy gate via cargo-deny.
[group("pre-build")]
validate-deps:
    cargo deny check

# Hook-driven (pre-push); kept out of `validate` so the default run ignores history.
# Check each commit in REFS is signed-off and spell-clean.
[group("pre-build")]
validate-commits REFS='main..':
    #!/usr/bin/env bash
    set -euo pipefail
    for commit in $(git rev-list "{{ REFS }}"); do
      MSG="$(git show -s --format=%B "$commit")"
      CODESPELL_RC="$(mktemp)"
      git show "$commit:.codespellrc" > "$CODESPELL_RC"
      if ! grep -q "Signed-off-by: " <<< "$MSG"; then
        printf "Commit %s lacks \"Signed-off-by\" line.\n" "$commit"
        printf "%s\n" \
            "  Please use:" \
            "    git rebase --signoff main && git push --force-with-lease" \
            "  See https://developercertificate.org/ for more details."
        exit 1;
      elif ! codespell --config "$CODESPELL_RC" - <<< "$MSG"; then
        printf "The spelling in commit %s needs improvement.\n" "$commit"
        exit 1;
      else
        printf "Commit %s is good.\n" "$commit"
      fi
    done

[group("pre-build")]
lint: lint-fmt lint-spelling lint-rust

[group("pre-build")]
lint-fmt: lint-fmt-just lint-fmt-rust

[group("pre-build")]
lint-fmt-just:
    just --unstable --fmt --check

# Nightly rustfmt — .rustfmt.toml import grouping is nightly-only.
[group("pre-build")]
lint-fmt-rust:
    cargo +nightly fmt --all -- --check

[group("pre-build")]
lint-spelling:
    codespell

[group("pre-build")]
lint-rust:
    cargo clippy --workspace --no-deps --all-targets -- -D warnings

[group("build")]
build: build-cargo build-docs

# The fuzz member is excluded — its libfuzzer-sys bin needs a sanitizer to link.
# Compile the library plus its examples and tests.
[group("build")]
build-cargo:
    cargo build --package ssh-agent-lib --all-targets

[group("build")]
build-docs:
    cargo doc --no-deps

[group("post-build")]
test: test-cargo

[group("post-build")]
test-cargo:
    cargo test --all

[group("codemod")]
codemod-fmt: codemod-fmt-just codemod-fmt-rust

[group("codemod")]
codemod-fmt-just:
    just --unstable --fmt

# Nightly rustfmt (see lint-fmt-rust).
[group("codemod")]
codemod-fmt-rust:
    cargo +nightly fmt --all

# Formats last because clippy's --fix rewrites can break formatting.
# Auto-fix spelling, rustc, and clippy findings on a staged, clean tree.
[group("codemod")]
codemod-fix:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! git diff-files --quiet ; then
        echo "Working tree has changes. Please stage them: git add ."
        exit 1
    fi
    codespell --write-changes
    just --unstable --fmt
    cargo fix --allow-staged
    cargo clippy --fix --allow-staged --allow-dirty
    cargo +nightly fmt --all

# Install the system packages the build needs (reads *_PACKAGES from `.env`).
[linux]
[group("operational")]
install-packages:
    sudo apt-get install --assume-yes --no-install-recommends $UBUNTU_PACKAGES

[macos]
[windows]
[group("operational")]
install-packages:
    echo no-op
