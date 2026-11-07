#!/usr/bin/env bash
set -euo pipefail
exec /usr/bin/python -I "$(dirname -- "${BASH_SOURCE[0]}")/install.py" "$@"
