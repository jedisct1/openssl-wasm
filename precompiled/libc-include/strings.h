#ifndef __LIBC_STRINGS_H
#define __LIBC_STRINGS_H

#include <__types.h>

__LIBC_BEGIN_DECLS

int strcasecmp(const char *a, const char *b);
int strncasecmp(const char *a, const char *b, size_t n);

__LIBC_END_DECLS

#endif
