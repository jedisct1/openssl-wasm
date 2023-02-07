# OpenSSL 3 (libcrypto and libtls) for WebAssembly

This is OpenSSL, compiled to WebAssembly/WASI.

Up-to-date. Maintained. 

## Precompiled library

For convenience, [precompiled files](precompiled/) libraries for WebAssembly can be directly downloaded from this repository.

They can be directly linked to C, Rust, Zig, etc. as any other static library.

## OpenSSL submodule

This repository includes an unmodified version of `OpenSSL` as a submodule. If you didn't clone it with the `--recursive` flag, the following command can be used to pull the submodule:

```sh
git submodule update --init --recursive --depth=1
```

## Dependencies

The only required dependencies to rebuild the library are:

* Perl - Required by OpenSSL to generate files
* [Zig](https://www.ziglang.org) - To compile C code to WebAssembly

## Building

```sh
./build.sh
```

The resulting files can be found in the `precompiled` directory.
