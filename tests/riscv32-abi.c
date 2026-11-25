/* Compile twice with opposite compilers, defining DEFINE for the callee. */
#include <stdarg.h>

typedef struct { double x, y; } Pair;
typedef struct { float x; int y; } Mix;
typedef struct { float x; } Element;
typedef struct { Element a[2]; } Nested;
typedef struct {} Empty;

#ifdef DEFINE
Nested nested(Nested p)
{
    return (Nested){ { p.a[1], p.a[0] } };
}

Empty empty(int x, int *received)
{
    *received = x;
    return (Empty){};
}

extern int aligned16(void *);
int varargs(int n, ...)
{
    long double local;
    va_list ap;
    int i;

    va_start(ap, n);
    for (i = 0; i < n; ++i)
        if (va_arg(ap, int) != i)
            return 0;
    va_end(ap);
    return aligned16(&local);
}

Pair pair(Pair p)
{
    return (Pair){ p.y, p.x };
}

Mix mix(Mix p)
{
    return (Mix){ p.x + 1, p.y + 1 };
}

long double quadadd(long double x, long double y)
{
    return x + y;
}

double ninth(double x1, double x2, double x3, double x4, double x5,
             double x6, double x7, double x8, double x9)
{
    return x1 + x9;
}
#else
extern Nested nested(Nested);
extern Empty empty(int, int *);
extern int varargs(int, ...);
extern Pair pair(Pair);
extern Mix mix(Mix);
extern long double quadadd(long double, long double);
extern double ninth(double, double, double, double, double,
                    double, double, double, double);

int aligned16(void *p)
{
    return ((unsigned)p & 15) == 0;
}

int main(void)
{
    Pair p = pair((Pair){ 1.25, 9.5 });
    Mix m = mix((Mix){ 2.5, 17 });
    Nested n = nested((Nested){ { { 1.25f }, { -2.5f } } });
    int received = 0;

    empty(12, &received);
    if (received != 12 || n.a[0].x != -2.5f || n.a[1].x != 1.25f ||
        !varargs(9, 0, 1, 2, 3, 4, 5, 6, 7, 8))
        return 1;
    return !(p.x == 9.5 && p.y == 1.25 && m.x == 3.5 && m.y == 18 &&
             quadadd(1.25L, 2.5L) == 3.75L &&
             ninth(1, 2, 3, 4, 5, 6, 7, 8, 9) == 10);
}
#endif
