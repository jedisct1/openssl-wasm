#ifndef __LIBC_FCNTL_H
#define __LIBC_FCNTL_H

#include <sys/stat.h>

/* Flag values copied from wasi-libc. */
#define O_APPEND 0x0001
#define O_DSYNC 0x0002
#define O_NONBLOCK 0x0004
#define O_RSYNC 0x0008
#define O_SYNC 0x0010
#define O_CREAT (0x0001 << 12)
#define O_DIRECTORY (0x0002 << 12)
#define O_EXCL (0x0004 << 12)
#define O_TRUNC (0x0008 << 12)
#define O_NOFOLLOW 0x01000000
#define O_EXEC 0x02000000
#define O_RDONLY 0x04000000
#define O_SEARCH 0x08000000
#define O_WRONLY 0x10000000
#define O_CLOEXEC 0
#define O_NOCTTY 0
#define O_RDWR (O_RDONLY | O_WRONLY)
#define O_ACCMODE (O_EXEC | O_RDWR | O_SEARCH)

#define F_GETFD 1
#define F_SETFD 2
#define F_GETFL 3
#define F_SETFL 4
#define FD_CLOEXEC 1

__LIBC_BEGIN_DECLS

int open(const char *path, int flags, ...);

__LIBC_END_DECLS

#endif
