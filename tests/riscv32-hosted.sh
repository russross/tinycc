#!/bin/sh
set -eu

# Run existing language and ABI regressions as hosted RV32 executables.
tcc=$1
tests=$2
: "${RV32_SYSROOT:?set RV32_SYSROOT to the RV32 Linux sysroot}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

for test in 19_pointer_arithmetic 20_pointer_comparison 23_type_coercion \
            35_sizeof 55_lshift_type 61_integers 88_codeopt \
            91_ptr_longlong_arith32 93_integer_promotion 95_bitfields \
            111_conversion 123_vla_bug 134_double_to_signed \
            135_func_arg_struct_compare 136_atomic_gcc_style \
            137_funcall_struct_args 142_int_conversion 153_large_struct_args; do
    "$tcc" -B. ${RV32_TEST_LDFLAGS:-} "$tests/tests2/$test.c" -o "$tmp/test"
    "${QEMU_RISCV32:-qemu-riscv32}" -L "$RV32_SYSROOT" "$tmp/test" >"$tmp/output"
    diff -u "$tests/tests2/$test.expect" "$tmp/output"
done
echo 'RV32 hosted tests passed'
