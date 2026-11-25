#!/bin/sh
set -eu

# Use the existing bounds suite with the target runtime and loader.
tcc=$1
tests=$2
: "${RV32_SYSROOT:?set RV32_SYSROOT to the RV32 Linux sysroot}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
"$tcc" -B. ${RV32_TEST_LDFLAGS:-} -b "$tests/boundtest.c" -o "$tmp/boundtest"

for n in 1 4 8 10 14 16; do
    if ! "${QEMU_RISCV32:-qemu-riscv32}" -L "$RV32_SYSROOT" "$tmp/boundtest" "$n" >"$tmp/log" 2>&1; then
        echo "bounds test $n unexpectedly failed" >&2
        cat "$tmp/log" >&2
        exit 1
    fi
done

for n in 2 5 6 7 9 11 12 13 15 17 18; do
    if "${QEMU_RISCV32:-qemu-riscv32}" -L "$RV32_SYSROOT" "$tmp/boundtest" "$n" >"$tmp/log" 2>&1; then
        echo "bounds test $n unexpectedly succeeded" >&2
        exit 1
    fi
    if ! grep -q 'BCHECK:' "$tmp/log"; then
        echo "bounds test $n failed without a bounds diagnostic" >&2
        cat "$tmp/log" >&2
        exit 1
    fi
done

# Exercise the existing bounds regressions for stack lifetime and control flow.
for test in 114_bound_signal 115_bound_setjmp 116_bound_setjmp2 \
            121_struct_return 122_vla_reuse 132_bound_test; do
    "$tcc" -B. ${RV32_TEST_LDFLAGS:-} -b "$tests/tests2/$test.c" -o "$tmp/regression"
    if ! "${QEMU_RISCV32:-qemu-riscv32}" -L "$RV32_SYSROOT" "$tmp/regression" >"$tmp/log" 2>&1; then
        echo "bounds regression $test failed" >&2
        cat "$tmp/log" >&2
        exit 1
    fi
    diff -u "$tests/tests2/$test.expect" "$tmp/log"
done

# Verify that a global overflow reports both the bounds error and its source.
"$tcc" -B. ${RV32_TEST_LDFLAGS:-} -b "$tests/tests2/126_bound_global.c" -o "$tmp/regression"
if "${QEMU_RISCV32:-qemu-riscv32}" -L "$RV32_SYSROOT" "$tmp/regression" >"$tmp/log" 2>&1; then
    echo 'global bounds regression unexpectedly succeeded' >&2
    exit 1
fi
grep -q '126_bound_global.c:11: at main: BCHECK:' "$tmp/log"
grep -q '126_bound_global.c:11: at main: RUNTIME ERROR: invalid memory access' "$tmp/log"
echo 'RV32 bounds tests passed'
