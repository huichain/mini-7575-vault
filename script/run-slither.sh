#!/usr/bin/env sh
set -eu

TARGET="${1:-src/Vault.sol}"
ALL_SOURCE="${2:-}"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
RUN_FROM="$(CDPATH= cd -- "$PROJECT_ROOT/.." && pwd)"

OPENZEPPELIN_PATH="$PROJECT_ROOT/lib/openzeppelin-contracts/contracts"

if ! command -v slither >/dev/null 2>&1; then
    echo "Slither is not installed or not in PATH. Run: python -m pip install slither-analyzer"
    exit 1
fi

run_slither() {
    target_path="$1"
    echo " -> $target_path"
    slither "$target_path" \
        --compile-force-framework solc \
        --solc-remaps "@openzeppelin/contracts=$OPENZEPPELIN_PATH/" \
        --exclude-low \
        --exclude-informational \
        --exclude-optimization
}

echo "Running Slither analysis ..."
cd "$RUN_FROM"

if [ "$TARGET" = "--all-source" ] || [ "$ALL_SOURCE" = "--all-source" ]; then
    found_any=0
    for file in "$PROJECT_ROOT"/src/*.sol "$PROJECT_ROOT"/src/*/*.sol; do
        if [ -f "$file" ]; then
            found_any=1
            run_slither "$file"
        fi
    done
    if [ "$found_any" -eq 0 ]; then
        echo "No Solidity files found under $PROJECT_ROOT/src"
        exit 1
    fi
else
    target_path="$PROJECT_ROOT/$TARGET"
    if [ ! -f "$target_path" ]; then
        echo "Target not found: $target_path"
        exit 1
    fi
    run_slither "$target_path"
fi
