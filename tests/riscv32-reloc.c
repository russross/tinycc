int base[8];
int *plus = base + 3;
int *minus = base - 1;
typedef struct { int *ptr; } Pair;
Pair copy = (Pair){ base + 2 };
