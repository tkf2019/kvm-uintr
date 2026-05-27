#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMG_PATH="${ROOT_DIR}/artifacts/guest-images/noble-server-cloudimg-amd64.img"

if [[ ! -f "$IMG_PATH" ]]; then
	echo "missing guest image: $IMG_PATH" >&2
	echo "run scripts/fetch-ubuntu-guest.sh first" >&2
	exit 1
fi

cat <<EOF
Placeholder launcher.

Expected next step:
- add a QEMU command line that boots Ubuntu 24.04 with KVM enabled
- expose the CPU feature plan required for guest-side UINTR testing
- attach cloud-init or another provisioning mechanism for Caladan setup
EOF
