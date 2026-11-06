#ifndef __LIBC_SYS_TIME_H
#define __LIBC_SYS_TIME_H

#include <__types.h>

__LIBC_BEGIN_DECLS

int gettimeofday(struct timeval *__restrict tv, void *__restrict tz);

__LIBC_END_DECLS

#endif
