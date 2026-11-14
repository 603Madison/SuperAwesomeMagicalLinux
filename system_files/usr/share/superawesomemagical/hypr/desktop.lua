-- SuperAwesomeMagicalLinux's window management: a normal desktop.
--
-- Windows open floating (overlapping, centred, the size they ask for), and every app that doesn't
-- draw its own title bar gets ours: the title in Lexend, and minimize, maximize and close buttons.
-- Drag the bar to move a window, drag any edge to resize it, double-click the bar to maximize it
-- (beside the shell's bar). Minimizing tucks a window into a hidden workspace; the taskbar in the
-- shell's bar brings it back. Apps with their own title bars (GTK apps) show the same three buttons
-- (the dconf button layout), and their minimize works the same way.
--
-- Snapping, as Windows' Aero Snap: drag a window to the left or right edge of the screen to fill
-- that half, to the top to fill the screen, into a corner for a quarter; drag it away and it gets
-- its size back. The shell shows where it will land. (The title bars plugin does this; snap.cpp.)
--
-- Keys on top of the usual ones: Alt+F4 closes, Alt+Tab switches windows, Super+Left/Right snap to
-- a half, Super+Up maximizes, Super+Down puts a snapped window back (or minimizes one that isn't).
-- Super+Alt+Space still tiles a window, for anyone who wants that.
--
-- To change any of it, override it in ~/.config/caelestia/hypr-user.lua.

local scheme = require("scheme.current")

local MINIMIZED = "special:minimized"

local function rgb(hex)
    return "rgb(" .. hex .. ")"
end

local function quote(s)
    return string.format("%q", s)
end

hl.config({
    general = {
        resize_on_border        = true,
        extend_border_grab_area = 12,
        hover_icon_on_border    = true,
        snap                    = {
            enabled     = true,
            window_gap  = 10,
            monitor_gap = 14,
        },
    },
    input = {
        -- Focus follows clicks, not the pointer.
        follow_mouse               = 2,
        float_switch_override_focus = 0,
    },
})

-- Every window floats; the ones that aren't X11 (whose popups count as windows) open centred.
hl.window_rule({ name = "sam-float", match = { class = ".*" }, float = true })
hl.window_rule({ name = "sam-centre", match = { xwayland = false }, center = true })

---- Minimize and restore ---------------------------------------------------------------------------

local function minimize(window)
    if not window or (window.workspace and window.workspace.name == MINIMIZED) then
        return
    end
    hl.dispatch(hl.dsp.window.move({ window = "address:" .. window.address, workspace = MINIMIZED, follow = false }))
end

-- The title bars' and apps' own minimize buttons, and the taskbar, all arrive here.
hl.on("window.minimize", function(window, minimized)
    if minimized then
        minimize(window)
    end
end)

---- Keys -------------------------------------------------------------------------------------------

local maximize = hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })

hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind("SUPER + Up", maximize)
-- The title bars plugin snaps; it's only there once Hyprland has loaded it, after reading this file.
local function snap(zone)
    return function()
        if hl.plugin.hyprbars then
            hl.plugin.hyprbars.snap(zone)
        end
    end
end
hl.bind("SUPER + Left", snap("left"))
hl.bind("SUPER + Right", snap("right"))
hl.bind("SUPER + Down", function()
    if not (hl.plugin.hyprbars and hl.plugin.hyprbars.unsnap()) then
        minimize(hl.get_active_window())
    end
end)
-- Alt+Tab already cycles windows (Caelestia's binds); bring the one it lands on to the front.
hl.bind("ALT + TAB", hl.dsp.window.bring_to_top())
hl.bind("SHIFT + ALT + TAB", hl.dsp.window.bring_to_top())

---- Title bars -------------------------------------------------------------------------------------

-- Our build of Hyprland's hyprbars (build_files/titlebars/), which also snaps. Hyprland loads plugins after reading
-- the config and then reads it again, so its settings only apply on that second read.
hl.plugin.load("/usr/lib64/hyprland/libsuperawesomemagical-titlebars.so")

if hl.plugin.hyprbars then
    local function dispatch(expr)
        return "hyprctl dispatch " .. quote(expr)
    end

    hl.config({
        plugin = {
            hyprbars = {
                bar_height                 = 36,
                bar_color                  = rgb(scheme.surfaceContainer),
                col                        = { text = rgb(scheme.onSurface) },
                -- Lexend for the title; the buttons' icons come from Material Symbols.
                bar_text_font              = "Lexend, Material Symbols Rounded",
                bar_text_size              = 11,
                bar_text_weight            = "semibold",
                bar_text_align             = "left",
                bar_padding                = 14,
                bar_button_padding         = 8,
                bar_part_of_window         = true,
                bar_precedence_over_border = true,
                inactive_button_color      = rgb(scheme.surfaceContainerHighest),
                on_double_click            = dispatch([[hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })]]),
            },
        },
    })

    -- Buttons, right to left: close, maximize, minimize.
    hl.plugin.hyprbars.add_button({
        bg_color = rgb(scheme.error),
        fg_color = rgb(scheme.onError),
        size     = 20,
        icon     = "\u{e5cd}", -- close
        action   = dispatch("hl.dsp.window.close()"),
    })
    hl.plugin.hyprbars.add_button({
        bg_color = rgb(scheme.secondary),
        fg_color = rgb(scheme.onSecondary),
        size     = 20,
        icon     = "\u{e3c6}", -- crop_square
        action   = dispatch([[hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })]]),
    })
    hl.plugin.hyprbars.add_button({
        bg_color = rgb(scheme.primary),
        fg_color = rgb(scheme.onPrimary),
        size     = 20,
        icon     = "\u{e15b}", -- remove
        action   = dispatch(string.format([[hl.dsp.window.move({ workspace = %q, follow = false })]], MINIMIZED)),
    })

    -- The shell's settings window has its own close button.
    hl.window_rule({ name = "sam-shell-no-bar", match = { class = "^org\\.quickshell$" }, ["hyprbars:no_bar"] = true })
end
