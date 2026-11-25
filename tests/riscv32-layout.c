/* Compile with riscv32-tcc -c -Iinclude and compare with
   clang --target=riscv32-linux-gnu -march=rv32gc -mabi=ilp32d -c -Iinclude. */
#include <float.h>

#if __riscv_xlen != 32 || __riscv_flen != 64 || !defined(__riscv_float_abi_double)
#error expected RV32 ILP32D
#endif

_Static_assert(sizeof(void *) == 4 && sizeof(int) == 4 && sizeof(long) == 4, "ILP32");
_Static_assert(sizeof(long long) == 8 && __alignof__(long long) == 8, "long long");
_Static_assert(sizeof(double) == 8 && __alignof__(double) == 8, "double");
_Static_assert(sizeof(long double) == 16 && __alignof__(long double) == 16, "long double");
_Static_assert(LDBL_MANT_DIG == 113 && (char)-1 > 0, "binary128 and unsigned char");
_Static_assert(__builtin_types_compatible_p(__SIZE_TYPE__, unsigned int), "size_t");
_Static_assert(__builtin_types_compatible_p(__PTRDIFF_TYPE__, int), "ptrdiff_t");

struct inner {
    char tag;
    double value;
};
struct outer {
    char tag;
    struct inner items[2];
};
struct flags {
    unsigned int low : 3;
    unsigned int high : 29;
    char tail;
};
_Static_assert(sizeof(struct inner) == 16 && sizeof(struct outer) == 40, "nested array");
_Static_assert(__builtin_offsetof(struct outer, items) == 8, "nested alignment");
_Static_assert(sizeof(struct flags) == 8 && __builtin_offsetof(struct flags, tail) == 4, "bitfields");

/* GCC 13.3 RV32 caps these member alignments at the packing limit.
   Clang lays out these explicitly aligned bitfields differently. */
#if defined(__TINYC__) || (defined(__GNUC__) && !defined(__clang__))
#pragma pack(push, 1)
struct packed_wide {
    int x : 12;
    char y : 6;
    long long z : 63;
    char a : 4 __attribute__((aligned(16)));
    long long b : 2;
};
struct packed_short {
    unsigned x : 5, y : 5, : 0, z : 5;
    char a : 5;
    short b : 5 __attribute__((aligned(16)));
};
#pragma pack(pop)

_Static_assert(sizeof(struct packed_wide) == 12 && __alignof__(struct packed_wide) == 1,
               "packed wide bitfield");
_Static_assert(sizeof(struct packed_short) == 7 && __alignof__(struct packed_short) == 1,
               "packed short bitfield");
#endif

#if defined(__TINYC__)
_Static_assert(__builtin_types_compatible_p(__builtin_va_list, char *), "RISC-V predefines");
#endif
