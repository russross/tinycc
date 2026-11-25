#include <stdlib.h>
#include <stddef.h>

/* AArch64 Linux uses the unsigned wchar_t required by its system headers. */
#if defined(__linux__) && defined(__aarch64__)
_Static_assert(__builtin_types_compatible_p(wchar_t, unsigned int), "wchar_t ABI");
#endif

int main(void) { return 0; }
