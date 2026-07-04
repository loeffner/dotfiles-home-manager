pragma Singleton

// Single source of truth for the whole shell's look. Gruvbox dark on a
// Material-3 token vocabulary: a neutral grey surface ramp (surface →
// surfaceContainerHighest), one runtime-switchable accent (primary, chosen in
// the Control Center), and a few status hues. One converged token set drives
// both the flat bar widgets and the M3 cluster/popouts.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: theme
    // ── Surfaces ──────────────────────────────────────────────────────────
    // The bar + every surface derive from the chosen background preset (bg,
    // below). The two token sets were converged — surface/surfaceContainer* +
    // outline are the single vocabulary now.
    readonly property color bar: bg.bar // bar background

    // ── Status colours (used sparingly, by meaning) ─────────────────────────
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

    // ── Material-3 layer (the DMS-grade cluster + popups) ───────────────────
    // A small Material-3 vocabulary mapped onto Gruvbox so the vendored-feel
    // widgets (M*.qml) and the new Popout sit naturally with the rest of the
    // bar. Surfaces step up in lightness like M3 surfaceContainer roles.
    readonly property string symbols: "Material Symbols Rounded" // icon font (Material Symbols)

    // Background preset: the surface ramp + bar + hairline. Runtime-switchable in
    // the Control Center and persisted (see bgFile) like the accent.
    property string bgChoice: "medium" // medium | hard | soft
    readonly property var backgrounds: ({
            "medium": { "surface": "#282828", "container": "#32302f", "high": "#3c3836", "highest": "#504945", "outline": "#665c54", "bar": "#1d2021" },
            "hard": { "surface": "#1d2021", "container": "#282828", "high": "#32302f", "highest": "#3c3836", "outline": "#504945", "bar": "#141617" },
            "soft": { "surface": "#32302f", "container": "#3c3836", "high": "#504945", "highest": "#665c54", "outline": "#7c6f64", "bar": "#282828" }
        })
    readonly property var bgOrder: ["soft", "medium", "hard"]
    readonly property var bg: backgrounds[bgChoice] || backgrounds["medium"]

    readonly property color surface: bg.surface // base panel
    readonly property color surfaceContainer: bg.container // raised tile
    readonly property color surfaceContainerHigh: bg.high // higher tile / track
    readonly property color surfaceContainerHighest: bg.highest // highest / pressed
    readonly property color outline: bg.outline // hairline borders
    // The single accent, used shell-wide (focused workspace, interactive
    // controls, active icons). Pick a Gruvbox hue by name — the one knob.
    // Runtime-switchable via the Control Center accent picker; persisted to disk
    // (see accentFile) so the choice survives restarts. Set with setAccent().
    property string accentChoice: "blue" // blue aqua green yellow orange purple red ivory
    readonly property var accents: ({
            "blue": "#458588",
            "aqua": "#689d6a",
            "green": "#98971a",
            "yellow": "#d79921",
            "orange": "#d65d0e",
            "purple": "#b16286",
            "red": "#cc241d",
            "ivory": "#bdae93"
        })
    // Stable order for the picker UI (object key order isn't guaranteed).
    readonly property var accentOrder: ["blue", "aqua", "green", "yellow", "orange", "purple", "red", "ivory"]
    readonly property color primary: accents[accentChoice] || accents["blue"]

    function setAccent(name) {
        if (!accents[name] || name === accentChoice)
            return;
        accentChoice = name;
        accentFile.setText(name);
    }
    function setBackground(name) {
        if (!backgrounds[name] || name === bgChoice)
            return;
        bgChoice = name;
        bgFile.setText(name);
    }

    // Persist the accent + background choices across restarts.
    FileView {
        id: accentFile
        path: (Quickshell.env("HOME") || "") + "/.cache/quickshell/accent"
        watchChanges: false
        printErrors: false
        atomicWrites: true
        onLoaded: {
            const v = (text() || "").trim();
            if (theme.accents[v])
                theme.accentChoice = v;
        }
    }
    FileView {
        id: bgFile
        path: (Quickshell.env("HOME") || "") + "/.cache/quickshell/background"
        watchChanges: false
        printErrors: false
        atomicWrites: true
        onLoaded: {
            const v = (text() || "").trim();
            if (theme.backgrounds[v])
                theme.bgChoice = v;
        }
    }
    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", (Quickshell.env("HOME") || "") + "/.cache/quickshell"]);
        accentFile.reload();
        bgFile.reload();
    }
    // onPrimary text auto-contrasts with the chosen hue (dark text on light
    // accents, light text on dark ones). NB: names must not start with "on" +
    // uppercase — QML parses those as signal handlers, not properties.
    readonly property color primaryText: (0.299 * primary.r + 0.587 * primary.g + 0.114 * primary.b) > 0.5 ? "#1d2021" : "#fbf1c7"
    readonly property color surfaceText: "#ebdbb2" // primary text/icon on surfaces
    readonly property color surfaceVariantText: "#928374" // secondary text/icon
    // Hover highlight for bar icons: the accent, so hovered widgets pick up the
    // shell's colour. The ivory accent is too close to the resting surfaceText to
    // read as a highlight, so fall back to the brightest fg there instead.
    readonly property color iconHover: accentChoice === "ivory" ? "#fbf1c7" : primary

    readonly property int radiusS: 8
    readonly property int radiusM: 12
    readonly property int radiusL: 16 // M3 card / popout rounding

    // Generous spacing for the M3 popouts (the flat legacy bar keeps pad/gap).
    readonly property int padL: 16 // popout inner padding
    readonly property int gapL: 12 // popout section spacing

    // ── Motion (lifted verbatim from DankMaterialShell) ─────────────────────
    // The popout's signature feel: a short spring-overshoot enter and an
    // emphasized-decelerate exit, applied to scale + opacity + a small offset.
    readonly property int popoutDur: 150 // DMS popoutAnimationDuration (Short)
    readonly property int durShort: 150
    readonly property int durMed: 250
    readonly property real scaleCollapsed: 0.90 // collapsed scale; lower = springier overshoot
    readonly property real animOffset: 16 // DMS effectAnimOffset (Standard), px
    // Cubic-bezier control points (Anims.expressiveDefaultSpatial / .emphasized).
    readonly property list<real> springEnter: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property list<real> emphExit: [0.05, 0.0, 0.133333, 0.06, 0.166667, 0.40, 0.208333, 0.82, 0.25, 1.0, 1.0, 1.0]
}
