#!/usr/bin/env sh
# Installs (or updates) the Ubuntu 20.04 build of Wu from the wuqingwei/wu fork.
#
#   curl -fsSL https://raw.githubusercontent.com/wuqingwei/wu/main/install-ubuntu2004.sh | sh
#
# Options (environment variables):
#   WU_VERSION=1.2.2-ubuntu2004   install a specific release tag (default: latest release)
#   WU_BUNDLE_PATH=/path/to/wu-linux-x86_64-ubuntu2004.tar.gz
#                                 install a local tarball instead of downloading
#                                 (handy for offline machines: download once, copy over)
#
# This installs the fork's 20.04-only build (wu-linux-x86_64-ubuntu2004.tar.gz):
# unpacked into ~/.local/wu.app, ~/.local/bin/wu symlinked, desktop entry installed.
# Running it again updates to the newest release. Linux x86_64 only.
# The build targets glibc 2.31, so it also runs on newer Ubuntu releases.
#
# The target machine still needs libfontconfig.so.1 (sudo apt install libfontconfig1).
# On Mesa 21 / llvmpipe (LLVM 12) the window will not open; upgrade Mesa to 25.0.7
# (kisak/turtle PPA) and set ZED_ALLOW_EMULATED_GPU=1.

set -eu

REPO="wuqingwei/wu"
ASSET="wu-linux-x86_64-ubuntu2004.tar.gz"
VERSION="${WU_VERSION:-latest}"
BUNDLE_PATH="${WU_BUNDLE_PATH:-}"

download() {
  url="$1"
  dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$dest" "$url"
  else
    echo "Could not find 'curl' or 'wget' in your path" >&2
    exit 1
  fi
}

main() {
  platform="$(uname -s)"
  arch="$(uname -m)"

  if [ "$platform" != "Linux" ]; then
    echo "This installer only supports Linux (the fork ships a 20.04 x86_64 build)." >&2
    exit 1
  fi

  if [ "$arch" != "x86_64" ]; then
    echo "Unsupported architecture: $arch (this installer only provides x86_64)." >&2
    exit 1
  fi

  if [ -n "${TMPDIR:-}" ] && [ -d "${TMPDIR}" ]; then
    temp="$(mktemp -d "$TMPDIR/wu-XXXXXX")"
  else
    temp="$(mktemp -d "/tmp/wu-XXXXXX")"
  fi
  trap 'rm -rf "$temp"' EXIT

  if [ -n "$BUNDLE_PATH" ]; then
    echo "Installing Wu from local bundle: $BUNDLE_PATH"
    cp "$BUNDLE_PATH" "$temp/$ASSET"
  else
    if [ "$VERSION" = "latest" ]; then
      download_base="https://github.com/$REPO/releases/latest/download"
    else
      download_base="https://github.com/$REPO/releases/download/$VERSION"
    fi
    echo "Downloading Wu version: $VERSION"
    download "$download_base/$ASSET" "$temp/$ASSET"
  fi

  # Unpack (re-running replaces the old install, i.e. updates it)
  rm -rf "$HOME/.local/wu.app"
  mkdir -p "$HOME/.local/wu.app"
  tar -xzf "$temp/$ASSET" -C "$HOME/.local/"

  # Warn about missing shared libraries instead of failing later at startup
  wu_editor="$HOME/.local/wu.app/libexec/wu-editor"
  if [ -f "$wu_editor" ] && command -v ldd >/dev/null 2>&1; then
    missing="$(ldd "$wu_editor" 2>/dev/null | sed -n 's/^[[:space:]]*\(.*\) => not found$/\1/p')"
    if [ -n "$missing" ]; then
      echo "Warning: your system is missing libraries that Wu needs:"
      echo "$missing" | sed 's/^/ /'
      echo "Install them with your package manager, or Wu will fail to start."
    fi
  fi

  mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
  ln -sf "$HOME/.local/wu.app/bin/wu" "$HOME/.local/bin/wu"

  desktop_src="$HOME/.local/wu.app/share/applications/me.farshed.Wu.desktop"
  desktop_dst="$HOME/.local/share/applications/me.farshed.Wu.desktop"
  if [ -f "$desktop_src" ]; then
    cp "$desktop_src" "$desktop_dst"
    sed -i "s|Icon=wu|Icon=$HOME/.local/wu.app/share/icons/hicolor/512x512/apps/wu.png|g" "$desktop_dst"
    sed -i "s|Exec=wu|Exec=$HOME/.local/wu.app/bin/wu|g" "$desktop_dst"
  fi

  if [ "$(command -v wu)" = "$HOME/.local/bin/wu" ]; then
    echo "Wu has been installed. Run with 'wu'"
  else
    echo "To run Wu from your terminal, add ~/.local/bin to your PATH:"
    echo "  echo 'export PATH=\$HOME/.local/bin:\$PATH' >> ~/.bashrc && source ~/.bashrc"
    echo "To run Wu now: '$HOME/.local/bin/wu'"
  fi
}

main "$@"
