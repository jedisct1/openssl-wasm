#ifndef __LIBC_UNISTD_H
#define __LIBC_UNISTD_H

#include <__types.h>

__LIBC_BEGIN_DECLS

pid_t getpid(void);
uid_t getuid(void);
uid_t geteuid(void);
gid_t getgid(void);
gid_t getegid(void);

int getentropy(void *buf, size_t len);
int getpagesize(void);
int usleep(useconds_t usec);
unsigned int sleep(unsigned int sec);

__LIBC_END_DECLS

#endif
