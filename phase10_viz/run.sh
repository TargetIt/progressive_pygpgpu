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


# --viz: Run visualization analysis (warp timeline + stall analysis)
if [ "$1" = "--viz" ]; then
    echo "--- Viz: warp timeline + stall analysis ---"
    cat > tmp_viz_demo.asm << 'ASM'
TID r1
MOV r2, 10
MUL r3, r1, r2
ADD r4, r3, r1
SHST r4, [0]
SHLD r5, [0]
ST r5, [100]
HALT
ASM
    PYTHONIOENCODING=utf-8 python -c "
import sys; sys.path.insert(0, 'src')
from trace_runner import run_with_trace
from visualizer import full_report
from assembler import assemble
from simt_core import SIMTCore
with open('tmp_viz_demo.asm', encoding='utf-8') as f:
    prog = assemble(f.read())
simt = SIMTCore(warp_size=4, num_warps=2, memory_size=512)
simt.load_program(prog)
collector = run_with_trace(simt, max_cycles=500)
print(full_report(collector, num_warps=2, mem_size=512))
"
    rm -f tmp_viz_demo.asm
    exit $?
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
