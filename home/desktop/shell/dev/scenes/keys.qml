// Scene: the popouts' shared keyboard rules (IslandPanel), with real key events
// (wtype into the island, which holds the keyboard while open — don't type or
// click while it runs). Per panel: the "?" sheet, Tab for tabs, j/k selection,
// "/" into the search with Ctrl+key shortcuts there, Escape clearing the search
// before closing, Backspace out of a sub-view. Checked via TEST lines, with
// screenshots of some sheets. Only keys without effects outside the throwaway
// state (no volume / network / power / media / kill / paste keys).
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.bar
import qs.island
import qs.panels
import qs.services
import qs.dev

ShellRoot {
    id: shell
    readonly property var scr: Quickshell.screens[0]
    readonly property string wtype: Quickshell.env("QS_DEV_WTYPE") || "wtype"

    Bar {
        id: bar
        modelData: shell.scr
        exclusionMode: ExclusionMode.Ignore
    }
    Island {
        id: island
        modelData: shell.scr
        ControlPanel { id: control }
        ConfirmPanel {}
        NotificationsPanel { id: notifs }
        ClipboardPanel { id: clip }
        MailPanel { id: mail }
        ProcessesPanel { id: procs }
        ClockPanel { id: clock }
        TrayMenuPanel {}
    }

    function open(id) {
        Popouts.open(shell.scr, id, bar.triggers[id]);
    }
    function type(args) {
        Quickshell.execDetached([shell.wtype].concat(args));
    }
    function ctrl(key) {
        shell.type(["-M", "ctrl", key, "-m", "ctrl"]);
    }
    function check(label, ok) {
        console.log("TEST " + (ok ? "ok   " : "FAIL ") + label + (island.hasKeyboard ? "" : " (island has no keyboard)"));
    }
    function shot(name, region) {
        snap.name = name;
        snap.region = region;
        snap.restart();
    }
    function isOpen(id) {
        return Popouts.current(shell.scr) === id;
    }

    property var accent0
    property bool dnd0
    readonly property var steps: [
        // Control centre: sheet, a few letters. (The first open creates the
        // island window; give it a step to get the keyboard.)
        () => shell.open("control"),
        () => {},
        () => shell.type(["?"]),
        () => { shell.check("control: ? opens the sheet", control.help); shell.shot("control-sheet", "2700,0 740x800"); },
        () => shell.type(["x"]),
        () => { shell.check("control: any key closes the sheet", !control.help); shell.accent0 = Settings.accent; shell.type(["c"]); },
        () => { shell.check("control: c cycles the accent", Settings.accent !== shell.accent0); shell.type(["-M", "shift", "c", "-m", "shift"]); },
        () => { shell.check("control: ⇧C cycles back", Settings.accent === shell.accent0); shell.dnd0 = Notifications.dnd; shell.type(["z"]); },
        () => { shell.check("control: z toggles Do Not Disturb", Notifications.dnd !== shell.dnd0); shell.type(["z"]); },

        // Notifications: Tab, j, sub-view out with Backspace, z.
        () => shell.open("notifications"),
        () => shell.type(["-k", "Tab"]),
        () => { shell.check("notifications: Tab → History", notifs.tab === 1); shell.type(["j"]); },
        () => { shell.check("notifications: j selects a card", notifs.selectedId !== "" || notifs.shownEntries.length === 0); shell.type(["s"]); },
        () => { shell.check("notifications: s → settings", notifs.view === 1); shell.type(["-k", "BackSpace"]); },
        () => { shell.check("notifications: ⌫ → back from settings", notifs.view === 0 && shell.isOpen("notifications")); shell.dnd0 = Notifications.dnd; shell.type(["z"]); },
        () => { shell.check("notifications: z toggles Do Not Disturb", Notifications.dnd !== shell.dnd0); shell.type(["z"]); },

        // Clipboard: letters are shortcuts until "/", Ctrl+key in the search,
        // Escape clears before it closes, the sheet with the search focused.
        () => shell.open("clipboard"),
        () => shell.type(["j"]),
        () => { shell.check("clipboard: j moves (search not focused on open)", clip.current === 1 || clip.entries.length < 2); shell.type(["k"]); },
        () => { shell.check("clipboard: k moves back", clip.current === 0); shell.type(["-k", "Tab"]); },
        () => { shell.check("clipboard: Tab → Text", clip.typeFilter === 1); shell.type(["-M", "shift", "-k", "Tab", "-m", "shift"]); },
        () => { shell.check("clipboard: ⇧Tab → All", clip.typeFilter === 0); shell.type(["/"]); },
        () => { shell.check("clipboard: / focuses the search (not typed)", clip.searchField.text === ""); shell.type(["?"]); },
        () => { shell.check("clipboard: ? in the empty search opens the sheet", clip.help); shell.shot("clipboard-sheet", "2700,0 740x560"); },
        () => shell.type(["x"]),
        () => { shell.check("clipboard: any key closes the sheet, not typed", !clip.help && clip.searchField.text === ""); shell.type(["e"]); },
        () => { shell.check("clipboard: letters type into the search now", clip.searchField.text === "e"); shell.ctrl("j"); },
        () => { shell.check("clipboard: Ctrl+J moves while typing", clip.current === 1 || clip.entries.length < 2); shell.type(["-k", "Escape"]); },
        () => { shell.check("clipboard: Esc clears the search first", clip.searchField.text === "" && shell.isOpen("clipboard")); shell.type(["-k", "Escape"]); },
        () => shell.check("clipboard: then Esc closes", !shell.isOpen("clipboard")),

        // Processes: j selects, s sorts, Ctrl+S and Tab from the search.
        () => shell.open("processes"),
        () => shell.type(["j"]),
        () => { shell.check("processes: j selects a row", procs.selectedPid !== ""); shell.type(["s"]); },
        () => { shell.check("processes: s sorts by memory", procs.sortKey === 1); shell.type(["/"]); },
        () => shell.ctrl("s"),
        () => { shell.check("processes: Ctrl+S sorts while typing", procs.sortKey === 0); shell.type(["-k", "Tab"]); },
        () => shell.check("processes: Tab → Mine (from the search)", procs.filter === 1),

        // Calendar: sheet + Escape closes it, not the panel.
        () => shell.open("clock"),
        () => shell.type(["?"]),
        () => { shell.check("clock: ? opens the sheet", clock.help); shell.shot("clock-sheet", "1200,0 1040x560"); },
        () => shell.type(["-k", "Escape"]),
        () => shell.check("clock: Esc closes the sheet, not the panel", !clock.help && shell.isOpen("clock")),

        // Mail: Tab, "/" then Ctrl+J, sheet.
        () => shell.open("mail"),
        () => shell.type(["-k", "Tab"]),
        () => { shell.check("mail: Tab → Unread", mail.filter === 1); shell.type(["-M", "shift", "-k", "Tab", "-m", "shift"]); },
        () => { shell.check("mail: ⇧Tab → All", mail.filter === 0); shell.type(["/"]); },
        () => shell.ctrl("j"),
        () => { shell.check("mail: Ctrl+J moves while typing", mail.kbNav); shell.type(["-k", "Escape"]); },
        () => { shell.check("mail: Esc leaves the empty search, popout stays", !mail.searchField.editing && shell.isOpen("mail")); shell.type(["?"]); },
        () => { shell.check("mail: ? opens the sheet", mail.help); shell.shot("mail-sheet", "1100,0 1240x800"); },
        () => shell.type(["j"]),
        () => shell.check("mail: any key closes the sheet", !mail.help),
        () => mail.openThread(Mail.threads[0].id),
        () => shell.type(["/"]),
        () => { shell.check("mail: / in a conversation → back to the inbox, into its search", mail.readingId === "" && mail.searchField.editing && shell.isOpen("mail")); shell.type(["-k", "Escape"]); },
        () => Qt.exit(0)
    ]
    property int step: 0
    Timer {
        interval: 700
        running: true
        repeat: true
        onTriggered: shell.steps[shell.step++]()
    }
    Snap {
        id: snap
        running: false
        delay: 450
    }
}
