#!/bin/bash -ex

dist="$(dirname "$0")/../dist/osx"
mkdir -p $dist

url="https://github.com/phracker/MacOSX-SDKs/releases/download/11.0-11.1/MacOSX11.1.sdk.tar.xz"
curl --fail -L $url | tar xJv -C $dist --strip-components=1

rm -f $dist/System/Library/Frameworks/Ruby.framework/Versions/2.6/Headers/ruby/ruby
rm -f $dist/System/Library/Frameworks/Ruby.framework/Headers/ruby/ruby/
