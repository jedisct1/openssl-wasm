#! /bin/sh

NPROCESSORS=$(getconf NPROCESSORS_ONLN 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null)

cd openssl || exit 1

env \
    CROSS_COMPILE="" \
    AR="zig ar" \
    RANLIB="zig ranlib" \
    CC="zig cc --target=wasm32-wasi" \
    CFLAGS="-Ofast" \
    CPPFLAGS="-DUSE_TIMEGM=1" \
    LDFLAGS="-s" \
    ./Configure --prefix=/tmp/open \
    --banner="wasm32-wasi port" \
    no-asm \
    no-async \
    no-dgram \
    no-egd \
    no-ktls \
    no-module \
    no-pic \
    no-posix-io \
    no-quic \
    no-secure-memory \
    no-shared \
    no-sock \
    no-stdio \
    no-thread-pool \
    no-threads \
    no-tls \
    no-ui-console \
    no-weak-ssl-ciphers || exit 1

make "-j${NPROCESSORS}"

cd - || exit 1

mkdir -p precompiled/lib
mv openssl/*.a precompiled/lib

mkdir -p precompiled/include
cp -r openssl/include/openssl precompiled/include
