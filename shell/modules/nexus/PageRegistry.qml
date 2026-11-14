pragma Singleton

import QtQuick
import Caelestia.I18n

QtObject {
    id: root

    // Each page, in the order the list shows them (PageCompRegistry has their contents in the same
    // order). Search looks through each one's label and description, the names of the settings on
    // it, and other words people might look for them by.
    readonly property list<var> pages: [
        // Appearance
        {
            id: "style",
            label: Tr.tr("Wallpaper & style"),
            icon: "palette",
            description: Tr.tr("Wallpaper, colours, light and dark"),
            category: "appearance",
            settings: [Tr.tr("Wallpaper"), Tr.tr("Colours"), Tr.tr("Dark theme"), Tr.tr("Light and dark by the time of day"), Tr.tr("Transparency"), Tr.tr("Fonts")],
            keywords: "theme background picture color colour scheme accent dark mode light mode automatic sunset sunrise night day transparent blur"
        },

        // Connectivity
        {
            id: "network",
            label: Tr.tr("Network"),
            icon: "wifi",
            description: Tr.tr("Wi-Fi, ethernet, VPN"),
            category: "connectivity",
            settings: [Tr.tr("Wi-Fi"), Tr.tr("Ethernet"), Tr.tr("VPN")],
            keywords: "wireless internet connection password hotspot cable wired proxy"
        },
        {
            id: "devices",
            label: Tr.tr("Connected devices"),
            icon: "devices_other",
            description: Tr.tr("Bluetooth, pairing"),
            category: "connectivity",
            noFill: true,
            settings: [Tr.tr("Bluetooth"), Tr.tr("Pairing")],
            keywords: "headphones earbuds speaker controller keyboard mouse pair connect"
        },
        {
            id: "audio",
            label: Tr.tr("Audio"),
            icon: "volume_up",
            description: Tr.tr("App volumes, sound devices"),
            category: "connectivity",
            settings: [Tr.tr("Volume"), Tr.tr("Output"), Tr.tr("Input"), Tr.tr("App volumes")],
            keywords: "sound speakers headphones microphone mic mute loud quiet"
        },

        // This computer
        {
            id: "displays",
            label: Tr.tr("Displays"),
            icon: "monitor",
            description: Tr.tr("Resolution, scale, night light"),
            category: "device",
            settings: [Tr.tr("Resolution"), Tr.tr("Refresh rate"), Tr.tr("Scale"), Tr.tr("Orientation"), Tr.tr("Position"), Tr.tr("Brightness"), Tr.tr("Night light"), Tr.tr("Warmth")],
            keywords: "screen monitor display size zoom bigger smaller text size hz hertz rotate rotation portrait landscape mirror external projector arrange dpi hidpi blue light warm colour temperature dim"
        },
        {
            id: "input",
            label: Tr.tr("Mouse & keyboard"),
            icon: "mouse",
            description: Tr.tr("Pointer, touchpad, layouts"),
            category: "device",
            settings: [Tr.tr("Pointer speed"), Tr.tr("Pointer acceleration"), Tr.tr("Natural scrolling"), Tr.tr("Tap to click"), Tr.tr("Left-handed"), Tr.tr("Scrolling speed"), Tr.tr("Keyboard layout"), Tr.tr("Caps Lock key"), Tr.tr("Repeat speed")],
            keywords: "trackpad touchpad cursor sensitivity scroll direction reverse click tap right click two finger palm typing language input keymap qwerty azerty dvorak repeat delay num lock"
        },
        {
            id: "power",
            label: Tr.tr("Power & battery"),
            icon: "battery_charging_full",
            description: Tr.tr("Power mode, battery, sleep"),
            category: "device",
            settings: [Tr.tr("Power mode"), Tr.tr("Battery saver"), Tr.tr("Limit charging"), Tr.tr("Lock the screen after"), Tr.tr("Turn the screen off after"), Tr.tr("Sleep after")],
            keywords: "battery health charge limit performance balanced energy suspend idle timeout screen off blank lock screensaver"
        },

        // System
        {
            id: "account",
            label: Tr.tr("Your account"),
            icon: "account_circle",
            description: Tr.tr("Picture, password, fingerprints"),
            category: "system",
            settings: [Tr.tr("Change your picture"), Tr.tr("Change your password"), Tr.tr("Add a fingerprint"), Tr.tr("Remove your fingerprints")],
            keywords: "user profile photo avatar face login sign in password fingerprint reader unlock security"
        },
        {
            id: "datetime",
            label: Tr.tr("Date & time"),
            icon: "schedule",
            description: Tr.tr("Time zone, network time, clock"),
            category: "system",
            settings: [Tr.tr("Set the time automatically"), Tr.tr("Time zone"), Tr.tr("Clock format")],
            keywords: "clock date time ntp sync synchronise synchronize wrong time timezone 24-hour 12-hour am pm"
        },
        {
            id: "accessibility",
            label: Tr.tr("Accessibility"),
            icon: "accessibility_new",
            description: Tr.tr("Text size, pointer size, motion"),
            category: "system",
            settings: [Tr.tr("Text size"), Tr.tr("Pointer size"), Tr.tr("Reduce motion")],
            keywords: "bigger larger font zoom cursor mouse pointer animation animations motion sickness vision a11y"
        },
        {
            id: "updates",
            label: Tr.tr("Updates"),
            icon: "update",
            description: Tr.tr("Nightly updates, restart, go back"),
            category: "system",
            settings: [Tr.tr("Check for updates now"), Tr.tr("Go back to the previous version")],
            keywords: "upgrade version rollback restart new"
        },

        // Shell
        {
            id: "panels",
            label: Tr.tr("Panels"),
            icon: "dock_to_bottom",
            description: Tr.tr("Dashboard, taskbar, launcher, sidebar"),
            category: "shell",
            settings: [Tr.tr("Dashboard"), Tr.tr("Taskbar"), Tr.tr("Launcher"), Tr.tr("Sidebar"), Tr.tr("Quick settings")],
            keywords: "bar clock tray workspaces status icons quick toggles"
        },
        {
            id: "apps",
            label: Tr.tr("Apps"),
            icon: "apps",
            description: Tr.tr("Default apps, favourites, hidden apps"),
            category: "shell",
            settings: [Tr.tr("Default apps"), Tr.tr("Favourites"), Tr.tr("Hidden apps")],
            keywords: "browser terminal files email mail default application program"
        },
        {
            id: "services",
            label: Tr.tr("Services"),
            icon: "build",
            description: Tr.tr("Notifications, polling, lyrics"),
            category: "shell",
            settings: [Tr.tr("Notifications")],
            keywords: "notification alerts toasts do not disturb lyrics poll interval"
        },
        {
            id: "language",
            label: Tr.tr("Language & region"),
            icon: "globe",
            description: Tr.tr("UI language, weather location, display units"),
            category: "shell",
            settings: [Tr.tr("UI language"), Tr.tr("Temperature"), Tr.tr("Data sizes")],
            keywords: "translation locale units celsius fahrenheit weather location city"
        },

        // About
        {
            id: "about",
            label: Tr.tr("About"),
            icon: "info",
            description: Tr.tr("System information, credits"),
            category: "about",
            settings: [],
            keywords: "version system information hardware computer name credits licence license"
        },
    ]
}
