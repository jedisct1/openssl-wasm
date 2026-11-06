#ifndef __LIBC_STDLIB_H
#define __LIBC_STDLIB_H

#include <__types.h>

#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1
#define RAND_MAX 0x7fffffff
#define MB_CUR_MAX 1

typedef struct {
    int quot;
    int rem;
} div_t;

typedef struct {
    long quot;
    long rem;
} ldiv_t;

typedef struct {
    long long quot;
    long long rem;
} lldiv_t;

__LIBC_BEGIN_DECLS

void *malloc(size_t size);
void *calloc(size_t n, size_t size);
void *realloc(void *ptr, size_t size);
void *aligned_alloc(size_t alignment, size_t size);
int posix_memalign(void **ptr, size_t alignment, size_t size);
void free(void *ptr);

_Noreturn void abort(void);

char *getenv(const char *name);
char *secure_getenv(const char *name);

int atoi(const char *s);
long atol(const char *s);
long long atoll(const char *s);
long strtol(const char *__restrict s, char **__restrict end, int base);
unsigned long strtoul(const char *__restrict s, char **__restrict end, int base);
long long strtoll(const char *__restrict s, char **__restrict end, int base);
unsigned long long strtoull(const char *__restrict s, char **__restrict end, int base);

void qsort(void *base, size_t n, size_t size, int (*cmp)(const void *, const void *));
void *bsearch(const void *key, const void *base, size_t n, size_t size,
              int (*cmp)(const void *, const void *));

int abs(int n);
long labs(long n);
long long llabs(long long n);
div_t div(int num, int den);
ldiv_t ldiv(long num, long den);
lldiv_t lldiv(long long num, long long den);

__LIBC_END_DECLS

#endif
