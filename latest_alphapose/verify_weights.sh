#!/usr/bin/env bash
set -euo pipefail

# Verify weights in latest_alphapose/weights against checksums.sha256

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WDIR="$SCRIPT_DIR/weights"
CSFILE="$WDIR/checksums.sha256"

if [[ ! -d "$WDIR" ]]; then
  echo "ERROR: weights directory not found: $WDIR" >&2
  exit 1
fi

if [[ ! -f "$CSFILE" ]]; then
  echo "No checksums found at $CSFILE." >&2
  echo "To create them, run (examples):" >&2
  echo "  (cd $WDIR && sha256sum fast_res50_256x192.pth >> checksums.sha256)" >&2
  echo "  (cd $WDIR && sha256sum yolox_x.pth >> checksums.sha256)" >&2
  echo "Current files and their SHA256:" >&2
  (cd "$WDIR" && ls -1 | grep -E '\\.(pth|onnx)$' || true | xargs -I{} sha256sum "{}" 2>/dev/null || true)
  exit 1
fi

echo "Verifying checksums in $CSFILE ..."
(cd "$WDIR" && sha256sum -c checksums.sha256)
echo "All checksums verified."

