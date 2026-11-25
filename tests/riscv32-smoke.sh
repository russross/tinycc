#!/bin/sh
set -eu

# The executable uses the Linux exit syscall and needs no target sysroot.
tcc=$1
tests=$2
runtime=$3
tmp=$(mktemp -d)
trap 'rm -r "$tmp"' EXIT
"$tcc" -I"$tests/../include" -c "$tests/riscv32-layout.c" -o "$tmp/layout.o"
cat > "$tmp/start.s" <<'ASM'
.globl _start
_start:
    call main
    li a7,93
    ecall
ASM
cat > "$tmp/encoding.S" <<'ASM'
.globl encoding
encoding:
    c.addi4spn a3, sp, 16
    c.addi4spn a5, sp, 1020
    addi a0,a0,2047
    addi a0,a0,-2048
    c.slli a0,31
    c.srli a1,31
    c.srai a2,31
ASM
"$tcc" -c "$tmp/encoding.S" -o "$tmp/encoding.o"
"${RV32_CLANG:-clang}" --target=riscv32-linux-gnu -march=rv32gc -mabi=ilp32d \
    -Dencoding=reference -c "$tmp/encoding.S" -o "$tmp/reference.o"
for instruction in 'c.addi4spn a3, sp, 0' 'c.addi4spn a5, sp, 1024' \
    'addi a0,a0,2048' 'addi a0,a0,-2049' \
    'c.slli a0,32' 'c.srli a1,32' 'c.srai a2,32'; do
    printf '%s\n' "$instruction" > "$tmp/invalid.s"
    if "$tcc" -c "$tmp/invalid.s" -o "$tmp/invalid.o" 2>"$tmp/error"; then
        echo "unexpectedly accepted $instruction" >&2
        exit 1
    fi
done

cat > "$tmp/check.c" <<'C'
extern int base[], *plus, *minus, *copy;
extern unsigned words[];
extern int *reloc_base(void);
extern int jump_addend(void);
extern const unsigned char encoding[], reference[];
static _Atomic unsigned counter;
static _Atomic unsigned long long wide;
int main(void)
{
    unsigned expected = 3, desired = 7;
    unsigned long long value = 0x100000005ULL, read;
    for (int i = 0; i < 18; ++i)
        if (encoding[i] != reference[i])
            return 1;
    __atomic_store(&counter, &expected, 5);
    if (!__atomic_compare_exchange(&counter, &expected, &desired, 0, 5, 5) ||
        counter != 7)
        return 1;
    __atomic_store(&wide, &value, 5);
    __atomic_load(&wide, &read, 5);
    if (read != value)
        return 1;
    return reloc_base() != base || plus != base + 3 || minus != base - 1 || copy != base + 2 ||
           words[0] != (unsigned)(base + 1) ||
           words[1] != (unsigned)(base + 2) || words[2] != 0 ||
           words[3] != 4 || words[4] != (unsigned)base - (unsigned)&words[4] ||
           jump_addend() != 1;
}
C
"$tcc" -c "$tmp/start.s" -o "$tmp/start.o"
"$tcc" -r "$tests/riscv32-reloc.c" "$tests/riscv32-reloc.s" -o "$tmp/reloc.o"
"$tcc" -static -nostdlib "$tmp/start.o" "$tmp/check.c" "$tmp/reloc.o" \
    "$tmp/encoding.o" "$tmp/reference.o" "$runtime" -o "$tmp/reloc"
"${QEMU_RISCV32:-qemu-riscv32}" "$tmp/reloc"

# A shared object cannot resolve an eight-byte absolute address at load time.
printf '%s\n' '.data' '.quad external+12' > "$tmp/dynamic.s"
if "$tcc" -shared -nostdlib "$tmp/dynamic.s" -o "$tmp/dynamic.so" 2>"$tmp/error"; then
    echo "expected a dynamic R_RISCV_64 relocation error" >&2
    exit 1
fi
grep -q 'R_RISCV_64 requires a dynamic relocation' "$tmp/error"

# Exchange callers and callees with the reference compiler.
for side in define use; do
    set --
    if [ "$side" = define ]; then set -- -DDEFINE; fi
    "${RV32_CLANG:-clang}" --target=riscv32-linux-gnu -march=rv32gc -mabi=ilp32d \
        -O1 -ffreestanding -mno-relax "$@" -c "$tests/riscv32-abi.c" -o "$tmp/$side-ref.o"
    "$tcc" -I"$tests/../include" "$@" -c "$tests/riscv32-abi.c" -o "$tmp/$side-tcc.o"
done

cat > "$tmp/memory.c" <<'C'
void *memmove(void *dest, const void *src, unsigned n)
{
    unsigned char *d = dest;
    const unsigned char *s = src;
    if (d < s) {
        for (unsigned i = 0; i < n; ++i) d[i] = s[i];
    } else {
        while (n) { --n; d[n] = s[n]; }
    }
    return dest;
}
void *memset(void *dest, int c, unsigned n)
{
    unsigned char *d = dest;
    while (n--) *d++ = c;
    return dest;
}
C
"$tcc" -c "$tmp/memory.c" -o "$tmp/memory.o"
for compilers in 'ref tcc' 'tcc ref'; do
    set -- $compilers
    "$tcc" -static -nostdlib "$tmp/start.o" "$tmp/define-$1.o" "$tmp/use-$2.o" \
        "$tmp/memory.o" "$runtime" -o "$tmp/abi"
    "${QEMU_RISCV32:-qemu-riscv32}" "$tmp/abi"
done
