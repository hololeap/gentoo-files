# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6
JAVA_PKG_IUSE="doc examples"

inherit git-r3 java-pkg-2 java-ant-2

S="${WORKDIR}/${P}/build"

DESCRIPTION="Open-source electronics prototyping platform"
HOMEPAGE="http://www.arduino.cc/"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS=""
IUSE=""

EGIT_REPO_URI="https://github.com/arduino/Arduino"

RDEPEND="
	dev-embedded/avrdude:=
	dev-embedded/uisp:=
	>=virtual/jre-1.6
	cross-avr/gcc:=
	cross-avr/avr-libc:="

DEPEND="
	>=virtual/jdk-1.6"
