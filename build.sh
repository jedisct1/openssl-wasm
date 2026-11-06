#! /bin/sh

NPROCESSORS=$(getconf NPROCESSORS_ONLN 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null)
ROOT=$(pwd)
LIBC_INCLUDE="$ROOT/libc/include"

# The base libraries run on every runtime, browsers included.
# The wide arithmetic libcrypto needs a runtime that supports that proposal.
# It uses 64-bit limbs, and is two to three times as fast for RSA and elliptic curves.
BASE_CPU="lime1+simd128"
WIDE_CPU="lime1+simd128+wide_arithmetic"

configure() {
    rm -rf "build/$1"
    # Configure writes apps/include/configuration.h even with no-apps, without creating the directory.
    mkdir -p "build/$1/apps/include"
    cd "build/$1" || exit 1
    env \
        CROSS_COMPILE="" \
        AR="zig ar" \
        RANLIB="zig ranlib" \
        CC="zig cc --target=wasm32-freestanding" \
        CFLAGS="-Ofast -fno-PIC -mcpu=$2 -Werror -Qunused-arguments -Wno-shift-count-overflow" \
        CPPFLAGS="$CPPFLAGS -isystem $LIBC_INCLUDE -D_BSD_SOURCE" \
        CXXFLAGS="-Werror -Qunused-arguments -Wno-shift-count-overflow" \
        "$ROOT/openssl/Configure" \
        --banner="wasm32-freestanding port" \
        --with-rand-seed=getrandom \
        enable-ec_nistp_64_gcc_128 \
        no-apps \
        no-asm \
        no-async \
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
        "$3" || exit 1
    cd "$ROOT" || exit 1
}

configure base "$BASE_CPU" wasm32-freestanding
configure wide "$WIDE_CPU" wasm32-freestanding-wide
make -C build/base "-j${NPROCESSORS}" build_libs || exit 1
make -C build/wide build_generated || exit 1
make -C build/wide "-j${NPROCESSORS}" libcrypto.a || exit 1

# The two builds must only differ by their limb size, which libssl doesn't depend on.
# Their configuration.h files are merged, so that the headers pick the limb size
# that matches the libcrypto being linked.
BASE_CONF=build/base/include/openssl/configuration.h
WIDE_CONF=build/wide/include/openssl/configuration.h
if diff "$BASE_CONF" "$WIDE_CONF" | grep "^[<>]" |
    grep -v -E "^[<>] #  (define|undef) (BN_LLONG|SIXTY_FOUR_BIT|THIRTY_TWO_BIT)$"; then
    echo "The base and wide arithmetic builds differ by more than their limb size" >&2
    exit 1
fi
diff -D __wasm_wide_arithmetic__ "$BASE_CONF" "$WIDE_CONF" >build/configuration.h
[ $? -le 1 ] || exit 1

# libssl is shared by both builds, so it must not call anything that takes or returns a BN_ULONG.
# This needs an nm that reads wasm objects, such as llvm-nm, and is skipped otherwise.
if nm -u build/base/libssl.a >build/libssl-undefined.txt 2>/dev/null; then
    for f in $(grep BN_ULONG openssl/include/openssl/bn.h | grep -o -E "BN_[A-Za-z0-9_]+ *\(" | tr -d " ("); do
        if grep -q -w "$f" build/libssl-undefined.txt; then
            echo "libssl calls $f, which depends on the limb size" >&2
            exit 1
        fi
    done
fi

rm -rf precompiled/lib || exit 1
mkdir -p precompiled/lib/wide-arithmetic || exit 1
cp build/base/libcrypto.a build/base/libssl.a precompiled/lib/ || exit 1
cp build/wide/libcrypto.a precompiled/lib/wide-arithmetic/ || exit 1

# zig build-lib names archive members after their path in the Zig cache.
# Repack them under plain names, so that the archive is reproducible.
rm -rf build/libc || exit 1
mkdir -p build/libc || exit 1
zig build-lib -target wasm32-freestanding -mcpu "$BASE_CPU" -O ReleaseFast -fno-PIC -fcompiler-rt -fstrip \
    libc/src/libc.zig -femit-bin=build/libc/libc.a || exit 1
for member in $(zig ar t build/libc/libc.a); do
    zig ar p build/libc/libc.a "$member" >"build/libc/$(basename "$member")" || exit 1
done
(cd build/libc && zig ar rcs "$ROOT/precompiled/lib/libc-freestanding.a" libc_zcu.o compiler_rt.o) || exit 1

rm -rf precompiled/include/openssl || exit 1
mkdir -p precompiled/include/openssl || exit 1
cp openssl/include/openssl/*.h build/base/include/openssl/*.h precompiled/include/openssl/ || exit 1
cp build/configuration.h precompiled/include/openssl/configuration.h || exit 1

rm -rf precompiled/libc-include || exit 1
cp -r libc/include precompiled/libc-include || exit 1
