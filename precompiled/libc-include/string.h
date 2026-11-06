#ifndef __LIBC_STRING_H
#define __LIBC_STRING_H

#include <__types.h>

__LIBC_BEGIN_DECLS

void *memcpy(void *__restrict dst, const void *__restrict src, size_t n);
void *memmove(void *dst, const void *src, size_t n);
void *memset(void *dst, int c, size_t n);
int memcmp(const void *a, const void *b, size_t n);
void *memchr(const void *s, int c, size_t n);
void *memrchr(const void *s, int c, size_t n);
void *memmem(const void *haystack, size_t haystack_len, const void *needle, size_t needle_len);

size_t strlen(const char *s);
size_t strnlen(const char *s, size_t max);
char *strcpy(char *__restrict dst, const char *__restrict src);
char *strncpy(char *__restrict dst, const char *__restrict src, size_t n);
char *strcat(char *__restrict dst, const char *__restrict src);
char *strncat(char *__restrict dst, const char *__restrict src, size_t n);
int strcmp(const char *a, const char *b);
int strncmp(const char *a, const char *b, size_t n);
int strcoll(const char *a, const char *b);
char *strchr(const char *s, int c);
char *strrchr(const char *s, int c);
char *strstr(const char *haystack, const char *needle);
size_t strspn(const char *s, const char *accept);
size_t strcspn(const char *s, const char *reject);
char *strpbrk(const char *s, const char *accept);
char *strtok(char *__restrict s, const char *__restrict sep);
char *strtok_r(char *__restrict s, const char *__restrict sep, char **__restrict state);
char *strdup(const char *s);
char *strndup(const char *s, size_t n);
char *strerror(int err);
int strerror_r(int err, char *buf, size_t len);

__LIBC_END_DECLS

#endif
