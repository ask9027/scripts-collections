#!/usr/bin/env bash
##
## Script for making rootfs creation easier.
##

set -e -u

if [ "$(uname -o)" = "Android" ]; then
	echo "[!] This script cannot be executed on Android OS."
	exit 1
fi

for i in curl git jq debootstrap sudo tar xz multistrap; do
	if [ -z "$(command -v "$i")" ]; then
		echo "[!] '$i' is not installed."
		exit 1
	fi
done

# Where to look for distribution build recipes
BUILD_DIR=$(dirname "$(realpath "$0")")/distro-build

# Where to put generated rootfs tarballs.
ROOTFS_DIR=$(dirname "$(realpath "$0")")/rootfs

# Working directory where chroots will be created.
WORKDIR=/tmp/proot-distro-bootstrap

# Normalize architecture names.
# Prefer aarch64,arm,i686,x86_64 architecture names just like used by
# termux-packages.
translate_arch() {
	case "$1" in
		aarch64|arm64) echo "aarch64";;
		arm|armel|armhf|armhfp|armv7|armv7l|armv7a|armv8l) echo "arm";;
		386|i386|i686|x86) echo "i686";;
		amd64|x86_64) echo "x86_64";;
		*)
			echo "translate_arch(): unknown arch '$1'" >&2
			exit 1
			;;
	esac
}

# Common way to archive the rootfs.
# Usage: archive_rootfs /path/to/rootfs.tar.xz rootfs-dir
# rootfs-dir is relative to $WORKDIR
archive_rootfs() {
	sudo rm -f "${1}.tmp"
	sudo tar \
		--directory="$WORKDIR" \
		--create \
		--sort=name \
		--hard-dereference \
		--numeric-owner \
		--preserve-permissions \
		--acls \
		--xattrs \
		--xattrs-include='*' \
		--xz \
		--file="${1}.tmp" \
		"$2"
	sudo chown $(id -un):$(id -gn) "${1}.tmp"
	mv "${1}.tmp" "${1}"
}

##############################################################################

# Reset workspace. This also deletes any previously made rootfs tarballs.
sudo rm -rf "${WORKDIR:?}"
mkdir -p "$ROOTFS_DIR" "$WORKDIR"
cd "$WORKDIR"

# Build distribution. if no argument is supplied then all distributions will be built
if [ "$#" -gt 0 ]; then
	DISTRIBUTIONS="$*"
else
	DISTRIBUTIONS="$(cd ${BUILD_DIR}; ls -1 *.sh | sed 's/.sh//')"
fi

# Loop over to build a specified distribution
for distro in ${DISTRIBUTIONS}; do
	# Check distribution recipe that is about to built. if it doesn't exist. continue to next distribution
	if [ ! -f "${BUILD_DIR}/${distro}.sh" ]; then
		continue
	fi

	. "${BUILD_DIR}/${distro}.sh"
	printf "\n[*] Building ${dist_name:=$distro}...\n"

	# Bootstrap step
	# If the function does not exists, abort to indicate there's an error occured during build
	if ! declare -F bootstrap_distribution &> /dev/null; then
		echo "[!] Failure to build rootfs ${distro}, missing bootstrap_distribution function. aborting..."
		exit 1
	fi
	bootstrap_distribution

	# Cleanup variables and functions
	unset dist_name	dist_version
	unset -f bootstrap_distribution
done
