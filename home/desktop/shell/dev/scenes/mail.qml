// Scene: the mail panel (mock inbox, as conversations) — list, a single
// message with attachments, a conversation (folded history, own replies,
// quoted text), the unread filter and its empty state, archive + delete, the
// shortcut sheet over the inbox and over a conversation.
// Screenshots each state.
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
    readonly property string region: "1100,0 1240x700"
    property int step: -1

    Bar {
        id: bar
        modelData: shell.scr
        exclusionMode: ExclusionMode.Ignore
    }
    Island {
        id: island
        modelData: shell.scr
        MailPanel { id: mail }
    }

    function shot(name) {
        snap.name = name;
        snap.region = region;
        snap.restart();
    }

    Timer {
        interval: 1400
        running: true
        repeat: true
        onTriggered: {
            shell.step++;
            switch (shell.step) {
            case 0:
                Popouts.open(shell.scr, "mail", bar.triggers["mail"]);
                shell.shot("1-list");
                break;
            case 1:
                mail.openThread("m3");
                shell.shot("2-single");
                break;
            case 2:
                mail.openThread("m2");
                shell.shot("3-conversation");
                break;
            case 3:
                mail.openThread("m4a");
                shell.shot("4-conversation-outlook-quote");
                break;
            case 4:
                mail.back();
                mail.filter = 1;
                shell.shot("5-unread-filter");
                break;
            case 5:
                for (const t of Mail.threads)
                    Mail.setRead(t.id, true);
                shell.shot("6-unread-empty");
                break;
            case 6:
                mail.filter = 0;
                Mail.trash("m1");
                Mail.archive("m2");
                shell.shot("7-after-trash-archive");
                break;
            case 7:
                mail.help = true;
                shell.shot("8-help-inbox");
                break;
            case 8:
                mail.help = false;
                mail.openThread("m4a");
                mail.help = true;
                shell.shot("9-help-conversation");
                break;
            default:
                console.log("TEST unread=" + Mail.unreadCount + " threads=" + Mail.threads.length + " w=" + island.shownW.toFixed(0) + " h=" + island.shownH.toFixed(0));
                Qt.exit(0);
            }
        }
    }
    Snap {
        id: snap
        running: false
        delay: 900
    }
}
