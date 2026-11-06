#ifndef __LIBC_TYPES_H
#define __LIBC_TYPES_H

/* Same sizes as wasi-libc, so objects built against these headers can be linked with it. */

#include <stddef.h>

typedef long ssize_t;
typedef long long off_t;
typedef long long time_t;
typedef long long suseconds_t;
typedef long long clock_t;
typedef int clockid_t;
typedef int pid_t;
typedef unsigned int uid_t;
typedef unsigned int gid_t;
typedef unsigned int mode_t;
typedef unsigned long long dev_t;
typedef unsigned long long ino_t;
typedef unsigned long long nlink_t;
typedef long blksize_t;
typedef long long blkcnt_t;
typedef unsigned int useconds_t;

struct timespec {
    time_t tv_sec;
    long tv_nsec;
};

struct timeval {
    time_t tv_sec;
    suseconds_t tv_usec;
};

#ifdef __cplusplus
# define __LIBC_BEGIN_DECLS extern "C" {
# define __LIBC_END_DECLS }
#else
# define __LIBC_BEGIN_DECLS
# define __LIBC_END_DECLS
#endif

#endif
