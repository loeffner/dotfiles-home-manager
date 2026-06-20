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

    // Dashboard: slides down from the bar on clock click (self-contained
    // full-screen window with its own click-catcher).
    Variants {
        model: Quickshell.screens
        Dashboard {}
    }

    // Power modal: full-screen overlay, above everything else.
    Variants {
        model: Quickshell.screens
        PowerWindow {}
    }

    // OSD: transient volume / mic / media feedback near the top edge.
    Variants {
        model: Quickshell.screens
        Osd {}
    }

    // Pictographic keybind cheatsheet (hold Super via keyd, or the toggle bind).
    Variants {
        model: Quickshell.screens
        Cheatsheet {}
    }
}
