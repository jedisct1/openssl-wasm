#!/bin/sh
# in other to build it for https://github.com/wasix-org/wasix-libc we need these flags:
export CFLAGS=" -Xclang -target-feature -Xclang +atomics -Xclang -target-feature -Xclang +bulk-memory"
export CPPFLAGS="-Xclang -target-feature -Xclang +atomics -Xclang -target-feature -Xclang +bulk-memory" 
./build.sh
