pragma Singleton

// Single source of truth for the bar's look. Gruvbox dark, but deliberately
// restrained: a neutral grey base with the soft Gruvbox foreground, and accent
// colour used *only* where it carries meaning (focused workspace, alerts). The
// rest of the setup (kitty/zellij borders) already leans hard on bright orange
// and green, so the bar stays quiet on purpose.
import Quickshell
import QtQuick

Singleton {
    // ── Surfaces ──────────────────────────────────────────────────────────
    readonly property color bar: "#1d2021" // bar background (bg0_h)
    readonly property color bgPopup: "#282828" // popup / toast background (bg0)
    readonly property color bg1: "#3c3836" // hover, track, separators
    readonly property color bg2: "#504945" // idle workspace pill
    readonly property color border: "#3c3836"

    // ── Text ──────────────────────────────────────────────────────────────
    readonly property color fg: "#ebdbb2" // primary foreground
    readonly property color dim: "#928374" // secondary / inactive

    // ── Accents (used sparingly, by meaning) ────────────────────────────────
    readonly property color accent: "#83a598" // focus / selection (gruvbox blue)
    readonly property color good: "#b8bb26" // connected / strong signal
    readonly property color warn: "#d79921" // caution
    readonly property color urgent: "#fb4934" // disconnected / critical

    // ── Metrics ─────────────────────────────────────────────────────────────
    readonly property string font: "MesloLGS Nerd Font"
    readonly property int fontSize: 13
    readonly property int iconSize: 15
    readonly property int barHeight: 30
    readonly property int pad: 10 // outer padding / group spacing
    readonly property int gap: 6 // intra-group spacing
    readonly property int radius: 10 // popup bottom-corner rounding
    readonly property int flareRadius: 14 // concave shoulder size where popups meet the bar
}
