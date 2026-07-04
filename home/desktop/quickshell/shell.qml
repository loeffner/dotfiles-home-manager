// Quickshell entry point. One bar and one toast overlay per connected screen.
// Referencing the Notifications singleton here ensures the notification daemon
// starts at launch, not only when the bar indicator is first shown.
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Variants {
        model: Quickshell.screens
        NotificationToasts {}
    }

    // Pictographic keybind cheatsheet (hold Super via keyd, or the toggle bind).
    Variants {
        model: Quickshell.screens
        Cheatsheet {}
    }

    // Camera-import progress OSD — driven over IPC by the camera-import script.
    Variants {
        model: Quickshell.screens
        CameraImportOsd {}
    }
}
