#include <__types.h>

#undef assert

#ifdef NDEBUG
# define assert(x) ((void)0)
#else
# define assert(x) ((void)((x) || (__assert_fail(#x, __FILE__, __LINE__, __func__), 0)))
#endif

#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L && __STDC_VERSION__ < 202311L \
    && !defined(__cplusplus)
# undef static_assert
# define static_assert _Static_assert
#endif

#ifndef __LIBC_ASSERT_H
#define __LIBC_ASSERT_H
__LIBC_BEGIN_DECLS
_Noreturn void __assert_fail(const char *expr, const char *file, int line, const char *func);
__LIBC_END_DECLS
#endif
