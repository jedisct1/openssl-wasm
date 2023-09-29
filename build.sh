#! /bin/sh

NPROCESSORS=$(getconf NPROCESSORS_ONLN 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null)

cd openssl || exit 1

env \
    CROSS_COMPILE="" \
    AR="zig ar" \
    RANLIB="zig ranlib" \
    CC="zig cc --target=wasm32-wasi" \
    CFLAGS="-Ofast -Werror -Qunused-arguments -Wno-shift-count-overflow" \
    CPPFLAGS="$CPPFLAGS -D_WASI_EMULATED_GETPID -Dgetuid=getpagesize -Dgeteuid=getpagesize -Dgetgid=getpagesize -Dgetegid=getpagesize" \
    CXXFLAGS="-Werror -Qunused-arguments -Wno-shift-count-overflow" \
    LDFLAGS="-s -lwasi-emulated-getpid" \
    ./Configure \
    --banner="wasm32-wasi port" \
    no-asm \
    no-async \
    no-egd \
    no-ktls \
    no-module \
    no-posix-io \
    no-secure-memory \
    no-shared \
    no-sock \
    no-stdio \
    no-thread-pool \
    no-threads \
    no-ui-console \
    no-weak-ssl-ciphers \
    wasm32-wasi || exit 1

make "-j${NPROCESSORS}"

cd - || exit 1

mkdir -p precompiled/lib
mv openssl/*.a precompiled/lib

mkdir -p precompiled/include
cp -r openssl/include/openssl precompiled/include
