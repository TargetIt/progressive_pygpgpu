#!/bin/bash
# Phase 10: Visualization & Toolchain -- one-click run script
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# --help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: ./run.sh [MODE] [program]"
    echo ""
    echo "Modes:"
    echo "  (default)    Run test suite"
    echo "  --trace      Run demo with auto trace output"
    echo "  --console    Run interactive learning console"
    echo ""
    echo "Examples:"
    echo "  ./run.sh                    # Run tests"
    echo "  ./run.sh --trace            # Trace default demo"
    echo "  ./run.sh --trace path.asm   # Trace specific program"
    echo "  ./run.sh --console          # Console with default demo"
    echo "  ./run.sh --console path.asm # Console with specific program"
    exit 0
fi

# --trace: no demo programs available in this phase
if [ "$1" = "--trace" ]; then
    echo "No demo programs available for Phase 10."
    echo "Usage: python src/learning_console.py <program> --auto"
    exit 1
fi

# --console: no demo programs available in this phase
if [ "$1" = "--console" ]; then
    echo "No demo programs available for Phase 10."
    echo "Usage: python src/learning_console.py <program>"
    exit 1
fi

# Default: run test suite
echo "╔══════════════════════════════════════════════╗"
echo "║  Phase 10: Visualization & Toolchain Test Suite║"
echo "╚══════════════════════════════════════════════╝"
echo ""

PYTHONIOENCODING=utf-8 python tests/test_phase10.py

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  Phase 10 Complete                           ║"
echo "╚══════════════════════════════════════════════╝"
