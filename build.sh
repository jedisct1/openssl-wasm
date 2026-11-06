#! /bin/sh

NPROCESSORS=$(getconf NPROCESSORS_ONLN 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null)
LIBC_INCLUDE="$(pwd)/libc/include"

cd openssl || exit 1

env \
    CROSS_COMPILE="" \
    AR="zig ar" \
    RANLIB="zig ranlib" \
    CC="zig cc --target=wasm32-freestanding" \
    CFLAGS="-Ofast -fno-PIC -Werror -Qunused-arguments -Wno-shift-count-overflow" \
    CPPFLAGS="$CPPFLAGS -isystem $LIBC_INCLUDE -D_BSD_SOURCE" \
    CXXFLAGS="-Werror -Qunused-arguments -Wno-shift-count-overflow" \
    ./Configure \
    --banner="wasm32-freestanding port" \
    --with-rand-seed=getrandom \
    no-apps \
    no-asm \
    no-async \
    no-atexit \
    no-docs \
    no-dso \
    no-egd \
    no-ktls \
    no-module \
    no-posix-io \
    no-secure-memory \
    no-shared \
    no-sock \
    no-stdio \
    no-tests \
    no-thread-pool \
    no-threads \
    no-ui-console \
    no-weak-ssl-ciphers \
    wasm32-freestanding || exit 1

make "-j${NPROCESSORS}" build_libs || exit 1

cd - || exit 1

mkdir -p precompiled/lib
mv openssl/*.a precompiled/lib

zig build-lib -target wasm32-freestanding -O ReleaseFast -fno-PIC -fcompiler-rt -fstrip \
    libc/src/libc.zig -femit-bin=precompiled/lib/libc-freestanding.a || exit 1

mkdir -p precompiled/include
rm -rf precompiled/include/openssl
cp -r openssl/include/openssl precompiled/include

rm -rf precompiled/libc-include
cp -r libc/include precompiled/libc-include
