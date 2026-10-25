// Quickshell entry point: everything per screen — the bar (with its volume OSD),
// the island hosting the popout panels, notification toasts, the keybind
// cheatsheet and the camera-import OSD. Services are singletons in services/;
// see README.md for the layout of this tree.
import QtQuick
import Quickshell
import qs.bar
import qs.island
import qs.overlays
import qs.panels

ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property var modelData

            Bar {
                modelData: perScreen.modelData
            }
            Island {
                modelData: perScreen.modelData
                ControlPanel {}
                ConfirmPanel {}
                NotificationsPanel {}
                ClipboardPanel {}
                MailPanel {}
                ProcessesPanel {}
                ClockPanel {}
                TrayMenuPanel {}
            }
            Toasts {
                modelData: perScreen.modelData
            }
            KeybindSheet {
                modelData: perScreen.modelData
            }
            CameraImportOsd {
                modelData: perScreen.modelData
            }
        }
    }
}
