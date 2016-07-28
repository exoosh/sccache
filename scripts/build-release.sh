#!/bin/bash
set -e

if ! test -d "$1"; then
    echo "Usage: build-release.sh <destination directory>"
    exit 1
fi


pushd "$(dirname $0)/.."
system=$(uname -s)
destdir="$1/$system"
if test -d "$destdir"; then
    rm -rf "$destdir"
fi
mkdir -p "$destdir"
tmpdir=$(mktemp -d)
stagedir=$tmpdir/sccache2
mkdir $stagedir
cargo clean
case $system in
    MINGW*)
        cargo build --release && cargo test --release
        cp "${OPENSSL_LIB_DIR}/../"{ssleay32,libeay32}.dll "$stagedir"
        cp target/release/sccache.exe "$stagedir"
        compress=bz2
        ;;
    Linux)
        # Build using rust-musl-builder
        docker run --rm -it -v "$(pwd)":/home/rust/src ekidd/rust-musl-builder sh -c "cargo build --release && cargo test --release"
        cp target/x86_64-unknown-linux-musl/release/sccache "$stagedir"
        strip "$stagedir/sccache"
        compress=xz
        ;;
    Darwin)
        export MACOSX_DEPLOYMENT_TARGET=10.7 OPENSSL_STATIC=1
        cargo build --release && cargo test --release
        cp target/release/sccache "$stagedir"
        strip "$stagedir/sccache"
        compress=bz2
        ;;
    *)
        echo "Don't know how to build a release on this platform"
        exit 1
        ;;
esac

case ${compress} in
    bz2)
        cflag=j
        ;;
    xz)
        cflag=J
        ;;
    *)
        echo "Unhandled compression ${compress}"
        exit 1
        ;;
esac

git rev-parse HEAD > "$destdir/REV"
cd "$tmpdir"
tar c${cflag}vf sccache2.tar.${compress} sccache2
cp sccache2.tar.${compress} "$destdir"
popd
rm -rf "$tmpdir"
