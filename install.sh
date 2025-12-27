#!/usr/bin/env bash
set -e

REPO="webgeaz/soadcli"
BINARY="soad"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
esac

URL="https://github.com/$REPO/releases/latest/download/${BINARY}_${OS}_${ARCH}.tar.gz"

echo "Downloading $BINARY..."
curl -fsSL "$URL" -o /tmp/$BINARY.tar.gz

tar -xzf /tmp/$BINARY.tar.gz -C /tmp
chmod +x /tmp/$BINARY
sudo mv /tmp/$BINARY /usr/local/bin/$BINARY

echo "$BINARY installed!"
