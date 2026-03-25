# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools multiprocessing flag-o-matic git-r3

DESCRIPTION="NetBSD's rumpkernel for the Hurd"
HOMEPAGE="https://salsa.debian.org/hurd-team/rumpkernel"

EGIT_REPO_URI="https://salsa.debian.org/hurd-team/rumpkernel.git"
if [[ ${PV} != *9999* ]] ; then
	EGIT_COMMIT="e7319044849aa613b3910533e5eb9c59dbfc69c6"
	KEYWORDS="~amd64 ~x86"
else
	# TODO: and then what?
fi

# A lot from NetBSD, see:
# https://salsa.debian.org/hurd-team/rumpkernel/-/blob/master/debian/copyright
LICENSE="Apache-2 Boost-1.0 BSD BSD-2 BSD-4 CDDL GPL-1 GPL-2+ GPL-3+ ISC
	LGPL2+ MIT public-domain ZLIB"

SLOT="0"
# XXX
IUSE=""

# XXX
DEPEND="
	dev-util/mig
"
RDEPEND="${DEPEND}"
BDEPEND="virtual/pkgconfig" # XXX

PATCHES=(
	"${FILESDIR}"/${PN}-0_p20250111_p6-bsd-own-mk-no-sysroot.patch
)

NBMAKE=${S}/buildrump.sh/src/obj/tooldir/bin/nbmake-i386

src_prepare() {
	local patches=( $(<${S}/debian/patches/series) )
	patches=( ${patches[@]/#/${S}/debian/patches/} )
	eapply ${patches[@]}
	default
}

src_configure() {
	#mkdir -p obj || die "Couldn't make obj dir"

	# TODO: conflict with -pg but we might not need -pg to begin with
	filter-flags -fomit-frame-pointer
	export HOST_CC=gcc
	export HOST_CPPFLAGS=-D_GNU_SOURCE
	export TARGET_AR=${CHOST}-ar
	export TARGET_CC=${CHOST}-gcc
	export TARGET_CXX=${CHOST}-g++
	export TARGET_LD=${CHOST}-ld
	export TARGET_MIG=${CHOST}-mig
	export TARGET_NM=${CHOST}-nm
	export MIG=${CHOST}-mig
	export _GCC_CRTENDS= _GCC_CRTEND= _GCC_CRTBEGINS= _GCC_CRTBEGIN= _GCC_CRTI= _GCC_CRTN=
	export BSDOBJDIR=${S}/obj

	cd "${S}"/buildrump.sh/src/lib/librumpuser || die "Couldn't change to the build directory"
	econf
}

src_compile() {
	cd buildrump.sh/src || die "Couldn't change to the build directory"
	mkdir -p obj || die "Couldn't make obj dir"

	local mybuildshargs=(
		-V TOOLS_BUILDRUMP=yes
		-V MKBINUTILS=no
		-V MKGDB=no
		-V MKGROFF=no
		-V MKDTRACE=no
		-V MKZFS=no
		-V TOPRUMP="${S}"/buildrump.sh/src/sys/rump
		-V BUILDRUMP_CPPFLAGS=-Wno-error=stringop-overread
		-V RUMPUSER_EXTERNAL_DPLIBS=pthread
		-V CPPFLAGS="-I../../obj/destdir.i386/usr/include -I${S}/buildrump.sh/src/obj/destdir.i386/usr/include -D_FILE_OFFSET_BITS=64 -DRUMP_REGISTER_T=int -DRUMPUSER_CONFIG=yes -DNO_PCI_MSI_MSIX=yes -DNUSB_DMA=1 -DPAE -DBUFPAGES=16 -U_FORTIFY_SOURCE"
		-V CWARNFLAGS="-Wno-error=maybe-uninitialized -Wno-error=address-of-packed-member -Wno-error=unused-variable -Wno-error=stack-protector -Wno-error=array-parameter -Wno-error=array-bounds -Wno-error=stringop-overflow -Wno-error=int-to-pointer-cast -Wno-error=incompatible-pointer-types -Wno-error=unterminated-string-initialization -Wno-error=format-nonliteral -Wno-error=sign-compare"

		-V TARGET_LDADD="-Wl,-v -v "
		-V _GCC_CRTENDS="" -V _GCC_CRTEND=""
		-V _GCC_CRTBEGINS="" -V _GCC_CRTBEGIN=""
		-V _GCC_CRTI="" -V _GCC_CRTN=""
		-V MIG=${CHOST}-mig

		# crossbuild shenananigans???
		-m i386
		-U -u
		-j $(get_makeopts_jobs)
		-T ./obj/tooldir
	)

	# The Makefiles scattered across NetBSD use $S everywhere. So we
	# will get rid of this. Otherwise, you won't see some things build
	# in the correct directory. Thank you sam
	local _S=${S} ; unset S
	./build.sh "${mybuildshargs[@]}" tools rump || die "rumpkernel's ./build.sh failed"

	cd ${_S}/buildrump.sh/src/lib/librumpuser || die "couldn't cd"
	RUMPRUN=true ${NBMAKE} -j $(get_makeopts_jobs) dependall

	cd ${_S}/pci-userspace/src-gnu || die "couldn't cd"
	${NBMAKE} -j $(get_makeopts_jobs) dependall
}

src_install() {
	: # TODO
}
