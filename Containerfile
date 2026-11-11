# SuperAwesomeMagicalLinux: Fedora, image-based, with the SuperAwesomeMagical desktop
# (Caelestia's shell on Hyprland, in the ecosystem's look).
#
# Built on Universal Blue's base-main, which is Fedora's atomic base with media codecs, hardware
# video decoding and firmware already sorted. Installed systems update from this image as a whole
# and can roll back to the previous one, which is most of what makes them stable.

ARG BASE_IMAGE=ghcr.io/ublue-os/base-main
ARG FEDORA_VERSION=45

# ---- Build context: the scripts, kept out of the final image ----
FROM scratch AS ctx
COPY build_files /

# ---- Stage 1: compile Caelestia's shell and CLI against the same Fedora the image ships ----
# (Only the files it uses are mounted, so changing anything else doesn't force a recompile.)
FROM ${BASE_IMAGE}:${FEDORA_VERSION} AS caelestia
RUN --mount=type=bind,from=ctx,source=/caelestia.sh,target=/ctx/caelestia.sh \
    --mount=type=bind,source=system_files/usr/share/backgrounds/superawesomemagical/aurora.jpg,target=/ctx/aurora.jpg \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/caelestia.sh

# ---- Stage 2: the OS image ----
FROM ${BASE_IMAGE}:${FEDORA_VERSION}
ARG FEDORA_VERSION
ARG IMAGE_REF=ghcr.io/603madison/superawesomemagicallinux

COPY --from=caelestia /out /
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,source=system_files,target=/ctx-files \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=tmpfs,dst=/tmp \
    FEDORA_VERSION="${FEDORA_VERSION}" IMAGE_REF="${IMAGE_REF}" /ctx/build.sh

RUN bootc container lint
