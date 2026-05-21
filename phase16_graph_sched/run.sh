#!/bin/bash
# Phase 16: Graph Scheduler -- one-click run script
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
    DEMO="${2:-tests/programs/demo_basic.asm}"
    echo "--- Trace: $DEMO ---"
    PYTHONIOENCODING=utf-8 python src/learning_console.py "$DEMO" --auto --max-cycles 500
    exit $?
fi

# --console: run interactive learning console
if [ "$1" = "--console" ]; then
    DEMO="${2:-tests/programs/demo_basic.asm}"
    echo "--- Console: $DEMO ---"
    PYTHONIOENCODING=utf-8 python src/learning_console.py "$DEMO"
    exit $?
fi

# --cutile: run CuTile DSL pipeline (parse -> assemble -> execute)
if [ "$1" = "--cutile" ]; then
    CUTILE="${2:-tests/programs/13_cutile_matmul.cutile}"
    echo "--- CuTile: $CUTILE ---"
    PYTHONIOENCODING=utf-8 python -c "
import sys; sys.path.insert(0, 'src')
from cutile_parser import assemble_cutile
from simt_core import SIMTCore
with open('$CUTILE', encoding='utf-8') as f:
    src = f.read()
matrix_data = {
    'A': {'base': 0, 'M': 2, 'N': 2},
    'B': {'base': 8, 'M': 2, 'N': 2},
    'C': {'base': 16, 'M': 2, 'N': 2},
}
code, asm_text = assemble_cutile(src, matrix_data)
print(f'CuTile DSL -> {len(code)} ISA instructions:')
print(asm_text)
simt = SIMTCore(warp_size=1, num_warps=1, memory_size=256)
simt.memory.write_word(0, 1); simt.memory.write_word(1, 2)
simt.memory.write_word(2, 3); simt.memory.write_word(3, 4)
simt.memory.write_word(8, 5); simt.memory.write_word(9, 6)
simt.memory.write_word(10, 7); simt.memory.write_word(11, 8)
simt.load_program(code)
simt.run()
print()
print('Result C = A x B:')
expected = {0: 19, 1: 22, 2: 43, 3: 50}
for i in range(4):
    actual = simt.memory.read_word(16+i)
    exp = expected.get(i, '?')
    ok = 'OK' if actual == exp else f'EXPECTED {exp}'
    print(f'  C[{i}] = {actual}  ({ok})')
"
    exit $?
fi

# Default: run test suite
echo "╔══════════════════════════════════════════════╗"
echo "║  Phase 16: Graph Scheduler Test Suite        ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

PYTHONIOENCODING=utf-8 python tests/test_phase16.py

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  Phase 16 Complete                           ║"
echo "╚══════════════════════════════════════════════╝"
