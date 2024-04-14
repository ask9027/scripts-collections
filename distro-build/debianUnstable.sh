dist_name="Debian Unstable"

# Put only current stable version here!
dist_version="sid"

bootstrap_distribution() {
	sudo rm -f "${ROOTFS_DIR}"/debian-"${dist_version}"-*.tar.xz

	for arch in arm64 armhf i386 amd64; do
		sudo rm -rf "${WORKDIR}/debian-${dist_version}-$(translate_arch "$arch")"
		sudo debootstrap \
			--arch=${arch} \
			--variant=minbase \
			--components="main,contrib" \
			--include="ca-certificates,locales" \
			"${dist_version}" \
			"${WORKDIR}/debian-${dist_version}-$(translate_arch "$arch")" \
			http://deb.debian.org/debian/
		archive_rootfs "${ROOTFS_DIR}/debian-${dist_version}-$(translate_arch "$arch").tar.xz" \
			"debian-${dist_version}-$(translate_arch "$arch")"
	done
	unset arch
}
