#!/usr/bin/env bash
# Stage 1 of the image build: compile the desktop shell and everything it needs that Fedora doesn't
# package, installing into /out for the OS image to copy. Compilers and -devel packages stay here.
#
# The pins are Caelestia's latest release and the exact Quickshell and M3Shapes revisions that
# release was made against (its flake.lock), so this is the combination upstream tested. Quickshell
# uses Qt's private API, so it's compiled here against the Qt the image ships rather than taken
# prebuilt: every image build recompiles it, and a Fedora Qt update can't leave it mismatched.
#
# To update: bump SHELL_*/CLI_* to a new release, then copy the quickshell and m3shapes revisions
# from that release's flake.lock, and DOTS_REV (build.sh) to the dotfiles commit of the same day.
set -xeuo pipefail

SHELL_VERSION=2.5.0
SHELL_REV=d999d4878ee4cec134168e60d913714566a8cfa6      # caelestia-dots/shell v2.5.0
CLI_VERSION=1.1.3
CLI_REV=82265df3665b40184e8bdc2165541e072c5a4971        # caelestia-dots/cli v1.1.3
QUICKSHELL_REV=2d3b3e9c70ef380dff751b61d334dc88df016c29 # pinned by shell v2.5.0
M3SHAPES_REV=32ad9ce328bb77ed349b40a3be10ee9ea610b8ab   # pinned by shell v2.5.0
LIBCAVA_REV=f4b69943ea7fecbbeec97fac8e73af03b39be499    # LukashonakV/cava 0.10.7
MATERIALYOUCOLOR_VERSION=3.0.4

OUT=/out
SRC=/tmp/src
mkdir -p "$OUT" "$SRC"

# Fetch one commit of a GitHub repo; the commit hash pins the contents.
fetch() {
    local repo=$1 rev=$2 dir=$SRC/$3
    git init -q "$dir"
    git -C "$dir" fetch -q --depth 1 "https://github.com/$repo" "$rev"
    git -C "$dir" checkout -q FETCH_HEAD
    test "$(git -C "$dir" rev-parse HEAD)" = "$rev"
}

# Install to / (so later builds here can find it) and to /out (for the image).
install_both() {
    "$@"
    DESTDIR=$OUT "$@"
}

dnf -y install --setopt=install_weak_deps=False \
    git-core cmake ninja-build meson gcc-c++ pkgconf-pkg-config desktop-file-utils spirv-tools \
    'cmake(Qt6Core)' 'cmake(Qt6CorePrivate)' 'cmake(Qt6Qml)' 'cmake(Qt6QuickPrivate)' \
    'cmake(Qt6ShaderTools)' 'cmake(Qt6WaylandClient)' 'cmake(Qt6Multimedia)' 'cmake(Qt6QuickControls2)' \
    'pkgconfig(CLI11)' 'pkgconfig(gbm)' 'pkgconfig(glib-2.0)' 'pkgconfig(jemalloc)' 'pkgconfig(libdrm)' \
    'pkgconfig(libpipewire-0.3)' 'pkgconfig(pam)' 'pkgconfig(polkit-agent-1)' \
    'pkgconfig(wayland-client)' 'pkgconfig(wayland-protocols)' \
    libqalculate-devel aubio-devel lm_sensors-devel fftw-devel iniparser-devel \
    python3-devel python3-pip python3-build python3-installer python3-hatchling python3-hatch-vcs python3-pillow

# ---- Quickshell (configured as Fedora's quickshell.spec does; the crash handler is off because it
# needs cpptrace, which Fedora doesn't package) ----
fetch quickshell-mirror/quickshell "$QUICKSHELL_REV" quickshell
cmake -S "$SRC/quickshell" -B "$SRC/quickshell/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_SKIP_INSTALL_RPATH=ON \
    -DDISTRIBUTOR="SuperAwesomeMagicalLinux" \
    -DINSTALL_QML_PREFIX=lib64/qt6/qml \
    -DCRASH_HANDLER=OFF \
    -DX11=OFF \
    -DGIT_REVISION="$QUICKSHELL_REV"
cmake --build "$SRC/quickshell/build"
install_both cmake --install "$SRC/quickshell/build"

# ---- M3Shapes: Material 3 shapes for QML ----
fetch soramanew/m3shapes "$M3SHAPES_REV" m3shapes
cmake -S "$SRC/m3shapes" -B "$SRC/m3shapes/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DINSTALL_QMLDIR=lib64/qt6/qml
cmake --build "$SRC/m3shapes/build"
install_both cmake --install "$SRC/m3shapes/build"

# ---- libcava: the audio visualiser's library ----
fetch LukashonakV/cava "$LIBCAVA_REV" cava
meson setup "$SRC/cava/build" "$SRC/cava" --prefix=/usr --libdir=lib64 --buildtype=release
meson compile -C "$SRC/cava/build"
install_both meson install -C "$SRC/cava/build"

# ---- Caelestia shell ----
fetch caelestia-dots/shell "$SHELL_REV" shell
cd "$SRC/shell"
# Lexend everywhere, like every SuperAwesomeMagical app; Fedora's Cascadia Code Nerd Font for code.
sed -i \
    -e 's/u"GoogleSansFlex"_s/u"Lexend"_s/g' \
    -e 's/u"Rubik"_s/u"Lexend"_s/g' \
    -e 's/u"CaskaydiaCove NF"_s/u"Cascadia Code NF"_s/g' \
    plugin/src/Caelestia/Config/appearanceconfig.hpp
test "$(grep -c 'u"Lexend"_s' plugin/src/Caelestia/Config/appearanceconfig.hpp)" -eq 6
! grep -q 'GoogleSansFlex"_s\|Rubik"_s\|CaskaydiaCove' plugin/src/Caelestia/Config/appearanceconfig.hpp
# Our wallpaper when none has been chosen yet.
python3 -c "from PIL import Image; Image.open('/ctx/aurora.jpg').save('assets/wallpaper.webp', quality=90)"
cmake -S . -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DVERSION="$SHELL_VERSION" \
    -DGIT_REVISION="$SHELL_REV" \
    -DDISTRIBUTOR="SuperAwesomeMagicalLinux" \
    -DINSTALL_LIBDIR=/usr/lib/caelestia \
    -DINSTALL_QMLDIR=/usr/lib64/qt6/qml \
    -DINSTALL_QSCONFDIR=/etc/xdg/quickshell/caelestia
cmake --build build
DESTDIR=$OUT cmake --install build

# ---- Caelestia CLI (and materialyoucolor, which Fedora doesn't package) ----
fetch caelestia-dots/cli "$CLI_REV" cli
cd "$SRC/cli"
SETUPTOOLS_SCM_PRETEND_VERSION="$CLI_VERSION" python3 -m build --wheel --no-isolation --outdir dist
python3 -m installer --destdir="$OUT" --prefix=/usr dist/*.whl
python3 -m pip install --no-deps --no-cache-dir --root "$OUT" --prefix /usr \
    "materialyoucolor==${MATERIALYOUCOLOR_VERSION}"

# Licences of what we built, next to the binaries.
for p in quickshell m3shapes cava shell cli; do
    install -Dm644 "$SRC/$p/LICENSE"* -t "$OUT/usr/share/licenses/superawesomemagical/$p/" 2>/dev/null || true
done

find "$OUT" -name '__pycache__' -prune -exec rm -rf {} +
find "$OUT" -maxdepth 4 | sort
