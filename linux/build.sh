#!/bin/bash -ex
# version:1

export sdk=$(dirname $(readlink -f $0))
export ext=$(dirname $sdk)/ext

# if not passed a target, recurse into available targets
rid=$1
if [ -z "$rid" ]
then
	pushd $sdk
	for i in $(ls */sdk.config | cut -d'/' -f1);
	do
		$sdk/build.sh $i
	done
	popd
	exit
fi

# common directories
home=$sdk/$rid
dist=$(dirname $sdk)/dist/$rid
root=$home/root

echo $dist
# include ct-nt variable
source $home/sdk.config

mkdir -p $dist
rm -f $dist/usr
ln -s . $dist/usr

# copy Linux headers for distribution
if [ ! -f $home/linux/stamp ]
then
	pushd $ext/linux
	make headers_install ARCH=$SDK_KERNEL_ARCH INSTALL_HDR_PATH=$home/linux
	popd
	pushd $home/linux
	mkdir -p $dist/include
	cp -rv include/* $dist/include
	touch stamp
	popd
fi

# build crosstool-ng if not already built
if [ ! -f $sdk/crosstool-ng/bin/ct-ng ]
then
	pushd $ext/crosstool-ng
	./bootstrap
	./configure --prefix=$sdk/crosstool-ng
	make install
	popd
fi
export PATH=$sdk/crosstool-ng/bin:$PATH

# build cross compiler
if [ ! -f $home/ct-ng-stamp ]
then
	mkdir -p /tmp/ctngsrc
	pushd $home
	ct-ng upgradeconfig
	ct-ng build
	touch ct-ng-stamp
	popd
fi

# use tools from root
export PATH=$root/bin:$PATH
echo $PATH

# SDK requires GLIBC
if [ $SDK_LIBC == "glibc" ]
then
	if [ ! -f $home/glibc/stamp ]
	then
		mkdir -p $home/glibc
		pushd $home/glibc
		$ext/glibc/configure \
			CFLAGS="-O2" \
			--host=$SDK_TARGET \
			--target=$SDK_TARGET \
			--prefix="" \
			--with-sysroot=$root \
			--with-headers=$dist/include \
			--disable-nls --disable-multilib --disable-selinux --disable-profile --disable-tunables
		make -j
		make DESTDIR=$dist install
		touch stamp
		popd
	fi

	# build GCC for distribution
	if [ ! -f $home/gcc/stamp ]
	then
		# rely on built in versions of libraries
		pushd $ext/gcc
		./contrib/download_prerequisites
		popd

		mkdir -p $home/gcc
		pushd $home/gcc
		$ext/gcc/configure \
			CFLAGS="-O0" \
			--host=$SDK_TARGET \
			--target=$SDK_TARGET \
			--prefix="" \
			--with-sysroot=$dist \
			--with-native-system-header-dir=/include \
			--disable-bootstrap --disable-nls --disable-multilib --enable-languages=c,c++ \
			$SDK_GCC_ARGS
		make all-target-libgcc all-target-libstdc++-v3
		make DESTDIR=$dist install-target-libgcc install-target-libstdc++-v3
		touch stamp
		popd
	fi
fi

# SDK requires musl
if [ $SDK_LIBC == "musl" ]
then
	# build musl for distribution
	if [ ! -f $home/musl/stamp ]
	then
		mkdir -p $home/musl
		pushd $home/musl
		$ext/musl/configure \
			CROSS_COMPILE=$SDK_TARGET- \
			CFLAGS="-O0" \
			--host=$SDK_TARGET \
			--target=$SDK_TARGET \
			--prefix="" \
			$SDK_MUSL_ARGS
		make
		make DESTDIR=$dist install
		ln -sf libc.so $dist/lib/ld-musl*
		touch stamp
		popd
	fi
fi

# build zlib
if [ ! -f $home/zlib/stamp ]
then
	mkdir -p $home/zlib
	pushd $home/zlib
	PKG_CONFIG_PATH=$dist/lib/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	CROSS_PREFIX=$SDK_TARGET- \
	$ext/zlib/configure \
		--prefix="" \
		$SDK_ZLIB_ARGS
	make
	make DESTDIR=$dist install
	touch stamp
	popd
fi

# build ncurses
if [ ! -f $home/ncurses/stamp ]
then
	if [ ! -f $ext/ncurses/configure ]
	then
		pushd $ext/ncurses
		NOCONFIGURE=1 ./autogen.sh
		popd
	fi

	mkdir -p $home/ncurses
	pushd $home/ncurses
	PKG_CONFIG_PATH=$dist/lib/pkgconfig:$dist/share/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	$ext/ncurses/configure \
 		--host=$SDK_TARGET \
 		--target=$SDK_TARGET \
 		--prefix="" \
 		--with-sysroot=$dist \
		--with-shared \
		--without-debug \
		--enable-echo \
		--disable-rpath \
		--disable-stripping \
		--enable-const \
		--enable-pc-files \
		--with-ticlib=tic \
		--with-termlib=tinfo \
		--without-ada \
		--without-tests \
		--without-progs \
		$SDK_NCURSES_ARGS
	make
	make DESTDIR=$dist install
	touch stamp
	popd
fi

# build libffi
if [ ! -f $home/libffi/stamp ]
then
	if [ ! -f $ext/libffi/configure ]
	then
		pushd $ext/libffi
		NOCONFIGURE=1 ./autogen.sh
		popd
	fi

	mkdir -p $home/libffi
	pushd $home/libffi
	PKG_CONFIG_PATH=$dist/lib/pkgconfig:$dist/share/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	$ext/libffi/configure \
 		--host=$SDK_TARGET \
 		--target=$SDK_TARGET \
 		--prefix="" \
 		--with-sysroot=$dist \
		$SDK_LIBFFI_ARGS
	make
	make DESTDIR=$dist install
	touch stamp
	popd
fi

## build cpython
#if [ ! -f $home/cpython/stamp ]
#then
#	mkdir -p $home/cpython
#	pushd $home/cpython
#	echo "ac_cv_file__dev_ptmx=no" >  config.site
#	echo "ac_cv_file__dev_ptc=no"  >> config.site
#	CONFIG_SITE=./config.site \
#	PKG_CONFIG_PATH=$dist/lib/pkgconfig:$dist/share/pkgconfig \
#	PKG_CONFIG_SYSROOT_DIR=$dist \
#	$ext/cpython/configure \
#		--build=`gcc -print-multiarch` \
# 		--host=$SDK_TARGET \
# 		--target=$SDK_TARGET \
# 		--prefix="" \
#		--disable-ipv6 \
#		--with-config-site=./CONFIG_SITE
#		$SDK_CPYTHON_ARGS
#	make
#	make DESTDIR=$dist install
#	touch stamp
#	popd
#fi

# build util-linux
if [ ! -f $home/util-linux/stamp ]
then
	if [ ! -f $ext/util-linux/configure ]
	then
		pushd $ext/util-linux
		NOCONFIGURE=1 ./autogen.sh
		popd
	fi

	mkdir -p $home/util-linux
	pushd $home/util-linux
	PKG_CONFIG_PATH=$dist/lib/pkgconfig:$dist/share/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	CFLAGS="--sysroot=$dist -I$dist/include" \
	CPPFLAGS="--sysroot=$dist -I$dist/include" \
	LDFLAGS="--sysroot=$dist -L$dist/lib" \
	$ext/util-linux/configure \
 		--host=$SDK_TARGET \
 		--target=$SDK_TARGET \
 		--prefix="" \
 		--with-sysroot=$dist \
		--without-python \
		--disable-login \
		--disable-nologin \
		--disable-kill \
		--disable-chfn-chsh \
		--disable-cal \
		--disable-libmount \
		--disable-mount \
		--disable-libblkid \
		--disable-libfdisk \
		$SDK_UTIL_LINUX_ARGS
	make
	fakeroot make DESTDIR=$dist install
	touch stamp
	popd
fi

# build libpng
if [ ! -f $home/libpng/stamp ]
then
	if [ ! -f $ext/libpng/configure ]
	then
		pushd $ext/libpng
		NOCONFIGURE=1 ./autogen.sh
		popd
	fi

	mkdir -p $home/libpng
	pushd $home/libpng
	PKG_CONFIG_PATH=$dist/lib/pkgconfig:$dist/lib/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	CFLAGS="--sysroot=$dist -I$dist/include" \
	CPPFLAGS="--sysroot=$dist -I$dist/include" \
	LDFLAGS="--sysroot=$dist -L$dist/lib" \
	$ext/libpng/configure \
		--host=$SDK_TARGET \
		--target=$SDK_TARGET \
		--prefix="" \
		--includedir=$dist/include \
		--with-sysroot=$dist \
		--with-zlib-prefix=$dist \
		$SDK_LIBPNG_ARGS
	make
	make DESTDIR=$dist install
	touch stamp
	popd
fi

# # build freetype
# if [ ! -f $home/freetype/stamp ]
# then
# 	pushd $ext/freetype
# 	NOCONFIGURE=1 ./autogen.sh
# 	popd
#
# 	mkdir -p $home/freetype
# 	pushd $home/freetype
# 	PKG_CONFIG_PATH=$dist/share/pkgconfig:$dist/lib/pkgconfig \
# 	PKG_CONFIG_SYSROOT_DIR=$dist \
# 	$ext/freetype/configure \
# 		CFLAGS="-O0" \
# 		--host=$SDK_TARGET \
# 		--target=$SDK_TARGET \
# 		--prefix="" \
# 		--with-sysroot=$dist \
# 		$SDK_FREETYPE_ARGS
# 	make
# 	make DESTDIR=$dist install
# 	touch stamp
# 	popd
# fi

# # build libexpat
# if [ ! -f $home/libexpat/stamp ]
# then
# 	pushd $ext/libexpat/expat
# 	./buildconf.sh
# 	popd

# 	mkdir -p $home/libexpat/expat
# 	pushd $home/libexpat
# 	PKG_CONFIG_PATH=$dist/lib/pkgconfig \
# 	PKG_CONFIG_SYSROOT_DIR=$dist \
# 	$ext/libexpat/expat/configure \
# 		CFLAGS="-O0" \
# 		--host=$SDK_TARGET \
# 		--target=$SDK_TARGET \
# 		--prefix="" \
# 		--with-sysroot=$dist \
# 		$SDK_LIBEXPAT_ARGS
# 	make
# 	make DESTDIR=$dist install
# 	touch stamp
# 	popd
# fi

# # build fontconfig
# if [ ! -f $home/fontconfig/stamp ]
# then
# 	pushd $ext/fontconfig
# 	NOCONFIGURE=1 ./autogen.sh
# 	popd

# 	mkdir -p $home/fontconfig
# 	pushd $home/fontconfig
# 	PKG_CONFIG_PATH=$dist/lib/pkgconfig \
# 	PKG_CONFIG_SYSROOT_DIR=$dist \
# 	$ext/fontconfig/configure \
# 		CFLAGS="-O0" \
# 		--host=$SDK_TARGET \
# 		--target=$SDK_TARGET \
# 		--prefix="" \
# 		--with-sysroot=$dist \
# 		$SDK_FONTCONFIG_ARGS
# 	make
# 	make DESTDIR=$dist install
# 	touch stamp
# 	popd
# fi

# build ALSA
if [ ! -f $home/alsa-lib/stamp ]
then
	pushd $ext/alsa-lib
	touch ltconfig
	libtoolize --force --copy --automake
	aclocal $ACLOCAL_FLAGS
	autoheader
	automake --foreign --copy --add-missing
	touch depcomp           # seems to be missing for old automake
	autoconf
	popd

	mkdir -p $home/alsa-lib
	pushd $home/alsa-lib
	PKG_CONFIG_PATH=$dist/lib/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	$ext/alsa-lib/configure \
		CFLAGS="-O0" \
		--host=$SDK_TARGET \
		--target=$SDK_TARGET \
		--prefix="" \
		--with-sysroot=$dist \
		--disable-ucm \
		--disable-topology \
		$SDK_ALSA_ARGS
	make
	make DESTDIR=$dist install
	touch stamp
	popd
fi

# build xorgproto
if [ ! -f $home/xorgproto/stamp ]
then
	mkdir -p $home/xorgproto
	pushd $home/xorgproto
	mkdir -p build
	pushd build
	meson setup --prefix=/ $ext/xorgproto
	ninja
	DESTDIR=$dist ninja install
	popd
	touch stamp
	popd
fi

# build xcbproto
if [ ! -f $home/xcbproto/stamp ]
then
 	pushd $ext/xcbproto
 	NOCONFIGURE=1 ./autogen.sh --prefix=""
 	popd

	mkdir -p $home/xcbproto
	pushd $home/xcbproto
	PKG_CONFIG_PATH=$dist/lib/pkgconfig:$dist/share/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	$ext/xcbproto/configure \
		--host=$SDK_TARGET \
		--target=$SDK_TARGET \
		--prefix="" \
		--with-sysroot=$dist \
		$SDK_XCBPROTO_ARGS
	make
	make DESTDIR=$dist install
	touch stamp
	popd
fi

# build libxdmcp
if [ ! -f $home/libxdmcp/stamp ]
then
 	pushd $ext/libxdmcp
 	NOCONFIGURE=1 ./autogen.sh --prefix=""
 	popd

	mkdir -p $home/libxdmcp
	pushd $home/libxdmcp
	PKG_CONFIG_PATH=$dist/lib/pkgconfig:$dist/share/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	$ext/libxdmcp/configure \
		--host=$SDK_TARGET \
		--target=$SDK_TARGET \
		--prefix="" \
		--with-sysroot=$dist \
		$SDK_LIBXDMCP_ARGS
	make
	make DESTDIR=$dist install
	touch stamp
	popd
fi

# build libxtrans
if [ ! -f $home/libxtrans/stamp ]
then
 	pushd $ext/libxtrans
 	NOCONFIGURE=1 ./autogen.sh --prefix=""
 	popd

	mkdir -p $home/libxtrans
	pushd $home/libxtrans
	PKG_CONFIG_PATH=$dist/lib/pkgconfig:$dist/share/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	$ext/libxtrans/configure \
		--host=$SDK_TARGET \
		--target=$SDK_TARGET \
		--prefix="" \
		--with-sysroot=$dist \
		$SDK_LIBXTRANS_ARGS
	make
	make DESTDIR=$dist install
	touch stamp
	popd
fi

# build libxau
if [ ! -f $home/libxau/stamp ]
then
 	pushd $ext/libxau
 	NOCONFIGURE=1 ./autogen.sh --prefix=""
 	popd

	mkdir -p $home/libxau
	pushd $home/libxau
	PKG_CONFIG_PATH=$dist/lib/pkgconfig:$dist/share/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	$ext/libxau/configure \
		--host=$SDK_TARGET \
		--target=$SDK_TARGET \
		--prefix="" \
		--with-sysroot=$dist \
		$SDK_LIBXAU_ARGS
	make
	make DESTDIR=$dist install
	touch stamp
	popd
fi

# build libxcb
if [ ! -f $home/libxcb/stamp ]
then
 	pushd $ext/libxcb
 	NOCONFIGURE=1 ./autogen.sh --prefix=""
 	popd

	mkdir -p $home/libxcb
	pushd $home/libxcb
	PKG_CONFIG_PATH=$dist/lib/pkgconfig:$dist/share/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	LDFLAGS="--sysroot=$dist" \
	$ext/libxcb/configure \
		--host=$SDK_TARGET \
		--target=$SDK_TARGET \
		--prefix="" \
		--with-sysroot=$dist \
		--disable-static \
		$SDK_LIBXCB_ARGS
	make
	make DESTDIR=$dist install
	touch stamp
	popd
fi

# build libx11
if [ ! -f $home/libx11/stamp ]
then
 	pushd $ext/libx11
 	NOCONFIGURE=1 ./autogen.sh --prefix=$dist
 	popd

	mkdir -p $home/libx11
	mkdir -p $dist/usr/include/X11
	pushd $home/libx11
	PKG_CONFIG_PATH=$dist/lib/pkgconfig:$dist/share/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	LDFLAGS="--sysroot=$dist" \
	$ext/libx11/configure \
		--host=$SDK_TARGET \
		--target=$SDK_TARGET \
		--prefix="" \
		--with-sysroot=$dist \
		--with-keysymdefdir=$dist/include/X11 \
		--enable-malloc0returnsnull \
		$SDK_LIBX11_ARGS
	make
	make DESTDIR=$dist install
	touch stamp
	popd
fi

# build libice
if [ ! -f $home/libice/stamp ]
then
 	pushd $ext/libice
 	NOCONFIGURE=1 ./autogen.sh --prefix=$dist
 	popd

	mkdir -p $home/libice
	pushd $home/libice
	PKG_CONFIG_PATH=$dist/lib/pkgconfig:$dist/share/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	LDFLAGS="--sysroot=$dist" \
	$ext/libice/configure \
		--host=$SDK_TARGET \
		--target=$SDK_TARGET \
		--prefix="" \
		--with-sysroot=$dist \
		--enable-malloc0returnsnull \
		$SDK_LIBICE_ARGS
	make
	make DESTDIR=$dist install
	touch stamp
	popd
fi

# build libsm
if [ ! -f $home/libsm/stamp ]
then
 	pushd $ext/libsm
 	NOCONFIGURE=1 ./autogen.sh --prefix=$dist
 	popd

	mkdir -p $home/libsm
	pushd $home/libsm
	PKG_CONFIG_PATH=$dist/lib/pkgconfig:$dist/share/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	LDFLAGS="--sysroot=$dist" \
	$ext/libsm/configure \
		--host=$SDK_TARGET \
		--target=$SDK_TARGET \
		--prefix="" \
		--with-sysroot=$dist \
		--enable-malloc0returnsnull \
		$SDK_LIBSM_ARGS
	make
	make DESTDIR=$dist install
	touch stamp
	popd
fi

# build libxt
if [ ! -f $home/libxt/stamp ]
then
 	pushd $ext/libxt
 	NOCONFIGURE=1 ./autogen.sh --prefix=$dist
 	popd

	mkdir -p $home/libxt
	pushd $home/libxt
	PKG_CONFIG_PATH=$dist/lib/pkgconfig:$dist/share/pkgconfig \
	PKG_CONFIG_SYSROOT_DIR=$dist \
	LDFLAGS="--sysroot=$dist" \
	$ext/libxt/configure \
		--host=$SDK_TARGET \
		--target=$SDK_TARGET \
		--prefix="" \
		--with-sysroot=$dist \
		--enable-malloc0returnsnull \
		$SDK_LIBXT_ARGS
	make
	make DESTDIR=$dist install
	touch stamp
	popd
fi

# adjust symlinks to relative paths
symlinks -cr $dist

# remove unused directories and files
rm -rf $dist/bin $dist/etc $dist/libexec $dist/sbin $dist/var $dist/home $dist/share $dist/usr
