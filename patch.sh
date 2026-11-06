#! /bin/sh

cd openssl || exit 1
for patch in ../patches/*.patch; do
    patch -p1 <"$patch" || exit 1
done
