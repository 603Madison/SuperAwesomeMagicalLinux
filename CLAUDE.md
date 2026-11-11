# Notes for Claude

SuperAwesomeMagicalLinux is a bootc image (Fedora 45 via `ghcr.io/ublue-os/base-main`) with
Caelestia's Quickshell shell on Hyprland. The README explains the layout; this is what to know
when changing it.

## Design

Match the owner's apps (SuperAwesomeMagicalWeather, SuperAwesomeMagicalMusic, Cockpit-Manager):
Lexend for all text, Material 3, the shared slate neutrals (`#0B1220` dark / `#F5F7FB` light) with
Weather's blue as the default accent, soft rounded corners. The colour values live in
`tools/schemes.py` (copied from Weather's `BrandColors.kt` and `Themes.kt`); regenerate the scheme
files from it rather than editing them by hand. The sign-in theme
(`system_files/usr/share/sddm/themes/superawesomemagical/Main.qml`) repeats the dark tokens.

## Pins and how to bump them

- Caelestia shell + CLI, Quickshell, M3Shapes, libcava: top of `build_files/caelestia.sh`. Take
  Quickshell's and M3Shapes' revisions from the new shell release's `flake.lock`.
- Caelestia dotfiles (Hyprland config): `DOTS_REV` in `build_files/build.sh`, matched to the
  Hyprland version the `lionheartp/Hyprland` COPR ships (Hyprland's config is Lua since 0.55-ish
  and its API still moves). `build.sh` patches a few lines of the dotfiles and fails loudly if they
  no longer match; fix the patch list rather than loosening it.
- Fonts: revisions and SHA-256s at the top of `build.sh`.
- Fedora version: `FEDORA_VERSION` in the workflow, `Containerfile` and `Justfile`.

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
- There's no KVM or GPU, so the desktop itself can't be run; `check-image` and offscreen QML
  renders are what can be verified.
