# OpenSSL (libcrypto and libssl) for WebAssembly

This is OpenSSL, compiled to WebAssembly (`wasm32-freestanding`), optimized for it.

Up-to-date. Maintained.

Related: [BoringSSL for WebAssembly](https://github.com/jedisct1/boringssl-wasm).

## Precompiled library

For convenience, [precompiled](precompiled/) libraries for WebAssembly can be directly downloaded from this repository.

They can be linked to C, Rust, Zig, etc. as regular static libraries:

- `precompiled/lib/libcrypto.a` and `precompiled/lib/libssl.a`: OpenSSL itself.
- `precompiled/lib/wide-arithmetic/libcrypto.a`: a faster libcrypto for runtimes that support wide arithmetic, see below.
- `precompiled/lib/libc-freestanding.a`: a small C library covering what OpenSSL needs, see [libc/README.md](libc/README.md).
- `precompiled/include`: the OpenSSL headers.
- `precompiled/libc-include`: the C library headers, which the OpenSSL headers need when there is no other libc.

The C library gets randomness and time from the host through two WASI preview1 imports, `random_get` and `clock_time_get`.
WASI runtimes such as Wasmtime or Node.js provide them out of the box.

In a browser or any other JavaScript host, implementing those two functions is enough; [test/host.mjs](test/host.mjs) is a complete example.

If your environment already has a libc that follows the wasi-libc ABI, you can use it instead of `libc-freestanding.a`.
The headers were written to match that ABI, but that combination hasn't been tested.

Linking a C program:

```sh
zig cc --target=wasm32-freestanding -mcpu=lime1+simd128 -O2 -fno-PIC \
    -isystem precompiled/libc-include -I precompiled/include \
    app.c precompiled/lib/libssl.a precompiled/lib/libcrypto.a precompiled/lib/libc-freestanding.a \
    -o app.wasm
```

Keep `-fno-PIC`: `zig cc` produces position-independent code by default on WebAssembly, and the libraries are not built that way.

## WebAssembly features

Everything is compiled for `lime1+simd128`: the [lime1](https://github.com/WebAssembly/tool-conventions/blob/main/Lime.md) feature set, plus 128-bit SIMD.
All current browsers and WebAssembly runtimes support both.

`precompiled/lib/wide-arithmetic/libcrypto.a` additionally uses [wide arithmetic](https://github.com/WebAssembly/wide-arithmetic), which adds 64x64 to 128-bit multiplications and 128-bit additions.

That makes RSA and elliptic curves two to three times as fast.

To use it, link it instead of the regular libcrypto, and compile your own code with wide arithmetic too:

```sh
zig cc --target=wasm32-freestanding -mcpu=lime1+simd128+wide_arithmetic -O2 -fno-PIC \
    -isystem precompiled/libc-include -I precompiled/include \
    app.c precompiled/lib/libssl.a precompiled/lib/wide-arithmetic/libcrypto.a precompiled/lib/libc-freestanding.a \
    -o app.wasm
```

The headers and `libssl.a` are the same for both builds.

The resulting module only runs where wide arithmetic is supported.
Wasmtime needs `-W wide-arithmetic=y`, wasmer accepts it by default.
V8 (Node.js, Chrome) and JavaScriptCore (Bun, Safari) don't support it yet, so for browsers, use the regular libcrypto.

## Performance

Times in microseconds (lower is better), or MB/s for the ciphers, measured with [test/bench.c](test/bench.c).
The "wide" columns are Wasmtime with the wide arithmetic libcrypto.

```
+--------------------------+-------------------------------+-------------------------------+
|                          | Apple M5 Max                  | AMD Ryzen 7 7700, boost off   |
| operation                | Node.js | Wasmtime |    wide  | Node.js | Wasmtime |    wide  |
+--------------------------+---------+----------+----------+---------+----------+----------+
| RSA-2048 sign            |    2187 |     2213 |     1107 |    4672 |     4786 |     2389 |
| RSA-2048 verify          |      54 |       57 |       29 |     106 |      110 |       59 |
| RSA-4096 sign            |   14701 |    15111 |     7572 |   29240 |    29637 |    15815 |
| ECDSA P-256 sign         |      75 |       93 |       39 |     195 |      224 |       89 |
| ECDSA P-256 verify       |     170 |      220 |       77 |     446 |      573 |      176 |
| ECDH P-256               |     112 |      150 |       46 |     299 |      407 |      105 |
| X25519                   |      32 |       34 |       15 |      85 |       89 |       37 |
| Ed25519 sign             |      15 |       15 |       15 |      37 |       37 |       37 |
| ML-KEM-768 encapsulation |      12 |       13 |       13 |      29 |       26 |       26 |
| ML-DSA-65 sign           |     345 |      365 |      359 |     761 |      596 |      601 |
| AES-256-GCM (MB/s)       |     163 |      174 |      174 |     103 |      112 |      112 |
| ChaCha20-Poly1305 (MB/s) |     732 |      697 |      699 |     424 |      378 |      377 |
+--------------------------+---------+----------+----------+---------+----------+----------+
```

Node.js 26 and Wasmtime 50 on the M5, Node.js 22 and Wasmtime 40 on the Ryzen.

## OpenSSL submodule

This repository includes OpenSSL as a submodule, with a few patches from the [patches](patches/) directory applied before building.
If you didn't clone it with the `--recursive` flag, the following command can be used to pull the submodule:

```sh
git submodule update --init --recursive --depth=1
```

## Dependencies

The only required dependencies to rebuild the library are:

* Perl: required by OpenSSL to generate files
* [Zig](https://www.ziglang.org) to compile C code to WebAssembly, and to build the C library

Zig no longer ships wasi-libc, which is why the target is `wasm32-freestanding` and why this repository brings its own C library.

## Building

```sh
./patch.sh
./build.sh
```

The resulting files can be found in the `precompiled` directory.

## Differences with a regular build

The libraries are built without threads, sockets, stdio, file I/O, or dynamic loading.
They have no assembly code, but they include the constant-time 64-bit implementations of P-224, P-256, P-384 and P-521 (`enable-ec_nistp_64_gcc_128`).

Certificates, keys and data have to come from memory, with `BIO_new_mem_buf()` and friends.

`RAND_priv_bytes()` and `RAND_pseudo_bytes()` read directly from the host's random source, and the DRBG used by `RAND_bytes()` is seeded from it too.

A WebAssembly module never exits, so OpenSSL never runs its global destructor.
Call `OPENSSL_cleanup()` explicitly if you need resources to be released.
