#!/bin/bash -ex

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

# # build libpng
# if [ ! -f $home/libpng/stamp ]
# then
# 	if [ ! -f $ext/libpng/configure ]
# 	then
# 		pushd $ext/libpng
# 		./autogen.sh
# 		popd
# 	fi

# 	mkdir -p $home/libpng
# 	pushd $home/libpng
# 	PKG_CONFIG_PATH=$dist/lib/pkgconfig \
# 	PKG_CONFIG_SYSROOT_DIR=$dist \
# 	$ext/libpng/configure \
# 		CFLAGS="-O0" \
# 		--host=$SDK_TARGET \
# 		--target=$SDK_TARGET \
# 		--prefix="" \
# 		--with-sysroot=$dist \
# 		$SDK_LIBPNG_ARGS
# 	make
# 	make DESTDIR=$dist install
# 	touch stamp
# 	popd
# fi

# # build freetype
# if [ ! -f $home/freetype/stamp ]
# then
# 	pushd $ext/freetype
# 	./autogen.sh
# 	popd

# 	mkdir -p $home/freetype
# 	pushd $home/freetype
# 	PKG_CONFIG_PATH=$dist/lib/pkgconfig \
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

# adjust symlinks to relative paths
symlinks -cr $dist

# remove unused directories
rm -rf $dist/bin $dist/etc $dist/libexec $dist/sbin $dist/share $dist/var
