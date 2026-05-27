#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/artifacts/guest-images"
IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMG_PATH="${OUT_DIR}/noble-server-cloudimg-amd64.img"

mkdir -p "$OUT_DIR"

if [[ -f "$IMG_PATH" ]]; then
	echo "guest image already exists: $IMG_PATH"
	exit 0
fi

curl -L "$IMG_URL" -o "$IMG_PATH"
echo "downloaded: $IMG_PATH"
