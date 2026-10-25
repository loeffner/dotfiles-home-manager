// IslandPanel — base for a popout panel hosted by the screen's Island. Declare
// content as children (laid out in a column with the popout padding/spacing).
// The Island sets `screen`; `isOpen` follows Popouts, and opened()/closed() fire
// on the transitions (e.g. to reset or focus things).
//
// Keyboard — the same rules in every popout. The panel takes keyboard focus as
// it opens, so keys arrive here (a search field gets focus only from "/"):
//   ?            the shortcut sheet: `shortcuts` (the `shortcutSection` one
//                highlighted) plus a shared "Everywhere" section; any key closes
//   Tab / ⇧Tab   switch the panel's tabs (tabStep(e) gives the direction)
//   j/k ↑/↓      move a list's selection; Enter / Space use it; d / Del delete it
//   /            focus `searchField` (if the panel has one)
//   Backspace    back() — leave a sub-view (return true if it did)
//   Escape       close the sheet, else clear / leave the search, else close
// Everything but "?" and "/" goes to handleKey(e) — override it, return true if
// handled — which reads e.key and ignores Ctrl: while typing in the search the
// field takes plain letters, and Ctrl+<key> reaches the same shortcut.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Item {
    id: root
    required property string panelId
    property int panelWidth: 360
    property var screen: null // set by the Island
    property bool shown: false // set by the Island: this panel's content is on screen
    readonly property bool isOpen: screen !== null && Popouts.isOpen(screen, panelId)
    property var shortcuts: [] // ShortcutSheet sections
    property int shortcutSection: 0
    property bool help: false // the shortcut sheet is up
    property var searchField: null // the panel's MTextField search, if any
    // The body's height, or while the sheet is up the sheet's — grown or shrunk
    // to it (the body lies squeezed under the opaque sheet meanwhile).
    readonly property real contentHeight: help ? sheet.contentHeight : body.implicitHeight + Theme.padL * 2
    default property alias content: body.data
    signal opened
    signal closed

    function close() {
        if (isOpen)
            Popouts.close(screen);
    }
    function handleKey(e) {
        return false;
    }
    function back() {
        return false;
    }
    // ⇧Tab comes as Backtab from keyboards, but as Tab + Shift from some
    // (wtype, remappers): +1 / -1 for either.
    function tabStep(e) {
        return e.key === Qt.Key_Backtab || (e.modifiers & Qt.ShiftModifier) ? -1 : 1;
    }

    // The search field passes "?" (when empty) and, while the sheet is up,
    // every key here (MTextField.helpKey) — it holds the focus then.
    onSearchFieldChanged: if (searchField) {
        searchField.helpKey = true;
        searchField.helpOpen = Qt.binding(() => root.help);
        searchField.helpRequested.connect(() => root.help = !root.help);
    }

    onIsOpenChanged: {
        if (isOpen) {
            help = false;
            forceActiveFocus();
            opened();
        } else {
            closed();
        }
    }

    Keys.onPressed: e => {
        if (shortcuts.length > 0 && e.text === "?")
            help = !help;
        else if (help)
            help = false; // any key closes the sheet
        else if (searchField && e.key === Qt.Key_Slash && searchField.visible)
            searchField.focusInput(); // never into a hidden field: keys would vanish
        else if (e.key === Qt.Key_Backspace)
            e.accepted = back();
        else
            e.accepted = handleKey(e);
    }
    Keys.onEscapePressed: e => {
        if (help) {
            help = false;
        } else if (searchField && (searchField.text !== "" || searchField.editing)) {
            searchField.clear();
            forceActiveFocus(); // out of the field, back to the shortcuts
        } else {
            e.accepted = false; // up to the Island, which closes
        }
    }

    width: panelWidth
    height: contentHeight
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.durShort; easing.type: Easing.OutCubic } }

    ColumnLayout {
        id: body
        anchors { fill: parent; margins: Theme.padL }
        spacing: Theme.gapL
    }

    ShortcutSheet {
        id: sheet
        anchors.fill: parent
        z: 10
        sections: root.shortcuts.concat([
            {
                "title": "Everywhere",
                "always": true,
                "keys": (root.searchField ? [
                        [["/"], "Search"],
                        [["Ctrl", "+ key"], "Shortcuts while searching"],
                        [["Esc"], "Leave the search, then close"]
                    ] : [
                        [["Esc"], "Close"]
                    ]).concat([[["?"], "This sheet"]])
            }
        ])
        current: root.shortcutSection
        shown: root.help
        onDismissed: root.help = false
    }
}
