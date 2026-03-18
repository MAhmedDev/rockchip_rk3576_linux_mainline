#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export PATH="${PATH}:/sbin:/usr/sbin"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export DEBIAN_FRONTEND=noninteractive

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
        debian|ubuntu) ;;
        *)
            echo "setup.sh is intended for Debian or Ubuntu hosts."
            exit 1
            ;;
    esac
fi

if [[ "$(id -u)" -eq 0 ]]; then
    SUDO_CMD=()
elif command -v sudo >/dev/null 2>&1; then
    SUDO_CMD=(sudo)
else
    echo "Run this script as root or install sudo first."
    exit 1
fi

mkdir -p archives deploy

required_packages=(
    autoconf
    automake
    autopoint
    binutils
    bison
    bc
    build-essential
    bzip2
    ccache
    cmake
    cpio
    curl
    debootstrap
    device-tree-compiler
    dpkg-dev
    fakeroot
    flex
    gawk
    gcc-aarch64-linux-gnu
    g++-aarch64-linux-gnu
    git
    gettext
    libelf-dev
    libglib2.0-dev
    libgmp-dev
    libltdl-dev
    libmpc-dev
    libmpfr-dev
    libncurses-dev
    libpython3-dev
    libreadline-dev
    libssl-dev
    libtool
    patch
    pkgconf
    python3
    python3-pyelftools
    qemu-user-static
    u-boot-tools
    util-linux
    wget
    zlib1g-dev
)

best_effort_packages=(
    ack
    antlr3
    asciidoc
    fastjar
    gperf
    haveged
    help2man
    intltool
    lrzsz
    nano
    ninja-build
    p7zip
    p7zip-full
    qemu-utils
    rsync
    scons
    squashfs-tools
    subversion
    swig
    texinfo
    uglifyjs
    upx-ucl
    unzip
    xmlto
    xxd
)

flash_tool_packages=(
    dh-autoreconf
    libudev-dev
    libusb-1.0-0-dev
)

available_packages=()
missing_best_effort=()
missing_required=()

collect_packages() {
    local package_kind="$1"
    shift

    local package_name
    for package_name in "$@"; do
        if apt-cache show "$package_name" >/dev/null 2>&1; then
            available_packages+=("$package_name")
        elif [[ "$package_kind" == "required" ]]; then
            missing_required+=("$package_name")
        else
            missing_best_effort+=("$package_name")
        fi
    done
}

"${SUDO_CMD[@]}" apt-get update

collect_packages required "${required_packages[@]}"
collect_packages best-effort "${best_effort_packages[@]}"
collect_packages best-effort "${flash_tool_packages[@]}"

if ((${#missing_required[@]})); then
    echo "Missing required apt packages:"
    printf '  %s\n' "${missing_required[@]}"
    exit 1
fi

if ((${#available_packages[@]})); then
    "${SUDO_CMD[@]}" apt-get install -y "${available_packages[@]}"
fi

if ((${#missing_best_effort[@]})); then
    echo "Skipped optional packages that are not available on this distro:"
    printf '  %s\n' "${missing_best_effort[@]}"
fi

required_commands=(
    aarch64-linux-gnu-g++
    aarch64-linux-gnu-gcc
    debootstrap
    mkimage
    qemu-aarch64-static
    sfdisk
)

missing_commands=()
for command_name in "${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        missing_commands+=("$command_name")
    fi
done

if ((${#missing_commands[@]})); then
    echo "Setup completed, but these required commands are still missing:"
    printf '  %s\n' "${missing_commands[@]}"
    exit 1
fi

echo "Setup complete."
echo "Host dependencies are installed and the workspace is ready for build-base.sh and the image scripts."