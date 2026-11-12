# SuperAwesomeMagicalLinux

The SuperAwesomeMagical ecosystem's operating system: Fedora, image-based, with a desktop in the
same look as the apps: Lexend everywhere, the brand's aurora purple and green over cool slate, soft
rounded cards.

![The sign-in screen: a large bold Lexend clock and a rounded slate card over a photo of purple and green northern lights, with the SuperAwesomeMagical sparkles and name at the bottom](docs/screenshots/sign-in.jpg)

| | |
|---|---|
| ![The dashboard over the aurora wallpaper: weather, a "Hi, Sam!" greeting, the clock, calendar, system meters and the music player](docs/screenshots/dashboard.jpg) | ![The lock screen: a big purple and green clock, weather, a "Good evening" card with the sparkles, the music card and notifications](docs/screenshots/lock.jpg) |
| ![Settings, on the Updates page: "Update ready", the installed version, and buttons to restart, check now or go back](docs/screenshots/settings-updates.jpg) | |

- **Stable.** The whole OS is one tested image. Updates download in the background and apply on
  the next restart, and if one ever misbehaves the previous version is one command away
  (`sudo bootc rollback`). Apps install from Flathub and update separately.
- **Fast.** Hyprland and the desktop shell are light, and Universal Blue's base brings hardware
  video decoding and codecs, so video plays on the GPU instead of the CPU.
- **Good looking.** Our own desktop shell, in Lexend (bold where it counts) and the
  SuperAwesomeMagical colours (aurora purple and green), with the SuperAwesomeMagical mark from the
  boot splash to the lock screen, a matching sign-in screen, and a photo of the northern lights over
  Yellowstone for the wallpaper. The original bright blue (Clear Sky) and Weather's themes (Harbor,
  Evergreen, Maple, Lupine, Aurora, Driftwood) are there to switch to.

## What's in it

| | |
|---|---|
| Base | Fedora 45 via [Universal Blue](https://universal-blue.org)'s `base-main` (codecs, firmware, drivers) |
| Desktop | [Hyprland](https://hypr.land) 0.57 with the SuperAwesomeMagical shell (`shell/`, built on Quickshell) |
| Sign-in | SDDM with our own theme |
| Apps | Firefox, Files (Nautilus), Text Editor, Image Viewer, foot terminal (fish), mpv, Software (Flathub) |
| Fonts | Lexend (interface), Cascadia Code Nerd Font (code), Material Symbols (icons) |

## Installing

**From the ISO.** CI builds a fresh installer ISO after every image it publishes: open the latest
*Build installer ISO* run in the Actions tab, download the ISO from its Artifacts (they're kept for
3 days; *Run workflow* there makes a new one any time), write it to a USB stick (Fedora Media Writer
or `dd`), and boot it. The installer asks which disk to use and has you create your account.

**From another Fedora Atomic system** (Silverblue, Kinoite, Bazzite, Bluefin, ...):

```sh
sudo bootc switch ghcr.io/603madison/superawesomemagicallinux:latest
systemctl reboot
```

Either way, the system then follows `ghcr.io/603madison/superawesomemagicallinux:latest`, which
CI rebuilds twice a week (Mondays and Thursdays) with Fedora's latest updates, and after every
change here. The image package has to be public for installed systems to download updates without
signing in to GitHub (Packages → superawesomemagicallinux → Package settings → Change visibility).

## Updating

Nothing to do: every night the system downloads the newest image in the background and gets it
ready for the next restart, and Flatpak apps update themselves. When an update is ready, a
notification says so with a **Restart now** button. To update straight away instead, use **Check
for updates now** in Settings → About, or from a terminal:

```sh
superawesomemagical-update            # download now; it takes over at the next restart
superawesomemagical-update --reboot   # ...and restart into it
sudo bootc rollback                   # go back to the version before (then restart)
```

Your settings live in your home folder, so updates bring the new desktop without touching them.

## Using it

`Super` opens the launcher. Some others (all of them are in
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
caelestia scheme set -n clearsky        # or superawesomemagical (the default), harbor, evergreen,
                                        #    maple, lupine, aurora, driftwood
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
checks, and publishes from the default branch; each publish then builds and checks an installer ISO
(`.github/workflows/build-iso.yml`). To build locally on Linux with podman and
[just](https://just.systems):

```sh
just build      # the image
just check      # its checks: programs, libraries, QML modules, fonts, branding
just iso        # an installer ISO in ./output
just qcow2      # a VM disk with an account, then `just vm` to boot it
```

How it's put together:

- `Containerfile`: three stages, the first two compiled against the image's own Qt. The first
  builds what the shell runs on, which rarely changes: Quickshell and two small libraries
  (`build_files/deps.sh`). The second builds the desktop shell from `shell/` and its command-line
  helper (`build_files/shell.sh`). The third installs Hyprland and the rest, lays our files over
  the top and makes the boot splash (`build_files/build.sh`, `build_files/plymouth.py`).
- `shell/`: the desktop shell, our fork of [Caelestia's](https://github.com/caelestia-dots/shell)
  (`shell/UPSTREAM.md` says where it came from and how to take in upstream changes).
- `system_files/`: copied onto the image as-is (sign-in theme, wallpapers, colour schemes,
  Hyprland entry config, session and update scripts, font and GTK defaults).
- `tools/`: regenerate the abstract wallpapers (`wallpapers.py`) and the colour schemes
  (`schemes.py`, which holds the brand's colour values); screenshot the shell without a GPU
  (`shell-preview/`, `just shell-preview`).

## Licence

GPL-3.0, like Caelestia's shell and Hyprland config, which ours grew from. Lexend and Material Symbols
are under the SIL Open Font Licence and Apache 2.0 respectively. The default wallpaper is *Aurora
borealis, Upper Geyser Basin* by NPS / Neal Herbert, a public-domain photo from Yellowstone National
Park (see `system_files/usr/share/backgrounds/superawesomemagical/CREDITS.md`).
