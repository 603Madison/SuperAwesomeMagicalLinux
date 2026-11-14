// SuperAwesomeMagicalLinux: snapping, as Windows' Aero Snap has it, for floating windows.
//
//   - Drag a window's title bar to the left or right edge of the screen: it fills that half. To the
//     top: the whole screen (beside the shell's bar). Into a corner: that quarter. While dragging,
//     the shell draws where it will land (Hyprland IPC event "samsnap>>x,y,w,h", empty to hide).
//   - Drag a snapped window away and it goes back to the size it had before.
//   - From Lua (the keyboard, in hypr/desktop.lua): hl.plugin.hyprbars.snap("left" | "right" | "top"
//     | "top_left" | "top_right" | "bottom_left" | "bottom_right") snaps the active window, and
//     hl.plugin.hyprbars.unsnap() puts it back, returning whether it was snapped.
//
// Built into our build of hyprbars (build.sh), so both share the one plugin.

#define WLR_USE_UNSTABLE

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/ipc/s2/S2.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/supplementary/DragController.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/state/MonitorState.hpp>

#include <format>
#include <optional>
#include <string>
#include <unordered_map>

extern "C" {
#include <lauxlib.h>
#include <lua.h>
}

namespace {
    enum class eZone : uint8_t {
        NONE,
        LEFT,
        RIGHT,
        TOP,
        TOP_LEFT,
        TOP_RIGHT,
        BOTTOM_LEFT,
        BOTTOM_RIGHT,
    };

    // How close to an edge (px) the pointer must be to snap, how far from a corner along the edge
    // counts as the corner, and the gap left around snapped windows (the desktop's rounded look).
    constexpr double EDGE      = 6;
    constexpr double CORNER    = 140;
    constexpr double GAP       = 10;
    constexpr double UNSNAP_AT = 12; // px of dragging before a snapped window gets its size back

    struct SSnap {
        // Windows we snapped, and the box (position and size) each had before.
        std::unordered_map<Desktop::View::CWindow*, CBox> before;

        // The drag in progress, if it's moving a window.
        PHLWINDOWREF dragging;
        Vector2D     dragStart;
        bool         restoredThisDrag = false;
        eZone        zone             = eZone::NONE;
        PHLMONITORREF zoneMonitor;

        CHyprSignalListener motion, ended;
    };

    SSnap g_snap;

    std::optional<eZone> zoneFromName(const std::string& name) {
        if (name == "left")
            return eZone::LEFT;
        if (name == "right")
            return eZone::RIGHT;
        if (name == "top")
            return eZone::TOP;
        if (name == "top_left")
            return eZone::TOP_LEFT;
        if (name == "top_right")
            return eZone::TOP_RIGHT;
        if (name == "bottom_left")
            return eZone::BOTTOM_LEFT;
        if (name == "bottom_right")
            return eZone::BOTTOM_RIGHT;
        return std::nullopt;
    }

    eZone zoneAt(const Vector2D& p, PHLMONITOR monitor) {
        const auto BOX        = monitor->logicalBox();
        const bool LEFT       = p.x <= BOX.x + EDGE;
        const bool RIGHT      = p.x >= BOX.x + BOX.w - EDGE;
        const bool TOP        = p.y <= BOX.y + EDGE;
        const bool NEARTOP    = p.y <= BOX.y + CORNER;
        const bool NEARBOTTOM = p.y >= BOX.y + BOX.h - CORNER;

        if (LEFT)
            return NEARTOP ? eZone::TOP_LEFT : NEARBOTTOM ? eZone::BOTTOM_LEFT : eZone::LEFT;
        if (RIGHT)
            return NEARTOP ? eZone::TOP_RIGHT : NEARBOTTOM ? eZone::BOTTOM_RIGHT : eZone::RIGHT;
        if (TOP)
            return eZone::TOP;
        return eZone::NONE;
    }

    // The zone's box on the monitor's work area (what the shell's bar leaves), title bar included.
    CBox zoneBox(eZone zone, PHLMONITOR monitor) {
        const auto A      = monitor->logicalBoxMinusReserved();
        const auto HALF_W = (A.w - GAP * 3) / 2;
        const auto HALF_H = (A.h - GAP * 3) / 2;
        const auto LEFT_X = A.x + GAP, RIGHT_X = A.x + GAP * 2 + HALF_W;
        const auto TOP_Y = A.y + GAP, BOTTOM_Y = A.y + GAP * 2 + HALF_H;
        const auto FULL_H = A.h - GAP * 2;

        switch (zone) {
            case eZone::LEFT: return {LEFT_X, TOP_Y, HALF_W, FULL_H};
            case eZone::RIGHT: return {RIGHT_X, TOP_Y, HALF_W, FULL_H};
            case eZone::TOP: return {LEFT_X, TOP_Y, A.w - GAP * 2, FULL_H};
            case eZone::TOP_LEFT: return {LEFT_X, TOP_Y, HALF_W, HALF_H};
            case eZone::TOP_RIGHT: return {RIGHT_X, TOP_Y, HALF_W, HALF_H};
            case eZone::BOTTOM_LEFT: return {LEFT_X, BOTTOM_Y, HALF_W, HALF_H};
            case eZone::BOTTOM_RIGHT: return {RIGHT_X, BOTTOM_Y, HALF_W, HALF_H};
            case eZone::NONE: break;
        }
        return {};
    }

    void announce(std::optional<CBox> box) {
        IPC::Socket2::sock()->postEvent({.event = "samsnap", .data = box ? std::format("{},{},{},{}", box->x, box->y, box->w, box->h) : ""});
    }

    bool snappable(PHLWINDOW window) {
        return window && window->layoutTarget() && window->layoutTarget()->floating() && !Fullscreen::controller()->isFullscreen(window);
    }

    // Puts the window in the zone: the zone's box less the window's title bar and borders.
    void snap(PHLWINDOW window, eZone zone, PHLMONITOR monitor) {
        if (!snappable(window) || !monitor || zone == eZone::NONE)
            return;

        const auto TARGET = window->layoutTarget();
        if (!g_snap.before.contains(window.get()))
            g_snap.before[window.get()] = TARGET->position();

        const auto BOX = zoneBox(zone, monitor);
        const auto EXT = window->getFullWindowReservedArea();
        TARGET->setPositionGlobal(CBox{BOX.x + EXT.topLeft.x, BOX.y + EXT.topLeft.y, BOX.w - EXT.topLeft.x - EXT.bottomRight.x,
                                       BOX.h - EXT.topLeft.y - EXT.bottomRight.y});
    }

    void onMotion() {
        const auto& DRAG   = g_layoutManager->dragController();
        const auto  TARGET = DRAG->target();
        const auto  WINDOW = TARGET ? TARGET->window() : nullptr;
        if (!WINDOW || DRAG->mode() != MBIND_MOVE || !snappable(WINDOW))
            return;

        const auto CURSOR = g_pInputManager->getMouseCoordsInternal();

        if (g_snap.dragging.lock() != WINDOW) {
            g_snap.dragging         = WINDOW;
            g_snap.dragStart        = CURSOR;
            g_snap.restoredThisDrag = false;
        }

        // Dragging a snapped window away gives it back its size; the drag carries on with it.
        if (!g_snap.restoredThisDrag && g_snap.before.contains(WINDOW.get()) && CURSOR.distance(g_snap.dragStart) > UNSNAP_AT) {
            const auto BEFORE = g_snap.before.at(WINDOW.get());
            g_snap.before.erase(WINDOW.get());
            g_snap.restoredThisDrag = true;
            TARGET->setPositionGlobal(CBox{TARGET->position().pos(), BEFORE.size()});
        }

        const auto MONITOR = State::monitorState()->query().vec(CURSOR).run();
        const auto ZONE    = MONITOR ? zoneAt(CURSOR, MONITOR) : eZone::NONE;
        if (ZONE == g_snap.zone && MONITOR == g_snap.zoneMonitor.lock())
            return;

        g_snap.zone        = ZONE;
        g_snap.zoneMonitor = MONITOR;
        announce(ZONE == eZone::NONE ? std::nullopt : std::optional<CBox>{zoneBox(ZONE, MONITOR)});
    }

    void onEnded() {
        const auto WINDOW  = g_snap.dragging.lock();
        const auto ZONE    = g_snap.zone;
        const auto MONITOR = g_snap.zoneMonitor.lock();

        g_snap.dragging.reset();
        g_snap.zoneMonitor.reset();
        g_snap.zone = eZone::NONE;
        if (ZONE != eZone::NONE)
            announce(std::nullopt);

        if (WINDOW && ZONE != eZone::NONE)
            snap(WINDOW, ZONE, MONITOR);
    }

    int luaSnap(lua_State* L) {
        const auto ZONE = zoneFromName(luaL_checkstring(L, 1));
        if (!ZONE)
            return luaL_error(L, "hl.plugin.hyprbars.snap: expected left, right, top, top_left, top_right, bottom_left or bottom_right");

        const auto WINDOW = Desktop::focusState()->window();
        if (WINDOW)
            snap(WINDOW, *ZONE, WINDOW->m_monitor.lock());
        return 0;
    }

    int luaUnsnap(lua_State* L) {
        const auto WINDOW = Desktop::focusState()->window();
        if (!WINDOW || !g_snap.before.contains(WINDOW.get()) || !snappable(WINDOW)) {
            lua_pushboolean(L, false);
            return 1;
        }

        const auto BEFORE = g_snap.before.at(WINDOW.get());
        g_snap.before.erase(WINDOW.get());
        WINDOW->layoutTarget()->setPositionGlobal(BEFORE);
        lua_pushboolean(L, true);
        return 1;
    }
}

void samSnapInit(HANDLE handle) {
    g_snap.motion = g_layoutManager->dragController()->m_events.motion.listen([] { onMotion(); });
    g_snap.ended  = g_layoutManager->dragController()->m_events.ended.listen([] { onEnded(); });

    static auto DESTROYED = Event::bus()->m_events.window.destroy.listen([](PHLWINDOWREF window) { g_snap.before.erase(window.get()); });

    HyprlandAPI::addLuaFunction(handle, "hyprbars", "snap", ::luaSnap);
    HyprlandAPI::addLuaFunction(handle, "hyprbars", "unsnap", ::luaUnsnap);
}

void samSnapExit() {
    g_snap.motion.reset();
    g_snap.ended.reset();
    g_snap.before.clear();
}
