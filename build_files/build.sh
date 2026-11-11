#!/usr/bin/env bash
# Stage 2 of the image build: turn Universal Blue's base into SuperAwesomeMagicalLinux.
# Stage 1 (caelestia.sh) has already put Quickshell and Caelestia's shell and CLI in place.
set -xeuo pipefail

FILES=/ctx-files
IMAGE_REF=${IMAGE_REF:-ghcr.io/603madison/superawesomemagicallinux}

# Caelestia's dotfiles (its Hyprland config), at the commit matched to the Hyprland 0.57 the COPR
# builds; the shell itself is pinned in caelestia.sh.
DOTS_REV=01d2df329240be60148d25804690779a078c6378
# Fonts Fedora doesn't package, pinned by commit and checksum.
LEXEND_REV=c30b221beb0c1da59d563feb91ec8656a1fa972a # google/fonts
LEXEND_SHA256=3add53e641fbc81da64da4bb254285e2831b52b029527bc0714e2b9610832ee6
SYMBOLS_REV=10ecc14790612ca8fd164e3f4ffe9c16fc50d5b7 # google/material-design-icons
SYMBOLS_SHA256=7e74e36533ccee12c2b81e75bfcf3ccf123d3bb7e7e46d65d94445f23db0c97c

HYPR_COPR=lionheartp/Hyprland
HYPR_REPO="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:lionheartp:Hyprland.repo"

### Repositories ##################################################################################

# Fedora dropped Hyprland in 2025; this COPR keeps it (and its companion tools) built for current
# Fedora. Quickshell is compiled in stage 1 against this image's Qt, so never take the COPR's.
dnf -y copr enable "$HYPR_COPR"
echo "excludepkgs=quickshell*" >> "$HYPR_REPO"

### Packages ######################################################################################

packages=(
    # The desktop: Hyprland and its portal, colour picker, polkit agent and screen recorder
    hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprland-guiutils
    hyprpicker hyprpolkitagent gpu-screen-recorder

    # Sign-in screen
    sddm sddm-wayland-generic

    # What the shell and Quickshell (built in stage 1) run on
    qt6-qtbase qt6-qtdeclarative qt6-qtwayland qt6-qtsvg qt6-qtimageformats qt6-qtmultimedia
    qt6-qt5compat jemalloc libqalculate aubio fftw-libs-double iniparser lm_sensors-libs
    pipewire-libs polkit-libs mesa-libgbm python3-pillow

    # Things the shell and CLI call on
    ddcutil brightnessctl lm_sensors upower tuned-ppd NetworkManager-wifi bluez
    grim slurp swappy wl-clipboard cliphist fuzzel libnotify dconf trash-cli
    gnome-keyring xdg-user-dirs xdg-utils

    # Apps
    foot fish nautilus gvfs gvfs-mtp file-roller gnome-text-editor loupe mpv pavucontrol
    gnome-software fastfetch btop eza zoxide

    # Look
    papirus-icon-theme adw-gtk3-theme adwaita-cursor-theme cascadia-code-nf-fonts
)
dnf -y install --setopt=install_weak_deps=False "${packages[@]}"

### Fonts: Lexend (the brand's typeface) and Material Symbols (the shell's icons) #################

fetch_font() {
    local url=$1 sha=$2 dest=$3
    install -d "$(dirname "$dest")"
    curl -fsSL --retry 5 -o "$dest" "$url"
    echo "$sha  $dest" | sha256sum -c -
}
fetch_font "https://raw.githubusercontent.com/google/fonts/$LEXEND_REV/ofl/lexend/Lexend%5Bwght%5D.ttf" \
    "$LEXEND_SHA256" "/usr/share/fonts/lexend/Lexend[wght].ttf"
curl -fsSL --retry 5 -o /usr/share/licenses/lexend-OFL.txt \
    "https://raw.githubusercontent.com/google/fonts/$LEXEND_REV/ofl/lexend/OFL.txt"
fetch_font "https://raw.githubusercontent.com/google/material-design-icons/$SYMBOLS_REV/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
    "$SYMBOLS_SHA256" "/usr/share/fonts/material-symbols/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
curl -fsSL --retry 5 -o /usr/share/licenses/material-symbols-LICENSE \
    "https://raw.githubusercontent.com/google/material-design-icons/$SYMBOLS_REV/LICENSE"

### Our files #####################################################################################

# Copied as root-owned files whatever the build checkout's owner was.
cp -R --preserve=mode,timestamps --no-preserve=ownership "$FILES"/. /

# Caelestia's Hyprland config, with the few Arch-specific bits made right for Fedora.
git init -q /tmp/dots
git -C /tmp/dots fetch -q --depth 1 https://github.com/caelestia-dots/caelestia "$DOTS_REV"
git -C /tmp/dots checkout -q FETCH_HEAD
test "$(git -C /tmp/dots rev-parse HEAD)" = "$DOTS_REV"
dest=/usr/share/superawesomemagical/hypr/caelestia
install -d "$dest"
cp -R --no-preserve=ownership /tmp/dots/hypr/. "$dest/"
rm -f "$dest/hyprland.lua" # ours, one folder up, is the entry point
install -Dm644 /tmp/dots/LICENSE /usr/share/licenses/superawesomemagical/caelestia-dots/LICENSE

python3 - "$dest" <<'EOF'
import sys
from pathlib import Path

root = Path(sys.argv[1])
# (file, exact text in Caelestia's config, replacement). Each must match, so a dotfiles bump that
# changes these lines fails the build here instead of shipping a half-working desktop.
patches = [
    ("hyprland/execs.lua", 'hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")',
     'hl.exec_cmd("/usr/libexec/hyprpolkitagent")'),
    # No location agent is packaged for Fedora, so no location-based night light yet.
    ("hyprland/execs.lua", '    hl.exec_cmd("/usr/lib/geoclue-2.0/demos/agent")\n', ""),
    ("hyprland/execs.lua", '    hl.exec_cmd("sleep 1 && gammastep")\n', ""),
    # First sign-in setup (colours, wallpaper), then the shell.
    ("hyprland/execs.lua", 'hl.exec_cmd("caelestia shell -d")',
     'hl.exec_cmd("/usr/libexec/superawesomemagical/start-shell")'),
    # qtengine is Arch-only; Qt apps follow the light/dark setting through the portal instead.
    ("hyprland/env.lua", 'hl.env("QT_QPA_PLATFORMTHEME", "qtengine")\n', ""),
]
for name, old, new in patches:
    path = root / name
    text = path.read_text()
    if text.count(old) != 1:
        sys.exit(f"patch for {name} no longer matches Caelestia's dotfiles: {old!r}")
    path.write_text(text.replace(old, new))
EOF

# Our colour schemes, offered next to Caelestia's own in the shell and `caelestia scheme`.
schemes=$(python3 -c 'import caelestia, pathlib; print(pathlib.Path(caelestia.__file__).parent / "data/schemes")')
for scheme in /usr/share/superawesomemagical/schemes/*/; do
    ln -sfn "${scheme%/}" "$schemes/$(basename "$scheme")"
done

# Only our session at the sign-in screen: the plain Hyprland ones have none of the setup.
rm -f /usr/share/wayland-sessions/hyprland*.desktop /usr/share/wayland-sessions/weston*.desktop

### Branding ######################################################################################

python3 - "$IMAGE_REF" <<'EOF'
import re
import sys
from pathlib import Path

path = Path("/usr/lib/os-release")
text = path.read_text()
version = re.search(r'^VERSION_ID=(.*)$', text, re.M).group(1).strip('"')
values = {
    "NAME": "SuperAwesomeMagicalLinux",
    "PRETTY_NAME": f"SuperAwesomeMagicalLinux {version}",
    "VARIANT": "SuperAwesomeMagical",
    "VARIANT_ID": "superawesomemagical",
    "DEFAULT_HOSTNAME": "superawesomemagical",
    "HOME_URL": "https://github.com/603Madison/SuperAwesomeMagicalLinux",
    "DOCUMENTATION_URL": "https://github.com/603Madison/SuperAwesomeMagicalLinux#readme",
    "SUPPORT_URL": "https://github.com/603Madison/SuperAwesomeMagicalLinux/issues",
    "BUG_REPORT_URL": "https://github.com/603Madison/SuperAwesomeMagicalLinux/issues",
    "IMAGE_ID": "superawesomemagicallinux",
    "OSTREE_IMAGE": sys.argv[1],
}
for key, value in values.items():
    line = f'{key}="{value}"'
    text, n = re.subn(rf"^{key}=.*$", line, text, flags=re.M)
    if not n:
        text = text.rstrip("\n") + "\n" + line + "\n"
path.write_text(text)
EOF

### System settings ###############################################################################

systemctl enable sddm.service tuned.service tuned-ppd.service
systemctl set-default graphical.target
# Flathub only (Universal Blue sets it up); Fedora's own Flatpak remote would list most apps twice.
systemctl disable flatpak-add-fedora-repos.service

dconf update
fc-cache -f

### Tidy up #######################################################################################

# Installed systems don't need the COPR switched on; the image already carries what it built.
sed -i 's/^enabled=1/enabled=0/' "$HYPR_REPO"
rm -rf /tmp/dots /var/lib/dnf/repos /var/log/dnf5.log* /var/log/hawkey.log
