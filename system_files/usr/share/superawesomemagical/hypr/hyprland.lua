-- SuperAwesomeMagicalLinux's Hyprland setup.
--
-- This is Caelestia's Hyprland config (installed with the image under ./caelestia, so it updates
-- with the OS), with SuperAwesomeMagicalLinux's defaults layered on top and then each person's own
-- changes, which live in their home folder and are never touched by updates:
--
--   ~/.config/caelestia/hypr-vars.lua   return { windowRounding = 10, ... }  to change any of the
--                                       variables in ./caelestia/variables.lua
--   ~/.config/caelestia/hypr-user.lua   any extra Hyprland config (monitors, binds, rules, ...)
--   ~/.config/hypr/scheme/current.lua   colours, written by `caelestia scheme set` (until then,
--                                       ./scheme/current.lua: the SuperAwesomeMagical colours)

local home = os.getenv("HOME")
local system = "/usr/share/superawesomemagical/hypr"
local user_hypr = home .. "/.config/hypr"
local user_caelestia = home .. "/.config/caelestia"

package.path = table.concat({
    system .. "/caelestia/?.lua",
    user_caelestia .. "/?.lua",
    user_hypr .. "/?.lua", -- only for scheme/current.lua
    system .. "/?.lua",    -- the default scheme/current.lua
    package.path,
}, ";")

-- SuperAwesomeMagicalLinux's defaults, then the person's own.
local vars = require("variables")
for k, v in pairs({
    editor        = "gnome-text-editor",
    fileExplorer  = "nautilus",
    audioSettings = "pavucontrol",
    cursorTheme   = "Adwaita",
    -- Opaque windows read better; the shell's own panels keep their blur.
    windowOpacity = 1.0,
    -- Rounder, like the cards in the apps.
    windowRounding = 18,
    -- Plain suspend: hibernation needs disk swap set up, which a default install doesn't have.
    sleepGestureCmd = "systemctl suspend",
}) do
    vars[k] = v
end

-- Load one of the person's files if they have it, saying so if it has a mistake in it.
local function load_user(name)
    local f = io.open(user_caelestia .. "/" .. name .. ".lua")
    if not f then return nil end
    f:close()
    local ok, result = pcall(require, name)
    if not ok then
        hl.exec_cmd("notify-send -u critical 'Your " .. name .. ".lua has a mistake' " .. string.format("%q", tostring(result)))
        return nil
    end
    return result
end

local overrides = load_user("hypr-vars")
if type(overrides) == "table" then
    for k, v in pairs(overrides) do
        vars[k] = v
    end
end

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

require("hyprland.env")
require("hyprland.general")
require("hyprland.input")
require("hyprland.misc")
require("hyprland.animations")
require("hyprland.decoration")
require("hyprland.group")
require("hyprland.execs")
require("hyprland.rules")
require("hyprland.gestures")
require("hyprland.keybinds")

load_user("hypr-user")
