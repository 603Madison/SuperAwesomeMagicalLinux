#!/usr/bin/env bash
# Stage 1c of the image build: the window title bars and snapping, a Hyprland plugin. It's
# Hyprland's own hyprbars with changes of ours, built against the exact Hyprland the image ships
# (plugins only load into the Hyprland they were built for), into /out.
#
#   - A bar only on windows that want the compositor to draw one: Wayland apps that ask for
#     server-side decorations (Qt apps, the terminal, Chromium-based apps; GTK apps draw their own
#     title bar and never ask) and X11 apps that don't say they draw their own. Plain hyprbars puts
#     a bar on every window, doubling up on GTK apps.
#   - Hyprland ignores an app's own minimize request (the minimize button in a GTK title bar); it's
#     passed on as Hyprland's minimize event, which the desktop's config (hypr/desktop.lua) handles
#     the same way as the title bars' and the taskbar's.
#   - Snapping, as Windows' Aero Snap: snap.cpp beside this script.
set -xeuo pipefail

: "${HYPRLAND_VERSION:?}"
PLUGINS_REV=d2427d4d15b36df40468f5a58bbd67cdba19835d # hyprwm/hyprland-plugins, as the COPR builds for 0.57.2
HYPR_COPR=lionheartp/Hyprland
OUT=/out
SRC=/var/tmp/titlebars

dnf -y copr enable "$HYPR_COPR"
dnf -y install --setopt=install_weak_deps=False \
    "hyprland-devel-$HYPRLAND_VERSION" "hyprland-$HYPRLAND_VERSION" gcc-c++ make git pkgconf-pkg-config \
    pixman-devel libdrm-devel libinput-devel systemd-devel wayland-devel libxkbcommon-devel lua-devel

git init -q "$SRC"
git -C "$SRC" fetch -q --depth 1 https://github.com/hyprwm/hyprland-plugins "$PLUGINS_REV"
git -C "$SRC" checkout -q FETCH_HEAD
test "$(git -C "$SRC" rev-parse HEAD)" = "$PLUGINS_REV"
cd "$SRC/hyprbars"

python3 - <<'EOF'
from pathlib import Path

path = Path("main.cpp")
text = path.read_text()
# (exact text in hyprbars, replacement). Each must match once, so a plugins bump that changes these
# lines fails the build here instead of shipping bars on every window.
patches = [
    ('#include "globals.hpp"\n', """#include "globals.hpp"

#include <hyprland/src/protocols/XDGShell.hpp>
#include <hyprland/src/protocols/core/Compositor.hpp>
#include <unordered_map>

// SuperAwesomeMagicalLinux: snapping (snap.cpp).
void samSnapInit(HANDLE handle);
void samSnapExit();
"""),
    ("    HyprlandAPI::reloadConfig();\n", "    samSnapInit(PHANDLE);\n    HyprlandAPI::reloadConfig();\n"),
    ("APICALL EXPORT void PLUGIN_EXIT() {\n", "APICALL EXPORT void PLUGIN_EXIT() {\n    samSnapExit();\n"),
    ("static void onNewWindow(PHLWINDOW window) {\n    if (true) {\n", """// SuperAwesomeMagicalLinux: which apps asked for server-side decorations is only kept in the
// protocol's private table, so its header is read here, after every other header (so nothing else
// is affected), with private made public.
#define private public
#include <hyprland/src/protocols/XDGDecoration.hpp>
#undef private

// SuperAwesomeMagicalLinux: a bar only for windows that want the compositor to draw one: Wayland
// apps that asked for server-side decorations, and X11 apps that didn't say they draw their own.
static bool wantsTitleBar(PHLWINDOW window) {
    auto& backend = window->backend();
    if (backend.type() == Desktop::View::eBackendType::WINDOW_BACKEND_X11)
        return !backend.traits().suggestsNoBorder;

    const auto SURFACE = backend.surface();
    if (!SURFACE || !SURFACE->m_role || SURFACE->m_role->role() != SURFACE_ROLE_XDG_SHELL)
        return false;
    const auto XDG      = static_cast<CXDGSurfaceRole*>(SURFACE->m_role.get())->m_xdgSurface.lock();
    const auto TOPLEVEL = XDG ? XDG->m_toplevel.lock() : nullptr;
    if (!TOPLEVEL || !PROTO::xdgDecoration)
        return false;
    return std::ranges::any_of(PROTO::xdgDecoration->m_decorations,
                               [&](const auto& entry) { return CXDGToplevelResource::fromResource(entry.first) == TOPLEVEL; });
}

// SuperAwesomeMagicalLinux: Hyprland ignores an app's own minimize request; pass it on as
// Hyprland's minimize event, as a taskbar's would be.
static std::unordered_map<Desktop::View::CWindow*, Hyprutils::Signal::CHyprSignalListener> g_minimizeListeners;

static void listenForMinimize(PHLWINDOW window) {
    PHLWINDOWREF ref                   = window;
    g_minimizeListeners[window.get()] = window->backend().m_events.stateRequest.listen([ref](const auto& request) {
        const auto WINDOW = ref.lock();
        if (WINDOW && request.minimized.value_or(false))
            Event::bus()->m_events.window.minimize.emit(WINDOW, true);
    });
}

static void onNewWindow(PHLWINDOW window) {
    listenForMinimize(window);
    if (wantsTitleBar(window)) {
"""),
]
for old, new in patches:
    if text.count(old) != 1:
        raise SystemExit(f"patch for hyprbars no longer matches: {old!r}")
    text = text.replace(old, new)
path.write_text(text)
EOF

cp /ctx/titlebars/snap.cpp .
make all SRC="main.cpp barDeco.cpp BarPassElement.cpp snap.cpp"
install -Dm755 hyprbars.so "$OUT/usr/lib64/hyprland/libsuperawesomemagical-titlebars.so"
install -Dm644 ../LICENSE "$OUT/usr/share/licenses/superawesomemagical/titlebars/LICENSE"
echo "$HYPRLAND_VERSION" > "$OUT/usr/lib64/hyprland/libsuperawesomemagical-titlebars.hyprland-version"
cd /
rm -rf "$SRC"
