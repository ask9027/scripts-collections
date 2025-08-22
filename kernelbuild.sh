#!/bin/bash
# ==========================================
#  Android Kernel Build Script
#  Author : ask9027
#  Usage  : <kerneldir>/build.sh <codename> [--clean]
#
#  Example:
#    <kerneldir>/build.sh courbet
#    <kerneldir>/build.sh sweet --clean
#
#  Notes:
#    - If no codename is specified, default is: courbet
#    - You can override default with:
#        DEFAULT_DEVICE=<codename> <kerneldir>/build.sh
#
#  Features:
#   - Supports multiple Xiaomi devices (sweet, courbet, tucana, toco, phoenix, davinci)
#   - Automatic ccache support (10G limit)
#   - Per-stage timers (defconfig, build, packaging, total)
#   - Embeds build user/host in kernel string
#   - Auto packaging with AnyKernel3
#   - Colored logs for easy reading
#   - Big SUCCESS/FAILURE banners at the end
# ==========================================

set -euo pipefail
SECONDS=0

# ===== CONFIG =====
ALLOWED_CODENAMES=(sweet courbet tucana toco phoenix davinci)
DATE_TAG="$(date '+%Y%m%d-%H%M')"

ARCH="arm64"
KBUILD_BUILD_USER="ask9027"
KBUILD_BUILD_HOST="Mi11Lite4G"

# ===== UTILS =====
log() { echo -e "\033[1;32m[✔] $*\033[0m"; }
err() { echo -e "\033[1;31m[✘] $*\033[0m" >&2; exit 1; }

# ===== FAILURE HANDLER =====
on_fail() {
    local exit_code=$?
    local total_time=${SECONDS}
    echo -e "\n\033[1;31m==========================================\033[0m"
    echo -e "\033[1;31m   [✘ BUILD FAILED] for device: ${DEVICE-unknown}\033[0m"
    echo -e "\033[1;31m   Elapsed: $((total_time / 60))m $((total_time % 60))s\033[0m"
    echo -e "\033[1;31m   Exit code: ${exit_code}\033[0m"
    echo -e "\033[1;31m==========================================\033[0m\n"
}
trap on_fail ERR

# ===== OPTIONS =====
case "${1-}" in
    --help|-h)
        cat <<EOF
==========================================
 Android Kernel Build Script
 Author : ask9027

 Usage  : <kerneldir>/build.sh <codename> [--clean]

 Example:
   <kerneldir>/build.sh courbet
   <kerneldir>/build.sh sweet --clean

 Notes:
   - If no codename is specified, default is: courbet
   - You can override default with:
       DEFAULT_DEVICE=<codename> <kerneldir>/build.sh

 Features:
  - Supports multiple Xiaomi devices (sweet, courbet, tucana, toco, phoenix, davinci)
  - Automatic ccache support (10G limit)
  - Per-stage timers (defconfig, build, packaging, total)
  - Embeds build user/host in kernel string
  - Auto packaging with AnyKernel3
  - Colored logs for easy reading
  - Big SUCCESS/FAILURE banners at the end
==========================================
EOF
        exit 0
        ;;
    --list)
        echo "Supported devices:"
        for d in "${ALLOWED_CODENAMES[@]}"; do
            echo "  ${d}"
        done
        echo "Default device: ${DEFAULT_DEVICE:-courbet}"
        exit 0
        ;;
esac

# ===== DEVICE ARGUMENT =====
DEFAULT_DEVICE="${DEFAULT_DEVICE:-courbet}"  # environment overrides, fallback = courbet
DEVICE="${1-}"

if [[ -z "${DEVICE}" || "${DEVICE}" =~ ^(-c|--clean)$ ]]; then
    log "No codename specified, using default: ${DEFAULT_DEVICE}"
    DEVICE="${DEFAULT_DEVICE}"
    # shift args if only --clean was passed without codename
    if [[ "${1-}" =~ ^(-c|--clean)$ ]]; then
        set -- "${DEFAULT_DEVICE}" "$@"
    fi
fi

if [[ " ${ALLOWED_CODENAMES[*]} " != *" ${DEVICE} "* ]]; then
    err "Invalid codename: ${DEVICE}.
Allowed: ${ALLOWED_CODENAMES[*]}
Usage: <kerneldir>/build.sh <codename> [--clean]"
fi

# ===== CLEAN =====
if [[ ${2-} =~ ^(-c|--clean)$ ]]; then
    log "Cleaning output..."
    rm -rf out
fi

# ===== CCACHE =====
if command -v ccache &>/dev/null; then
    log "Enabling ccache (10G limit)"
    export USE_CCACHE=1
    ccache --max-size=10G >/dev/null
fi

# ===== BUILD FLAGS =====
BUILD_FLAGS=(
    O=out
	EXTRAVERSION=""
    ARCH=${ARCH}
    SUBARCH=${ARCH}
    HEADER_ARCH=${ARCH}
    KBUILD_BUILD_USER=${KBUILD_BUILD_USER}
    KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST}
    CC="ccache clang"
    CXX="ccache clang++"
    LLVM=1 LLVM_IAS=1
    LLVM_AR=llvm-ar
    LLVM_NM=llvm-nm
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
    READELF=llvm-readelf
    HOSTAR=llvm-ar
    HOSTCXX="ccache clang++"
    DTC_EXT=dtc
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    CLANG_TRIPLE=aarch64-linux-gnu-
    CONFIG_NO_ERROR_ON_MISMATCH=y
    CONFIG_DEBUG_SECTION_MISMATCH=y
    KCFLAGS="-O2 -pipe"
    HOSTCFLAGS="-O2 -pipe"
    HOSTCXXFLAGS="-O2 -pipe"
    DEPMOD=true
)

# ===== DEFCONFIG =====
DEFCONFIG_TIME=${SECONDS}
log "Running defconfig for ${DEVICE}..."
make "${BUILD_FLAGS[@]}" "${DEVICE}_defconfig"
DEFCONFIG_TIME=$((SECONDS - DEFCONFIG_TIME))
log "Defconfig completed in $((DEFCONFIG_TIME / 60))m $((DEFCONFIG_TIME % 60))s"

# ===== BUILD =====
BUILD_TIME=${SECONDS}
log "Building kernel for ${DEVICE}..."
make -j"$(nproc --all)" "${BUILD_FLAGS[@]}"
BUILD_TIME=$((SECONDS - BUILD_TIME))
log "Build completed in $((BUILD_TIME / 60))m $((BUILD_TIME % 60))s"

# ===== KERNEL STRING =====
log "Getting Kernel Release String..."
KERNEL_STRING="$(grep UTS_RELEASE out/include/generated/utsrelease.h | cut -d'"' -f2 || true)"
[[ -z "${KERNEL_STRING}" ]] && err "Failed to extract kernel version"
log "Kernel: ${KERNEL_STRING}"

# ===== VERIFY OUTPUT =====
for f in Image.gz dtbo.img dtb.img; do
    [[ ! -f "out/arch/arm64/boot/${f}" ]] && err "Missing ${f} — build failed"
done

# ===== PACKAGE =====
PACKAGE_TIME=${SECONDS}
log "Packaging kernel..."
[[ ! -d AnyKernel3 ]] && git clone -q --depth=1 https://github.com/ask9027/AnyKernel3

cp out/arch/arm64/boot/{Image.gz,dtbo.img,dtb.img} AnyKernel3/

sed -i \
    -e "s|^kernel.string=.*|kernel.string=${KERNEL_STRING} by ${KBUILD_BUILD_USER} @ ${KBUILD_BUILD_HOST}|" \
    -e "s|^device.name1=.*|device.name1=${DEVICE}|" \
    -e "s|^device.name2=.*|device.name2=${DEVICE}in|" \
    -e "s|^device.name[3-5]=.*|device.name=|" \
    -e "s|^supported.versions=.*|supported.versions=11-16|" \
    -e "s|^BLOCK=.*|BLOCK=/dev/block/bootdevice/by-name/boot;|" \
    AnyKernel3/anykernel.sh

ZIPNAME="${DEVICE}-${KERNEL_STRING}-${DATE_TAG}.zip"
(
    cd AnyKernel3
    zip -r9 "../${ZIPNAME}" * -x .git\*
)
PACKAGE_TIME=$((SECONDS - PACKAGE_TIME))
log "Packaging completed in $((PACKAGE_TIME / 60))m $((PACKAGE_TIME % 60))s"

# ===== CLEAN PACKAGE DIR =====
log "Cleaning AnyKernel3 leftovers..."
rm -f AnyKernel3/{Image.gz,dtbo.img,dtb.img}

# ===== DONE =====
TOTAL_TIME=${SECONDS}
trap - ERR  # disable failure trap after success
echo -e "\n\033[1;32m==========================================\033[0m"
echo -e "\033[1;32m   [✓ BUILD SUCCESS] ${DEVICE} kernel built\033[0m"
echo -e "\033[1;32m   Kernel: ${KERNEL_STRING}\033[0m"
echo -e "\033[1;32m   Output: ${ZIPNAME}\033[0m"
echo -e "\033[1;32m   Time:   $((TOTAL_TIME / 60))m $((TOTAL_TIME % 60))s\033[0m"
echo -e "\033[1;32m==========================================\033[0m\n"
