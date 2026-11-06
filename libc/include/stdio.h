#ifndef __LIBC_STDIO_H
#define __LIBC_STDIO_H

#include <stdarg.h>
#include <__types.h>

/*
 * There are no streams on wasm32-freestanding.
 * FILE only exists so that prototypes referring to it still compile.
 */
typedef struct _IO_FILE FILE;
typedef off_t fpos_t;

#define EOF (-1)
#define BUFSIZ 1024
#define FILENAME_MAX 4096

#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

__LIBC_BEGIN_DECLS

/* C99 conversions, except positional arguments and wide characters. */
int snprintf(char *__restrict s, size_t n, const char *__restrict fmt, ...);
int vsnprintf(char *__restrict s, size_t n, const char *__restrict fmt, va_list ap);
int sprintf(char *__restrict s, const char *__restrict fmt, ...);
int vsprintf(char *__restrict s, const char *__restrict fmt, va_list ap);

/* Integer, character and string conversions only, no floating point. */
int sscanf(const char *__restrict s, const char *__restrict fmt, ...);
int vsscanf(const char *__restrict s, const char *__restrict fmt, va_list ap);

__LIBC_END_DECLS

#endif
