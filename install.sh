#!/usr/bin/env bash
# Install or update grok CLI from youfun/grok-build-ci GitHub Releases.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/youfun/grok-build-ci/main/install.sh | bash
#   ./install.sh
#   ./install.sh --dir "$HOME/.local/bin"
#   GROK_CI_REPO=youfun/grok-build-ci ./install.sh
#
# Env:
#   GROK_CI_REPO       release repo (default: youfun/grok-build-ci)
#   GROK_INSTALL_DIR   install directory (default: ~/.local/bin)
#   GROK_RELEASE_TAG   release tag (default: latest)

set -euo pipefail

REPO="${GROK_CI_REPO:-youfun/grok-build-ci}"
INSTALL_DIR="${GROK_INSTALL_DIR:-${HOME}/.local/bin}"
TAG="${GROK_RELEASE_TAG:-latest}"
BIN_NAME="grok"

usage() {
  cat <<'USAGE'
Install or update the grok CLI binary.

Options:
  -d, --dir DIR   Install directory (default: ~/.local/bin)
  -t, --tag TAG   Release tag (default: latest)
  -h, --help      Show help

Examples:
  curl -fsSL https://raw.githubusercontent.com/youfun/grok-build-ci/main/install.sh | bash
  ./install.sh --dir "$HOME/bin"
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dir)
      INSTALL_DIR="${2:?missing dir}"
      shift 2
      ;;
    -t|--tag)
      TAG="${2:?missing tag}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

need_cmd uname
need_cmd mktemp
if command -v curl >/dev/null 2>&1; then
  DOWNLOAD_CMD="curl"
elif command -v wget >/dev/null 2>&1; then
  DOWNLOAD_CMD="wget"
else
  echo "error: need curl or wget" >&2
  exit 1
fi

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$OS" in
  darwin) OS_KEY="macos" ;;
  linux) OS_KEY="linux" ;;
  msys*|mingw*|cygwin*)
    echo "error: on Windows use install.ps1" >&2
    exit 1
    ;;
  *)
    echo "error: unsupported OS: $OS" >&2
    exit 1
    ;;
esac

case "$ARCH" in
  arm64|aarch64) ARCH_KEY="aarch64" ;;
  x86_64|amd64) ARCH_KEY="x86_64" ;;
  *)
    echo "error: unsupported arch: $ARCH" >&2
    exit 1
    ;;
esac

ASSET="grok-${OS_KEY}-${ARCH_KEY}"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
URL="${BASE_URL}/${ASSET}"

echo "Installing grok"
echo "  source : ${REPO}@${TAG}"
echo "  asset  : ${ASSET}"
echo "  dest   : ${INSTALL_DIR}/${BIN_NAME}"

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

TMP_BIN="${TMP_DIR}/${BIN_NAME}"

download() {
  local url="$1" out="$2"
  if [[ "$DOWNLOAD_CMD" == "curl" ]]; then
    curl -fL --retry 3 --retry-delay 1 -o "$out" "$url"
  else
    wget -O "$out" "$url"
  fi
}

echo "Downloading ${URL}"
if ! download "$URL" "$TMP_BIN"; then
  echo "error: download failed. Is the '${TAG}' release published with asset '${ASSET}'?" >&2
  echo "  releases: https://github.com/${REPO}/releases" >&2
  exit 1
fi

chmod +x "$TMP_BIN"
mkdir -p "$INSTALL_DIR"
# Atomic-ish replace
install -m 755 "$TMP_BIN" "${INSTALL_DIR}/${BIN_NAME}" 2>/dev/null || {
  cp "$TMP_BIN" "${INSTALL_DIR}/${BIN_NAME}"
  chmod 755 "${INSTALL_DIR}/${BIN_NAME}"
}

# Optional version probe (non-fatal)
if "${INSTALL_DIR}/${BIN_NAME}" --version >/dev/null 2>&1; then
  echo "Installed: $("${INSTALL_DIR}/${BIN_NAME}" --version 2>/dev/null | head -n1)"
else
  echo "Installed binary to ${INSTALL_DIR}/${BIN_NAME}"
fi

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*)
    echo "PATH already includes ${INSTALL_DIR}"
    ;;
  *)
    echo
    echo "Add to PATH (current shell):"
    echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
    echo
    shell_rc=""
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "${SHELL:-}" == *zsh* ]]; then
      shell_rc="${HOME}/.zshrc"
    elif [[ -n "${BASH_VERSION:-}" ]] || [[ "${SHELL:-}" == *bash* ]]; then
      shell_rc="${HOME}/.bashrc"
    fi
    marker_begin="# >>> grok-build-ci installer >>>"
    marker_end="# <<< grok-build-ci installer <<<"
    if [[ -n "$shell_rc" ]]; then
      if [[ -f "$shell_rc" ]] && grep -qF "$marker_begin" "$shell_rc" 2>/dev/null; then
        echo "PATH block already present in ${shell_rc}"
      else
        {
          echo
          echo "$marker_begin"
          echo "export PATH=\"${INSTALL_DIR}:\$PATH\""
          echo "$marker_end"
        } >> "$shell_rc"
        echo "Appended PATH export to ${shell_rc} (open a new terminal)"
      fi
    fi
    ;;
esac

echo "Done. Run: ${BIN_NAME} --version"
