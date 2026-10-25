// Snap — dev-harness screenshot helper for scenes: after `delay` ms, grabs
// `region` ("x,y wxh" in global compositor coordinates, "" = all outputs) into
// $QS_DEV_OUT/<name>.png using the grim that dev/run provides ($QS_DEV_GRIM).
import QtQuick
import Quickshell

Timer {
    property string name: "snap"
    property string region: ""
    property int delay: 1000

    interval: delay
    running: true
    onTriggered: {
        const out = (Quickshell.env("QS_DEV_OUT") || "/tmp") + "/" + name + ".png";
        const grim = Quickshell.env("QS_DEV_GRIM") || "grim";
        Quickshell.execDetached(region ? [grim, "-g", region, out] : [grim, out]);
    }
}
