#!/bin/bash
set -e

# Barrel — SessionStart hook
# Installs Swift and cmark-gfm so the engine package builds on Linux (Claude Code web).
# On macOS this is a no-op (tools are expected via Homebrew / Xcode).

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# --------------------------------------------------------------------------- #
# Skip on macOS — local devs manage their own toolchain.
# --------------------------------------------------------------------------- #
if [[ "$(uname)" == "Darwin" ]]; then
  exit 0
fi

# --------------------------------------------------------------------------- #
# Helper: only install a package if it is not already present.
# --------------------------------------------------------------------------- #
need_cmd() { command -v "$1" >/dev/null 2>&1; }

# --------------------------------------------------------------------------- #
# 1. System packages (Ubuntu / Debian)
# --------------------------------------------------------------------------- #
install_system_deps() {
  local pkgs_needed=()

  need_cmd pkg-config || pkgs_needed+=(pkg-config)
  need_cmd cmake      || pkgs_needed+=(cmake)

  # cmark-gfm dev headers — try the distro package first.
  if ! pkg-config --exists libcmark-gfm 2>/dev/null && \
     ! [ -f /usr/local/include/cmark-gfm.h ]; then
    pkgs_needed+=(libcmark-gfm-dev)
  fi

  if (( ${#pkgs_needed[@]} )); then
    echo "[barrel] Installing system packages: ${pkgs_needed[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y -qq "${pkgs_needed[@]}" 2>/dev/null || true
  fi
}

# --------------------------------------------------------------------------- #
# 2. cmark-gfm from source (fallback if distro package unavailable)
# --------------------------------------------------------------------------- #
install_cmark_from_source() {
  if pkg-config --exists libcmark-gfm 2>/dev/null || \
     [ -f /usr/local/include/cmark-gfm.h ]; then
    return 0
  fi

  echo "[barrel] Building cmark-gfm from source..."
  local tmp
  tmp="$(mktemp -d)"
  git clone --depth 1 https://github.com/github/cmark-gfm.git "$tmp/cmark-gfm"
  mkdir -p "$tmp/cmark-gfm/build"
  cd "$tmp/cmark-gfm/build"
  cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local -DCMARK_TESTS=OFF -DCMARK_SHARED=ON
  make -j"$(nproc)"
  sudo make install
  sudo ldconfig
  cd "$PROJECT_DIR"
  rm -rf "$tmp"
  echo "[barrel] cmark-gfm installed to /usr/local"
}

# --------------------------------------------------------------------------- #
# 3. Swift toolchain
# --------------------------------------------------------------------------- #
install_swift() {
  if need_cmd swift; then
    echo "[barrel] Swift already available: $(swift --version 2>&1 | head -1)"
    return 0
  fi

  echo "[barrel] Installing Swift toolchain..."

  # Install Swift dependencies
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    binutils libc6-dev libcurl4-openssl-dev libedit-dev \
    libgcc-13-dev libpython3-dev libsqlite3-dev libstdc++-13-dev \
    libxml2-dev libncurses-dev libz3-dev pkg-config unzip zlib1g-dev \
    2>/dev/null || \
  sudo apt-get install -y -qq \
    binutils libc6-dev libcurl4-openssl-dev libedit-dev \
    libgcc-12-dev libpython3-dev libsqlite3-dev libstdc++-12-dev \
    libxml2-dev libncurses-dev pkg-config unzip zlib1g-dev \
    2>/dev/null || true

  # Try swiftly (Swift version manager)
  if ! need_cmd swiftly; then
    curl -fsSL https://swiftlang.github.io/swiftly/swiftly-install.sh | bash -s -- --yes 2>/dev/null || true
  fi

  if need_cmd swiftly; then
    swiftly install latest --yes 2>/dev/null || true
    # Source the environment
    [ -f "$HOME/.local/share/swiftly/env.sh" ] && . "$HOME/.local/share/swiftly/env.sh"
  fi

  # Fallback: try direct download
  if ! need_cmd swift; then
    echo "[barrel] swiftly install failed, trying direct download..."
    local SWIFT_VERSION="6.0.3"
    local SWIFT_PLATFORM
    SWIFT_PLATFORM="ubuntu$(lsb_release -rs | tr -d '.')"

    local url="https://download.swift.org/swift-${SWIFT_VERSION}-release/${SWIFT_PLATFORM}/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu$(lsb_release -rs).tar.gz"
    local tmp
    tmp="$(mktemp -d)"
    if curl -fsSL "$url" -o "$tmp/swift.tar.gz" 2>/dev/null; then
      sudo mkdir -p /usr/local/swift
      sudo tar xzf "$tmp/swift.tar.gz" -C /usr/local/swift --strip-components=1
    fi
    rm -rf "$tmp"
  fi

  if need_cmd swift; then
    echo "[barrel] Swift installed: $(swift --version 2>&1 | head -1)"
  else
    echo "[barrel] WARNING: Could not install Swift. Engine build will fail."
  fi
}

# --------------------------------------------------------------------------- #
# 4. Persist environment variables for the session
# --------------------------------------------------------------------------- #
persist_env() {
  if [ -n "$CLAUDE_ENV_FILE" ]; then
    {
      echo "export BARREL_ENGINE_DIR=\"$PROJECT_DIR/packages/MarkdownEngine\""

      # Add Swift to PATH if installed via swiftly
      if [ -f "$HOME/.local/share/swiftly/env.sh" ]; then
        echo "source \"$HOME/.local/share/swiftly/env.sh\""
      fi

      # Add /usr/local Swift to PATH if installed directly
      if [ -d /usr/local/swift/usr/bin ]; then
        echo 'export PATH="/usr/local/swift/usr/bin:$PATH"'
      fi

      # Add cmark-gfm pkg-config path if built from source
      if [ -f /usr/local/lib/pkgconfig/libcmark-gfm.pc ]; then
        echo 'export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"'
      fi
    } >> "$CLAUDE_ENV_FILE"
  fi
}

# --------------------------------------------------------------------------- #
# 5. Sanity check
# --------------------------------------------------------------------------- #
sanity_check() {
  echo "[barrel] Environment check:"
  echo "  swift:    $(swift --version 2>&1 | head -1 || echo 'NOT FOUND')"
  echo "  cmark-gfm: $(pkg-config --modversion libcmark-gfm 2>/dev/null || echo 'header at /usr/local/include' || echo 'NOT FOUND')"
  echo "  pkg-config: $(pkg-config --version 2>/dev/null || echo 'NOT FOUND')"

  # Quick build test of the engine (non-blocking — don't fail the hook)
  if need_cmd swift; then
    echo "[barrel] Testing engine build..."
    cd "$PROJECT_DIR/packages/MarkdownEngine"
    swift build 2>&1 | tail -3 || echo "[barrel] Build test had issues (non-fatal)"
    cd "$PROJECT_DIR"
  fi
}

# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
echo "[barrel] SessionStart: setting up environment..."
install_system_deps
install_cmark_from_source
install_swift
persist_env
sanity_check
echo "[barrel] SessionStart: done."
exit 0
