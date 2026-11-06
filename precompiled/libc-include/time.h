#ifndef __LIBC_TIME_H
#define __LIBC_TIME_H

#include <__types.h>

#define CLOCKS_PER_SEC 1000000LL

#define CLOCK_REALTIME 0
#define CLOCK_MONOTONIC 1

struct tm {
    int tm_sec;
    int tm_min;
    int tm_hour;
    int tm_mday;
    int tm_mon;
    int tm_year;
    int tm_wday;
    int tm_yday;
    int tm_isdst;
    int tm_gmtoff;
    const char *tm_zone;
    int __tm_nsec;
};

__LIBC_BEGIN_DECLS

time_t time(time_t *t);
double difftime(time_t a, time_t b);
time_t mktime(struct tm *tm);
time_t timegm(struct tm *tm);
struct tm *gmtime(const time_t *t);
struct tm *gmtime_r(const time_t *__restrict t, struct tm *__restrict tm);
struct tm *localtime(const time_t *t);
struct tm *localtime_r(const time_t *__restrict t, struct tm *__restrict tm);
int clock_gettime(clockid_t clock, struct timespec *ts);
int nanosleep(const struct timespec *req, struct timespec *rem);

__LIBC_END_DECLS

#endif
