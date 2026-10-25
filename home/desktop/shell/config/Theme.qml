pragma Singleton

// The shell's look: Gruvbox colours (config/palette.json — the single palette
// source, also read by Nix for the lock screen) mapped onto a small Material-3
// token vocabulary, plus metrics and motion. The accent and background preset are
// user settings (services/Settings); everything else is static.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: theme

    // ── Palette (config/palette.json, loaded synchronously at startup) ───────
    FileView {
        path: Quickshell.shellPath("config/palette.json")
        blockLoading: true
        printErrors: true
        JsonAdapter {
            id: pal
            property var accentOrder: ["blue"]
            property var accents: ({ "blue": "#458588" })
            property var backgroundOrder: ["medium"]
            property var backgrounds: ({ "medium": { "surface": "#282828", "container": "#32302f", "high": "#3c3836", "highest": "#504945", "outline": "#665c54", "bar": "#1d2021" } })
            property var text: ({ "primary": "#ebdbb2", "secondary": "#928374", "bright": "#fbf1c7", "dark": "#1d2021" })
            property var status: ({ "good": "#b8bb26", "warn": "#d79921", "urgent": "#fb4934" })
            property string starTint: "#bdae93"
        }
    }

    readonly property var accentOrder: pal.accentOrder
    readonly property var accents: pal.accents
    readonly property var backgroundOrder: pal.backgroundOrder
    readonly property var backgrounds: pal.backgrounds

    // ── Surfaces (from the chosen background preset) ─────────────────────────
    readonly property var bg: backgrounds[Settings.background] || backgrounds["medium"] || backgrounds[backgroundOrder[0]]
    readonly property color bar: bg.bar
    // Popout background: the bar's own colour, so popouts read as the bar
    // extending downward. List rows inside popouts rest on this (opaque) colour.
    readonly property color popout: bar
    readonly property color surface: bg.surface // standalone cards (toasts, overlays)
    readonly property color surfaceContainer: bg.container // raised tile / row hover
    readonly property color surfaceContainerHigh: bg.high // higher tile / track / selected row
    readonly property color surfaceContainerHighest: bg.highest // highest / pressed
    readonly property color outline: bg.outline // hairline borders

    // ── Accent ───────────────────────────────────────────────────────────────
    readonly property color primary: accents[Settings.accent] || accents["blue"] || accents[accentOrder[0]]
    // Text on the accent: dark on light hues, light on dark ones.
    readonly property color primaryText: contrastText(primary)
    // Bar-icon hover tint. The ivory accent is too close to resting text to read
    // as a highlight, so it falls back to the brightest foreground.
    readonly property color iconHover: Settings.accent === "ivory" ? pal.text.bright : primary

    function contrastText(c) {
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > 0.5 ? pal.text.dark : pal.text.bright;
    }

    // ── Text + status ────────────────────────────────────────────────────────
    readonly property color surfaceText: pal.text.primary
    readonly property color surfaceVariantText: pal.text.secondary
    readonly property color good: pal.status.good
    readonly property color warn: pal.status.warn
    readonly property color urgent: pal.status.urgent
    readonly property color starTint: pal.starTint

    // ── Type + metrics ───────────────────────────────────────────────────────
    readonly property string font: "MesloLGS Nerd Font"
    readonly property string symbols: "Material Symbols Rounded" // MIcon ligature font
    readonly property int fontSize: 13
    readonly property int iconSize: 15
    readonly property int barHeight: 30
    readonly property int pad: 10 // bar padding / group spacing
    readonly property int gap: 6 // intra-group spacing
    readonly property int padL: 16 // popout inner padding
    readonly property int gapL: 12 // popout section spacing
    readonly property int radiusS: 8
    readonly property int radiusM: 12
    readonly property int radiusL: 16 // card / popout rounding
    readonly property int flareRadius: 14 // concave shoulder where a popout meets the bar

    // ── Motion ───────────────────────────────────────────────────────────────
    // Popouts morph out of the bar with a spring-overshoot enter and fold back
    // with an emphasized exit (curves from DankMaterialShell's Anims).
    readonly property int durShort: 150
    readonly property int durMed: 250
    readonly property int islandEnterDur: 280
    readonly property int islandExitDur: 200
    readonly property list<real> springEnter: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property list<real> emphExit: [0.05, 0.0, 0.133333, 0.06, 0.166667, 0.40, 0.208333, 0.82, 0.25, 1.0, 1.0, 1.0]
}
