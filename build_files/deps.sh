#!/usr/bin/env bash
# Stage 1a of the image build: compile what the desktop shell runs on that Fedora doesn't package
# (Quickshell, M3Shapes, libcava), installing to / for the shell stage to build against and to
# /out for the OS image. Compilers and -devel packages stay out of the image.
#
# Quickshell and M3Shapes are the exact revisions the shell's upstream release was made against
# (shell/UPSTREAM.md). Quickshell uses Qt's private API, so it's compiled here against the Qt the
# image ships rather than taken prebuilt: every image build recompiles it, and a Fedora Qt update
# can't leave it mismatched.
set -xeuo pipefail

QUICKSHELL_REV=2d3b3e9c70ef380dff751b61d334dc88df016c29 # pinned by Caelestia shell v2.5.0's flake.lock
M3SHAPES_REV=32ad9ce328bb77ed349b40a3be10ee9ea610b8ab   # pinned by Caelestia shell v2.5.0's flake.lock
LIBCAVA_REV=f4b69943ea7fecbbeec97fac8e73af03b39be499    # LukashonakV/cava 0.10.7

OUT=/out
# Compiled on disk, not in /tmp: /tmp here is a RAM-backed tmpfs, and on GitHub's runners podman caps
# it well below what these builds (precompiled headers especially) need. Each build folder goes as
# soon as its install is done.
SRC=/var/tmp/sam-src
mkdir -p "$OUT" "$SRC"

# Fetch one commit of a GitHub repo; the commit hash pins the contents.
fetch() {
    local repo=$1 rev=$2 dir=$SRC/$3
    git init -q "$dir"
    git -C "$dir" fetch -q --depth 1 "https://github.com/$repo" "$rev"
    git -C "$dir" checkout -q FETCH_HEAD
    test "$(git -C "$dir" rev-parse HEAD)" = "$rev"
}

# Install to / (so the shell stage can build against it) and to /out (for the image).
install_both() {
    "$@"
    DESTDIR=$OUT "$@"
}

# Everything both stages need to build (the shell stage starts from this one).
dnf -y install --setopt=install_weak_deps=False \
    git-core cmake ninja-build meson gcc-c++ pkgconf-pkg-config desktop-file-utils spirv-tools \
    'cmake(Qt6Core)' 'cmake(Qt6CorePrivate)' 'cmake(Qt6Qml)' 'cmake(Qt6QuickPrivate)' \
    'cmake(Qt6ShaderTools)' 'cmake(Qt6WaylandClient)' 'cmake(Qt6Multimedia)' 'cmake(Qt6QuickControls2)' \
    'pkgconfig(CLI11)' 'pkgconfig(gbm)' 'pkgconfig(glib-2.0)' 'pkgconfig(jemalloc)' 'pkgconfig(libdrm)' \
    'pkgconfig(libpipewire-0.3)' 'pkgconfig(pam)' 'pkgconfig(polkit-agent-1)' \
    'pkgconfig(wayland-client)' 'pkgconfig(wayland-protocols)' \
    libqalculate-devel aubio-devel lm_sensors-devel fftw-devel iniparser-devel \
    python3-devel python3-pip python3-build python3-installer python3-hatchling python3-hatch-vcs python3-pillow

# ---- Quickshell (configured as Fedora's quickshell.spec does, except as a plain Release build:
# without debug info it builds in a fraction of the space and ships a far smaller binary. The crash
# handler is off because it needs cpptrace, which Fedora doesn't package.) ----
fetch quickshell-mirror/quickshell "$QUICKSHELL_REV" quickshell
cmake -S "$SRC/quickshell" -B "$SRC/quickshell/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_SKIP_INSTALL_RPATH=ON \
    -DDISTRIBUTOR="SuperAwesomeMagicalLinux" \
    -DINSTALL_QML_PREFIX=lib64/qt6/qml \
    -DCRASH_HANDLER=OFF \
    -DX11=OFF \
    -DGIT_REVISION="$QUICKSHELL_REV"
cmake --build "$SRC/quickshell/build"
install_both cmake --install "$SRC/quickshell/build"
rm -rf "$SRC/quickshell/build"

# ---- M3Shapes: Material 3 shapes for QML ----
fetch soramanew/m3shapes "$M3SHAPES_REV" m3shapes
cmake -S "$SRC/m3shapes" -B "$SRC/m3shapes/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DINSTALL_QMLDIR=lib64/qt6/qml
cmake --build "$SRC/m3shapes/build"
install_both cmake --install "$SRC/m3shapes/build"
rm -rf "$SRC/m3shapes/build"

# ---- libcava: the audio visualiser's library ----
fetch LukashonakV/cava "$LIBCAVA_REV" cava
meson setup "$SRC/cava/build" "$SRC/cava" --prefix=/usr --libdir=lib64 --buildtype=release
meson compile -C "$SRC/cava/build"
install_both meson install -C "$SRC/cava/build"
rm -rf "$SRC/cava/build"

for p in quickshell m3shapes cava; do
    install -Dm644 "$SRC/$p/LICENSE"* -t "$OUT/usr/share/licenses/superawesomemagical/$p/" 2>/dev/null || true
done

cd /
rm -rf "$SRC"
find "$OUT" -maxdepth 4 | sort
