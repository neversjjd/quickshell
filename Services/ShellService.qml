pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// Clavis 自身的生命周期。
//
// 「关掉之后 UI 就没了，没法再从 UI 打开」是这类开关的固有问题，所以这里拆成两件事：
//   · autostartEnabled —— 持久开关，决定下次登录要不要拉起 Clavis（写 XDG autostart 条目）；
//   · quit()           —— 只关掉当前这一次，之后用 `key shell` 重新启动。
Singleton {
    id: root

    readonly property string autostartDir: Paths.xdgConfigHome + "/autostart"
    readonly property string autostartFile: root.autostartDir + "/clavis-shell.desktop"
    readonly property string startCommand: "key shell -d"

    property bool autostartEnabled: false
    property bool autostartReady: false
    property bool quitRequested: false

    readonly property string desktopEntry: "[Desktop Entry]\n"
        + "Type=Application\n"
        + "Name=Clavis Shell\n"
        + "Comment=" + qsTr("Quickshell 桌面外壳") + "\n"
        + "Exec=" + root.startCommand + "\n"
        + "Terminal=false\n"

    Process {
        id: probeEntry

        command: ["test", "-f", root.autostartFile]
        onExited: exitCode => {
            root.autostartEnabled = exitCode === 0;
            root.autostartReady = true;
        }
    }

    Process {
        id: writeEntry

        onExited: exitCode => {
            if (exitCode !== 0)
                return ;
            probeEntry.running = true;
        }
    }

    Process {
        id: removeEntry

        command: ["rm", "-f", root.autostartFile]
        onExited: exitCode => {
            if (exitCode !== 0)
                return ;
            probeEntry.running = true;
        }
    }

    Process {
        id: quitProcess

        command: ["key", "shell", "-k"]
    }

    function setAutostartEnabled(value) {
        if (!root.autostartReady)
            return ;
        if (!!value === root.autostartEnabled)
            return ;

        if (value) {
            writeEntry.command = [
                "sh", "-c",
                "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/clavis-shell.desktop\"",
                "sh", root.autostartDir, root.desktopEntry
            ];
            writeEntry.running = true;
        } else {
            removeEntry.running = true;
        }
    }

    function quit() {
        if (root.quitRequested)
            return ;
        root.quitRequested = true;
        quitProcess.running = true;
    }

    Component.onCompleted: probeEntry.running = true
}
