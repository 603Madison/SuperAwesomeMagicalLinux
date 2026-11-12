#!/usr/bin/env bash
# Stage 1b of the image build: compile SuperAwesomeMagicalLinux's desktop shell from shell/ in this
# repository (our fork of Caelestia's), and install its command-line companion, into /out-shell for
# the OS image. Runs on top of stage 1a (deps.sh), which has the build tools and libraries.
set -xeuo pipefail

SHELL_VERSION=1.0.0   # our desktop's own version; shell/UPSTREAM.md says which upstream release it grew from
CLI_VERSION=1.1.3
CLI_REV=82265df3665b40184e8bdc2165541e072c5a4971        # caelestia-dots/cli v1.1.3
MATERIALYOUCOLOR_VERSION=3.0.4

OUT=/out-shell
SRC=/var/tmp/sam-src # on disk, not the RAM-backed /tmp (see deps.sh)
mkdir -p "$OUT" "$SRC"

# ---- The shell ----
cp -R /ctx/shell "$SRC/shell"
cd "$SRC/shell"
# Which source this is, for `caelestia --version` and bug reports: a hash of shell/ (the build sees
# no git history, and a commit hash would recompile the shell on every commit).
SOURCE_ID=src-$(find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -c1-12)
# Our wallpaper when none has been chosen yet.
python3 -c "from PIL import Image; Image.open('/ctx/aurora.jpg').save('assets/wallpaper.webp', quality=90)"
cmake -S . -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DVERSION="$SHELL_VERSION" \
    -DGIT_REVISION="$SOURCE_ID" \
    -DDISTRIBUTOR="SuperAwesomeMagicalLinux" \
    -DINSTALL_LIBDIR=/usr/lib/caelestia \
    -DINSTALL_QMLDIR=/usr/lib64/qt6/qml \
    -DINSTALL_QSCONFDIR=/etc/xdg/quickshell/caelestia
cmake --build build
DESTDIR=$OUT cmake --install build
install -Dm644 LICENSE -t "$OUT/usr/share/licenses/superawesomemagical/shell/"

# ---- Its command-line companion (colour schemes, wallpapers, screenshots), and materialyoucolor,
# which Fedora doesn't package ----
git init -q "$SRC/cli"
git -C "$SRC/cli" fetch -q --depth 1 https://github.com/caelestia-dots/cli "$CLI_REV"
git -C "$SRC/cli" checkout -q FETCH_HEAD
test "$(git -C "$SRC/cli" rev-parse HEAD)" = "$CLI_REV"
cd "$SRC/cli"
python3 - <<'EOF'
from pathlib import Path

root = Path("src/caelestia")
stop = ('        raise SystemExit("SuperAwesomeMagicalLinux updates its desktop along with the rest of the '
        'system. To update now, run: superawesomemagical-update")\n')
# (file, exact text, replacement). Each must match, so a CLI bump that changes these lines fails the
# build here rather than shipping half-patched.
patches = [
    # It's our desktop's helper, not a dotfiles installer: its install/update would fetch Arch
    # packages and overwrite the desktop's setup, so they only point at the real updater.
    ("parser.py", 'description="Main control script for the Caelestia dotfiles"',
     'description="Desktop helper for SuperAwesomeMagicalLinux: colour schemes, wallpapers, screenshots"'),
    ("parser.py", 'help="install the Caelestia dotfiles",', "help=argparse.SUPPRESS,"),
    ("parser.py", 'help="update the Caelestia dotfiles")', "help=argparse.SUPPRESS)"),
    ("subcommands/install.py", "    def run(self) -> None:\n", "    def run(self) -> None:\n" + stop),
    ("subcommands/update.py", "    def run(self) -> None:\n", "    def run(self) -> None:\n" + stop),
    # `caelestia --version` describes this system, not an Arch dotfiles install.
    ("utils/version.py", """    meta_package = print_packages()
    print_legacy_install(meta_package)

    print()
    print_dots_version()
""", """    import importlib.metadata
    import platform

    _header("System:")
    print(f"{INDENT}{platform.freedesktop_os_release().get('PRETTY_NAME', 'unknown')}")

    print()
    _header("Desktop tools:")
    print(f"{INDENT}{importlib.metadata.version('caelestia')}")
"""),
    ("utils/version.py", '        _header("Shell:")', '        _header("Desktop:")'),
    # Its notifications (screenshots, recordings, schemes) come from the OS, by name.
    ("utils/notify.py", '"-a", "caelestia-cli"', '"-a", "SuperAwesomeMagical"'),
    # The clipboard and emoji pickers, in Lexend and as round as the rest.
    ("data/templates/fuzzel.ini", "font=JetBrains Mono NF:size=17", "font=Lexend:weight=medium:size=13"),
    ("data/templates/fuzzel.ini", "radius=10", "radius=18"),
]
for name, old, new in patches:
    path = root / name
    text = path.read_text()
    if text.count(old) != 1:
        raise SystemExit(f"patch for {name} no longer matches the CLI: {old!r}")
    path.write_text(text.replace(old, new))
EOF
SETUPTOOLS_SCM_PRETEND_VERSION="$CLI_VERSION" python3 -m build --wheel --no-isolation --outdir dist
python3 -m installer --destdir="$OUT" --prefix=/usr dist/*.whl
python3 -m pip install --no-deps --no-cache-dir --root "$OUT" --prefix /usr \
    "materialyoucolor==${MATERIALYOUCOLOR_VERSION}"
install -Dm644 LICENSE -t "$OUT/usr/share/licenses/superawesomemagical/cli/"

cd /
rm -rf "$SRC"
find "$OUT" -name '__pycache__' -prune -exec rm -rf {} +
find "$OUT" -maxdepth 4 | sort
