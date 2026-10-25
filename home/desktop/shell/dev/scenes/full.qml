// Scene: the whole shell (shell.qml) for a load check — prints QML warnings.
// (dev/run copies this file over shell.qml in the mirror, so it just re-imports
// the real entry point's pieces.)
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.bar
import qs.island
import qs.overlays
import qs.panels
import qs.dev

ShellRoot {
    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData
            Bar { modelData: perScreen.modelData; exclusionMode: ExclusionMode.Ignore }
            Island {
                modelData: perScreen.modelData
                ControlPanel {}
                ConfirmPanel {}
                NotificationsPanel {}
                ClipboardPanel {}
                ProcessesPanel {}
                ClockPanel {}
                TrayMenuPanel {}
            }
            Toasts { modelData: perScreen.modelData }
            KeybindSheet { modelData: perScreen.modelData }
            CameraImportOsd { modelData: perScreen.modelData }
        }
    }
    Quit { delay: 2500 }
}
