// Scene: Settings migration + Theme resolution. Run twice: the first run migrates
// from the legacy ~/.cache files; the second (--keep-home) must load
// settings.json — both must print the same values.
import QtQuick
import Quickshell
import qs.config
import qs.services

ShellRoot {
    // Touch the singletons at startup like the real shell does.
    Component.onCompleted: Theme.primary
    Timer {
        running: true
        interval: 1000
        onTriggered: {
            const n = Settings.notifications;
            console.log("TEST accent=" + Settings.accent + " background=" + Settings.background
                + " primary=" + Theme.primary + " bar=" + Theme.bar
                + " muted=" + JSON.stringify(n.mutedApps) + " rules=" + n.silenceRules.length
                + " known=" + n.knownApps.length + " defaultTimeout=" + n.defaultTimeout
                + " defaultTimeoutCrit=" + n.defaultTimeoutCrit + " accents=" + Theme.accentOrder.length);
        }
    }
}
