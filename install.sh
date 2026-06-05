#!/bin/sh
# Jury installer — downloads the prebuilt `jury` binary for your platform from
# GitHub Releases. No Rust toolchain required.
#
#   curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh | sh
#
# Override the source repo or install dir if needed:
#   JURY_REPO=owner/repo  JURY_BIN_DIR=$HOME/.local/bin  sh install.sh
set -eu

REPO="${JURY_REPO:-morfestboy/Jury}"
BIN_DIR="${JURY_BIN_DIR:-$HOME/.local/bin}"

say()  { printf '%s\n' "$*"; }
err()  { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- detect platform -------------------------------------------------------
os="$(uname -s)"
arch="$(uname -m)"
case "$os" in
  Linux)  os_part="unknown-linux-gnu" ;;
  Darwin) os_part="apple-darwin" ;;
  *) err "unsupported OS '$os'. On Windows use install.ps1 (PowerShell)." ;;
esac
case "$arch" in
  x86_64|amd64) arch_part="x86_64" ;;
  arm64|aarch64) arch_part="aarch64" ;;
  *) err "unsupported architecture '$arch'." ;;
esac
target="${arch_part}-${os_part}"
asset="jury-${target}.tar.gz"
url="https://github.com/${REPO}/releases/latest/download/${asset}"

say "Installing jury (${target}) from ${REPO}…"

# --- download + verify -----------------------------------------------------
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    err "need curl or wget to download."
  fi
}

fetch "$url" "$tmp/$asset" || err "download failed: $url
(has a release been published for $REPO yet?)"

# Optional checksum verification if the .sha256 asset exists.
if fetch "${url}.sha256" "$tmp/${asset}.sha256" 2>/dev/null; then
  if command -v shasum >/dev/null 2>&1; then
    expected="$(awk '{print $1}' "$tmp/${asset}.sha256")"
    actual="$(shasum -a 256 "$tmp/$asset" | awk '{print $1}')"
    [ "$expected" = "$actual" ] || err "checksum mismatch — refusing to install."
    say "Checksum verified."
  fi
fi

# --- extract + install -----------------------------------------------------
tar -xzf "$tmp/$asset" -C "$tmp"
mkdir -p "$BIN_DIR"
install -m 0755 "$tmp/jury" "$BIN_DIR/jury" 2>/dev/null || {
  cp "$tmp/jury" "$BIN_DIR/jury"; chmod 0755 "$BIN_DIR/jury";
}

say ""
say "✓ Installed jury to $BIN_DIR/jury"
"$BIN_DIR/jury" --version || true

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) say ""
     say "Add $BIN_DIR to your PATH, e.g.:"
     say "  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc && source ~/.bashrc" ;;
esac
