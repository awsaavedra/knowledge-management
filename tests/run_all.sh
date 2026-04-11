#!/usr/bin/env bash
# run_all.sh — Run the full KMS test suite.
#
# Usage:
#   bash tests/run_all.sh                          # run all tests
#   bash tests/run_all.sh tests/todo_summary.bats  # run one file
#   bash tests/run_all.sh --filter "TODO marker"   # run matching tests
#   bash tests/run_all.sh --tap                    # TAP output for CI

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS="${SCRIPT_DIR}/lib/bats-core/bin/bats"

if [[ ! -x "$BATS" ]]; then
    echo "ERROR: bats not found at ${BATS}" >&2
    echo "Run: git submodule update --init --recursive" >&2
    exit 1
fi

# If specific files were passed, run those; otherwise run all .bats files
if [[ $# -gt 0 && "$1" != -* ]]; then
    "$BATS" "$@"
else
    "$BATS" "${SCRIPT_DIR}"/*.bats "$@"
fi
