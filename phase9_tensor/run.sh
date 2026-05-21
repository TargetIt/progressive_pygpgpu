#!/bin/bash
# Phase 9: Tensor Core -- one-click run script
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

# --trace: run a demo program with auto trace output
if [ "$1" = "--trace" ]; then
    DEMO="${2:-tests/programs/01_mma_dot.asm}"
    echo "--- Trace: $DEMO ---"
    PYTHONIOENCODING=utf-8 python src/learning_console.py "$DEMO" --auto --max-cycles 500
    exit $?
fi

# --console: run interactive learning console
if [ "$1" = "--console" ]; then
    DEMO="${2:-tests/programs/01_mma_dot.asm}"
    echo "--- Console: $DEMO ---"
    PYTHONIOENCODING=utf-8 python src/learning_console.py "$DEMO"
    exit $?
fi


# --mma: Run MMA tensor core demo
if [ "$1" = "--mma" ]; then
    DEMO="${2:-tests/programs/01_mma_dot.asm}"
    echo "--- Run MMA tensor core demo: $DEMO ---"
    PYTHONIOENCODING=utf-8 python src/learning_console.py ${DEMO} --auto --max-cycles 500
    exit $?
fi

# Default: run test suite
echo "╔══════════════════════════════════════════════╗"
echo "║  Phase 9: Tensor Core Test Suite             ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

PYTHONIOENCODING=utf-8 python tests/test_phase9.py

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  Phase 9 Complete                            ║"
echo "╚══════════════════════════════════════════════╝"
