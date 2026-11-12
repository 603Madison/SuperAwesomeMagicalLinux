# Notes for Claude

SuperAwesomeMagicalLinux is a bootc image (Fedora 45 via `ghcr.io/ublue-os/base-main`) with
Caelestia's Quickshell shell on Hyprland. The README explains the layout; this is what to know
when changing it.

## Design

Match the owner's apps (SuperAwesomeMagicalWeather, SuperAwesomeMagicalMusic, Cockpit-Manager):
Lexend for all text, Material 3, the shared slate neutrals (`#0B1220` dark / `#F5F7FB` light), soft
rounded corners.

The SuperAwesomeMagical colours are the aurora's, purple and green (the owner's choice for the whole
ecosystem from November 2026 on): primary `#CFBDFF` dark / `#5B3FD1` light (Music's violet),
secondary `#6EF2B0` / `#0B7A4F`, tertiary the original blue `#8DB4FF` / `#2563EB`. That original
blue scheme stays available as "Clear Sky". The values live in `tools/schemes.py`; regenerate the
scheme files from it rather than editing them by hand. The sign-in theme
(`system_files/usr/share/sddm/themes/superawesomemagical/Main.qml` and its `theme.conf`) repeats the
dark tokens.

The desktop is ours, not stock Caelestia: nothing a person sees (text, notifications, logos, app
names) should say Caelestia, and the novelties are gone (no bongo cat, kurukuru or dino). Headings,
names and buttons are Lexend Bold or DemiBold; body text Medium. The SuperAwesomeMagical mark (twin
sparkles: a big four-point one fading from purple into green, a small green one beside it, in a 128
design; the owner's pick) is drawn in `shell/components/Logo.qml` (`AnimatedLogo.qml` animates it),
the hicolor `superawesomemagical.svg` and `build_files/plymouth.py`; change them together, then
redraw fastfetch's copy with `tools/fastfetch-logo.py`. Internal names (the `caelestia` command, `~/.config/caelestia`, QML module names)
stay, since renaming them buys nothing and breaks people's settings.

The default wallpaper is a public-domain NPS photo (credits beside it); keep any new bundled image
public domain or CC0/CC BY and credited in `CREDITS.md`.

## Pins and how to bump them

- The shell is source in `shell/` (our fork); `shell/UPSTREAM.md` says how to take in an upstream
  release. Quickshell, M3Shapes, libcava: top of `build_files/deps.sh` (take Quickshell's and
  M3Shapes' revisions from the upstream shell release's `flake.lock`). The CLI: top of
  `build_files/shell.sh`, which also patches it (Lexend pickers, our name on notifications, no
  dotfiles install/update); like the dotfiles patches, they fail loudly if they stop matching.
- Caelestia dotfiles (Hyprland config): `DOTS_REV` in `build_files/build.sh`, matched to the
  Hyprland version the `lionheartp/Hyprland` COPR ships (its 0.57 takes Lua configs, and the Lua
  API still moves; `check-image` runs Hyprland's own config check, so a mismatch fails CI). `build.sh` patches a few lines of the dotfiles and fails loudly if they
  no longer match; fix the patch list rather than loosening it.
- The family's apps (SuperAwesomeMagical Browser in place of Fedora's Firefox, the Music and
  Email desktop apps): not pinned on purpose. They're the owner's own releases, and the browser's
  carry Firefox's security fixes. CI looks up each one's newest release
  (`build_files/newest-release.sh`, which reads where `releases/latest/download/` redirects: the
  sandbox's proxy blocks the release pages), passes it as `BROWSER_TAG`/`MUSIC_TAG`/`EMAIL_TAG` and
  labels the image with it; `follow-apps.yml` rebuilds when one is behind. `build.sh` checks each
  .rpm against its release's SHA256SUMS where there is one, and Email is left out until it has a
  release. Music and Email are built on Ubuntu 24.04 and link OpenSSL 3, so the image carries
  Fedora's `openssl3-libs` (Fedora 45's own is OpenSSL 4).
- Fonts: revisions and SHA-256s at the top of `build.sh`.
- Fedora version: `FEDORA_VERSION` in the workflow, `Containerfile` and `Justfile`.

## Updates

Installed systems follow `ghcr.io/603madison/superawesomemagicallinux:latest`. The base already
downloads and stages a new image nightly (`rpm-ostreed-automatic.timer`, policy `stage`) and updates
Flatpaks; ours adds `superawesomemagical-update` (update now) and a user timer that notifies when an
update is staged (`update-notify`), plus the About page's button. `check-image` checks they're all
wired up. The boot splash lives in the initramfs, which `build.sh` regenerates with dracut.

## Per-user files

Nothing in the image writes into home folders except `user-setup` and `start-shell` in
`system_files/usr/libexec/superawesomemagical/`, and those only create files that are missing.
System-wide defaults go in `/usr` or `/etc` (dconf, fontconfig, `/etc/xdg`), so they update with
the image; keep it that way.

## Checks before pushing

```sh
just build && just check
```

`check-image` (`system_files/usr/libexec/superawesomemagical/check-image`) is also what CI runs:
programs present, every compiled file's libraries resolve, every QML module the shell imports is
installed, fonts resolve, patches applied, branding. Add a check when adding something the desktop
depends on.

After pushing, follow the whole chain through: "Build image" (build, check, publish), then "Build
installer ISO", which runs by itself after every publish and checks the ISO is a bootable EFI
installer of sensible size. The procedure isn't done until both are green. Changes to
`disk_config/iso.toml` or the ISO workflow can be tried with that workflow's *Run workflow* button
(it uses the last published image). The sandbox hasn't the disk for a local ISO; `just iso` builds
one on a real machine.

The installer's look is `disk_config/installer/branding.py`: the ISO workflow makes a `product.img`
from it (Anaconda's boot scripts lay `images/product.img` over the installer before it starts) and
adds it with lorax's `mkksiso --skip-mkefiboot`, keeping the unbranded ISO if the boot records come
out different. The product name already comes from os-release. The disc label is still
bootc-image-builder's `Fedora-S-dvd-x86_64-45`: `mkksiso -V` would change it, but that rebuilds the
EFI boot image (a loop mount, not possible in the sandbox) and can't be tried without booting it.

The installer must make people create an account (there's no first-run wizard to do it later):
never put `rootpw` (even `--lock`) in `disk_config/iso.toml`, since the installer then treats an
admin as already set up and lets the account screens be skipped. The ISO workflow refuses it.

## Building in a Claude cloud sandbox

- Start Docker yourself: `dockerd > /tmp/dockerd.log 2>&1 &`.
- Network goes through a TLS-intercepting proxy, so make a local base that trusts its CA and pass
  the proxy through:
  ```sh
  printf 'FROM ghcr.io/ublue-os/base-main:45\nCOPY ca.crt /etc/pki/ca-trust/source/anchors/\nRUN update-ca-trust\n' > /tmp/b/Containerfile
  cp /root/.ccr/ca-bundle.crt /tmp/b/ca.crt && docker build -t localhost/base-main-ccr:45 /tmp/b
  docker build --network host --build-arg BASE_IMAGE=localhost/base-main-ccr \
    --build-arg https_proxy=$HTTPS_PROXY -t localhost/superawesomemagicallinux .
  docker run --rm localhost/superawesomemagicallinux /usr/libexec/superawesomemagical/check-image
  ```
- There's no KVM or GPU, so the desktop itself can't be run. What can be verified:
  `check-image`; `bootc container lint`; Hyprland's own config check, as a non-root user after
  `user-setup` (`useradd -m t; su - t -c "/usr/libexec/superawesomemagical/user-setup;
  XDG_RUNTIME_DIR=/tmp Hyprland --verify-config --config /usr/share/superawesomemagical/hypr/hyprland.lua"`);
  the sign-in screen rendered offscreen (`tools/signin-preview.qml`, see `just signin-preview`;
  Fedora's Qt logs to the journal unless `QT_FORCE_STDERR_LOGGING=1`); and the shell itself,
  screenshotted under headless sway with lavapipe and a fake Hyprland IPC:
  ```sh
  docker run --rm --network host -e https_proxy=$HTTPS_PROXY -e SHOTS="dash:drawers toggle dashboard;lock:lock lock" \
    -v $PWD/tools/shell-preview:/preview:ro -v $PWD/shell:/etc/xdg/quickshell/caelestia:ro \
    -v /tmp/shots:/out localhost/superawesomemagicallinux bash /preview/run.sh
  ```
  Mounting `shell/` shows QML edits without a rebuild; C++ (config defaults) needs one.
- The image is ~12 GB unpacked on a ~10 GB base and the sandbox's disk allowance is ~30 GB: delete
  old images and run `docker builder prune -f` between builds, and keep the stage 1 cache.

## QML gotchas met so far

- Property names starting with `on` + a capital are read as signal handlers, so Material's
  `onSurface`-style token names can't be QML properties (the sign-in theme calls them `ink`).
- Hidden or zero-size `ListView`s don't create delegates; use a `Repeater` to read model rows.
