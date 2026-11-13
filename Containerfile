# SuperAwesomeMagicalLinux: Fedora, image-based, with the SuperAwesomeMagical desktop
# (our own shell, grown from Caelestia's, on Hyprland).
#
# Built on Universal Blue's base-main, which is Fedora's atomic base with media codecs, hardware
# video decoding and firmware already sorted. Installed systems update from this image as a whole
# and can roll back to the previous one, which is most of what makes them stable.

ARG BASE_IMAGE=ghcr.io/ublue-os/base-main
ARG FEDORA_VERSION=45
# Hyprland, from the lionheartp/Hyprland COPR. Pinned, because the title bars plugin (stage 1c) is
# built for exactly this version, and Caelestia's Hyprland config (DOTS_REV in build.sh) matches it.
ARG HYPRLAND_VERSION=0.57.2

# ---- Build context: the scripts, kept out of the final image ----
FROM scratch AS ctx
COPY build_files /

# Stages 1a and 1b compile against the same Fedora the image ships. Each mounts only the files it
# uses, so changing anything else doesn't force a recompile.

# ---- Stage 1a: what the shell runs on (Quickshell, M3Shapes, libcava); rarely changes ----
FROM ${BASE_IMAGE}:${FEDORA_VERSION} AS deps
RUN --mount=type=bind,from=ctx,source=/deps.sh,target=/ctx/deps.sh \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/deps.sh

# ---- Stage 1b: the desktop shell, from shell/ in this repository ----
FROM deps AS shell
RUN --mount=type=bind,from=ctx,source=/shell.sh,target=/ctx/shell.sh \
    --mount=type=bind,source=shell,target=/ctx/shell \
    --mount=type=bind,source=system_files/usr/share/backgrounds/superawesomemagical/aurora.jpg,target=/ctx/aurora.jpg \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/shell.sh

# ---- Stage 1c: the window title bars, a Hyprland plugin built for exactly HYPRLAND_VERSION ----
FROM ${BASE_IMAGE}:${FEDORA_VERSION} AS titlebars
ARG HYPRLAND_VERSION
# (Its own dnf cache: this stage builds alongside stage 1a, and two dnf runs can't share one.)
RUN --mount=type=bind,from=ctx,source=/titlebars.sh,target=/ctx/titlebars.sh \
    --mount=type=cache,id=dnf-titlebars,dst=/var/cache/libdnf5 \
    --mount=type=tmpfs,dst=/tmp \
    HYPRLAND_VERSION="${HYPRLAND_VERSION}" /ctx/titlebars.sh

# ---- Stage 2: the OS image ----
FROM ${BASE_IMAGE}:${FEDORA_VERSION}
ARG FEDORA_VERSION
ARG HYPRLAND_VERSION
ARG IMAGE_REF=ghcr.io/603madison/superawesomemagicallinux
# Which releases of the family's apps to install (SuperAwesomeMagical Browser, Music, Email); empty
# for the newest.
ARG BROWSER_TAG=
ARG MUSIC_TAG=
ARG EMAIL_TAG=

COPY --from=deps /out /
COPY --from=shell /out-shell /
COPY --from=titlebars /out /
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,source=system_files,target=/ctx-files \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=tmpfs,dst=/tmp \
    FEDORA_VERSION="${FEDORA_VERSION}" HYPRLAND_VERSION="${HYPRLAND_VERSION}" IMAGE_REF="${IMAGE_REF}" BROWSER_TAG="${BROWSER_TAG}" MUSIC_TAG="${MUSIC_TAG}" EMAIL_TAG="${EMAIL_TAG}" \
    /ctx/build.sh

# podman leaves the dnf cache mount's (empty) folder behind; nothing in /var should ship.
RUN rm -rf /var/cache/libdnf5 && bootc container lint
