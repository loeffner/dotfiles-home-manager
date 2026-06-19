// Transparent full-screen layer active while any popup is open. Catches clicks
// that would otherwise go to applications and calls hide() with animation.
// Sits above application windows (WlrLayer.Top) but below XDG popups, which are
// always above layershell surfaces in Wayland regardless of layer.
import QtQuick
import Quickshell

PanelWindow {
    id: backdrop
    required property var modelData
    screen: modelData

    // Cover the whole screen below the bar (bar's exclusive zone pushes us down
    // when using ExclusionMode.Normal, but we use Ignore and set margin manually
    // so we don't affect other windows).
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Theme.barHeight
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"
    visible: PopupState.anyOpen || ShellState.dashboardOpen

    MouseArea {
        anchors.fill: parent
        onClicked: {
            PopupState.current?.hide();
            ShellState.dashboardOpen = false;
        }
    }
}
