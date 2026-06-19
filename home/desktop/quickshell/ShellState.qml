pragma Singleton

// Global visibility flags for full-screen shell layers (dashboard, power modal).
// Distinct from PopupState which manages the bar's dropdown popups.
import QtQuick
import Quickshell

Singleton {
    property bool dashboardOpen: false
    property bool powerOpen: false

    // Close any open bar popup when entering a full-screen mode.
    onDashboardOpenChanged: if (dashboardOpen) PopupState.current?.hide()
    onPowerOpenChanged: if (powerOpen) { PopupState.current?.hide(); dashboardOpen = false; }
}
