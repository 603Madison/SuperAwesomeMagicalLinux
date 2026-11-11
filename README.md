# SuperAwesomeMagicalLinux

The SuperAwesomeMagical ecosystem's operating system: Fedora, image-based, with a desktop in the
same look as the apps (Lexend everywhere, the slate-and-blue brand colours, soft rounded cards).

![The sign-in screen: a large Lexend clock and a rounded slate card over the aurora wallpaper](docs/screenshots/sign-in.jpg)

- **Stable.** The whole OS is one tested image. Updates download in the background and apply on
  the next restart, and if one ever misbehaves the previous version is one command away
  (`sudo bootc rollback`). Apps install from Flathub and update separately.
- **Fast.** Hyprland and Caelestia's shell are light, and Universal Blue's base brings hardware
  video decoding and codecs, so video plays on the GPU instead of the CPU.
- **Good looking.** [Caelestia](https://github.com/caelestia-dots/shell)'s shell, in Lexend and
  the SuperAwesomeMagical colours, plus Weather's themes (Harbor, Evergreen, Maple, Lupine, Aurora,
  Driftwood) as colour schemes, a matching sign-in screen and an aurora-over-the-pines wallpaper.

## What's in it

| | |
|---|---|
| Base | Fedora 45 via [Universal Blue](https://universal-blue.org)'s `base-main` (codecs, firmware, drivers) |
| Desktop | [Hyprland](https://hypr.land) 0.57 with Caelestia's shell 2.5.0 and its Hyprland config |
| Sign-in | SDDM with our own theme |
| Apps | Firefox, Files (Nautilus), Text Editor, Image Viewer, foot terminal (fish), mpv, Software (Flathub) |
| Fonts | Lexend (interface), Cascadia Code Nerd Font (code), Material Symbols (icons) |

## Installing

**From the ISO.** Run *Build installer ISO* from the Actions tab, download the ISO from the run,
write it to a USB stick (Fedora Media Writer or `dd`), and boot it. The installer asks which disk
to use and has you create your account.

**From another Fedora Atomic system** (Silverblue, Kinoite, Bazzite, Bluefin, ...):

```sh
sudo bootc switch ghcr.io/603madison/superawesomemagicallinux:latest
systemctl reboot
```

Either way, the system then follows `ghcr.io/603madison/superawesomemagicallinux:latest`, which
CI rebuilds twice a week (Mondays and Thursdays) with Fedora's latest updates. The image package has
to be public for installed systems to download updates without signing in to GitHub (Packages →
superawesomemagicallinux → Package settings).

## Using it

`Super` opens the launcher. Some others (all of Caelestia's keys are in
`/usr/share/superawesomemagical/hypr/caelestia/variables.lua`):

| Keys | |
|---|---|
| `Super` | Launcher |
| `Super + T` / `W` / `E` | Terminal / Firefox / Files |
| `Super + Q` | Close window |
| `Super + 1`–`0` | Switch workspace |
| `Super + Alt + Space` | Float or tile the window |
| `Super + F` | Fullscreen |
| `Super + N` | Sidebar (notifications, quick settings) |
| `Super + L` | Lock |
| `Super + Shift + S` | Screenshot a region |
| `Super + V` | Clipboard history |
| `Ctrl + Alt + Delete` | Session menu (log out, restart, shut down) |

**Changing things.** Colours and wallpaper are in the shell's dashboard, or from a terminal:

```sh
caelestia scheme set -n harbor          # or superawesomemagical, evergreen, maple, lupine, aurora, driftwood
caelestia scheme set -n dynamic         # colours from the wallpaper, Material You style
caelestia scheme set -m light           # light mode
```

Your own Hyprland changes go in `~/.config/caelestia/hypr-vars.lua` (settings) and
`~/.config/caelestia/hypr-user.lua` (anything else); the shell's settings are in
`~/.config/caelestia/shell.json`. Updates never touch these.

**Installing software.** Apps: the Software app (Flathub). Command-line and development tools: a
`distrobox` container (`distrobox create`, then `distrobox enter`, and `dnf install` inside it).
System packages can be layered with `rpm-ostree install`, but every layered package is something
updates have to work around, so prefer the other two.

## Building

CI (`.github/workflows/build.yml`) builds on every push and twice a week, runs the image's own
checks, and publishes from the default branch. To build locally on Linux with podman and
[just](https://just.systems):

```sh
just build      # the image
just check      # its checks: programs, libraries, QML modules, fonts, branding
just iso        # an installer ISO in ./output
just qcow2      # a VM disk with an account, then `just vm` to boot it
```

How it's put together:

- `Containerfile`: two stages. The first compiles Quickshell, Caelestia's shell and CLI and two
  small libraries against the image's own Qt (`build_files/caelestia.sh`); the second installs
  Hyprland and the rest and lays our files over the top (`build_files/build.sh`).
- `system_files/`: copied onto the image as-is (sign-in theme, wallpapers, colour schemes,
  Hyprland entry config, session scripts, font and GTK defaults).
- `tools/`: regenerate the wallpapers (`wallpapers.py`) and colour schemes (`schemes.py`).

## Licence

GPL-3.0, like Caelestia, whose shell and Hyprland config this builds on. Lexend and Material Symbols
are under the SIL Open Font Licence and Apache 2.0 respectively.
