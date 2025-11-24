#!/bin/bash -ex

xwin_version="0.6.7"
dist="$(dirname "$0")/../dist/win"
bin="$(dirname "$0")/bin"
sdk_version="10.0.26100"
crt_version="14.44.17.14"
mkdir -p $bin

case "$(uname -s)" in
    Linux*)     xwin_prefix=xwin-$xwin_version-x86_64-unknown-linux-musl;;
    Darwin*)    xwin_prefix=xwin-$xwin_version-aarch64-apple-darwin;;
    *)          exit 1;
esac

curl --fail -L https://github.com/Jake-Shadle/xwin/releases/download/$xwin_version/$xwin_prefix.tar.gz | tar -xzv -C $bin --strip-components=1 $xwin_prefix/xwin


# with symlinks for case-sensitive file systems
dist="$(dirname "$0")/../dist/win"
rm -rf $dist
$bin/xwin --accept-license --cache-dir /tmp/xwincache --arch x86,x86_64,aarch64 --sdk-version $sdk_version --crt-version $crt_version splat --include-debug-libs --preserve-ms-arch-notation --output $dist

# without symlinks for case-insensitive file systems
dist="$(dirname "$0")/../dist/win.ci"
rm -rf $dist
$bin/xwin --accept-license --cache-dir /tmp/xwincache --arch x86,x86_64,aarch64 --sdk-version $sdk_version --crt-version $crt_version splat --disable-symlinks --include-debug-libs --preserve-ms-arch-notation --output $dist
