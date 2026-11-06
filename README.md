# OpenSSL (libcrypto and libssl) for WebAssembly

This is OpenSSL, compiled to WebAssembly (`wasm32-freestanding`).

Up-to-date. Maintained.

Related: [BoringSSL for WebAssembly](https://github.com/jedisct1/boringssl-wasm).

## Precompiled library

For convenience, [precompiled](precompiled/) libraries for WebAssembly can be directly downloaded from this repository.

They can be linked to C, Rust, Zig, etc. as regular static libraries:

- `precompiled/lib/libcrypto.a` and `precompiled/lib/libssl.a`: OpenSSL itself.
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
zig cc --target=wasm32-freestanding -O2 -fno-PIC \
    -isystem precompiled/libc-include -I precompiled/include \
    app.c precompiled/lib/libssl.a precompiled/lib/libcrypto.a precompiled/lib/libc-freestanding.a \
    -o app.wasm
```

Keep `-fno-PIC`: `zig cc` produces position-independent code by default on WebAssembly, and the libraries are not built that way.

## OpenSSL submodule

This repository includes OpenSSL as a submodule, with a few patches from the [patches](patches/) directory applied before building.
If you didn't clone it with the `--recursive` flag, the following command can be used to pull the submodule:

```sh
git submodule update --init --recursive --depth=1
```

## Dependencies

The only required dependencies to rebuild the library are:

* Perl - Required by OpenSSL to generate files
* [Zig](https://www.ziglang.org) - To compile C code to WebAssembly, and to build the C library

The current build uses Zig 0.18.
Zig no longer ships wasi-libc, which is why the target is `wasm32-freestanding` and why this repository brings its own C library.

## Building

```sh
./patch.sh
./build.sh
```

The resulting files can be found in the `precompiled` directory.

## Testing

```sh
./test/run.sh
```

This links [test/test.c](test/test.c) against the precompiled libraries and runs it with Wasmtime and Node.js, whichever are installed.
It checks the C library, a set of known-answer tests, key generation and signatures, ML-KEM, and a full TLS 1.3 handshake between two in-memory peers.

## Differences with a regular build

The libraries are built without threads, sockets, stdio, file I/O, or dynamic loading.
Certificates, keys and data have to come from memory, with `BIO_new_mem_buf()` and friends.

`RAND_priv_bytes()` and `RAND_pseudo_bytes()` read directly from the host's random source, and the DRBG used by `RAND_bytes()` is seeded from it too.

A WebAssembly module never exits, so OpenSSL never runs its global destructor.
Call `OPENSSL_cleanup()` explicitly if you need resources to be released.
