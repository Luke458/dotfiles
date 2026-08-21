pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../services"
import "PickerModel.js" as PickerModel

PanelWindow { // qmllint disable uncreatable-type
    id: root

    required property string mode
    required property var payload
    required property int requestSerial
    property var allItems: []
    property var currentMatches: []
    property string statusText: ""
    property bool actionPending: false
    property bool ready: false
    readonly property string passwordStoreDir: Quickshell.env("PASSWORD_STORE_DIR") || Quickshell.env("HOME") + "/.local/share/password-store"
    readonly property string menuFile: payload && payload.file ? String(payload.file) : ""
    readonly property string prompt: {
        if (payload && payload.prompt)
            return String(payload.prompt);
        if (mode === "pass") return "Pass:";
        if (mode === "power") return "Power:";
        if (mode === "menu") return "Select:";
        if (mode === "emoji") return "Emoji:";
        return "Run:";
    }
    readonly property var terminalCommand: ["kitty", "-e"]
    property bool pasteAvailable: false

    signal requestClose(string reason)

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.space(24)
    color: Theme.bg
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.namespace: "qs-picker"

    ScreenMoveRemap {
        id: remapGuard
        window: root
    }
    visible: !remapGuard.remapping

    ListModel { id: resultsModel }

    // Generation guards: killing a scan still flushes its StdioCollector
    // asynchronously, so late callbacks must not clobber a newer mode's data.
    property int initSerial: 0
    property int passwordScanSerial: -1
    property int menuScanSerial: -1

    Process {
        id: passwordListProcess
        command: ["find", root.passwordStoreDir, "-type", "f", "-name", "*.gpg"]
        stdout: StdioCollector {
            onStreamFinished: root.loadPasswords(text)
        }
        onExited: (exitCode) => { // qmllint disable signal-handler-parameters
            if (exitCode !== 0 && root.allItems.length === 0)
                root.statusText = "Password store not found";
        }
    }

    Process {
        id: passwordCopyProcess
        onExited: (exitCode) => { // qmllint disable signal-handler-parameters
            notificationProcess.exec(["notify-send", exitCode === 0 ? "Pass" : "Pass Error",
                exitCode === 0 ? "Password copied to clipboard." : "Could not copy password."]);
            root.actionPending = false;
            root.requestClose("password-complete");
        }
    }

    Process { id: notificationProcess }

    Process {
        id: menuFileProcess
        stdout: StdioCollector {
            onStreamFinished: root.loadMenuLines(text)
        }
    }

    function populateApplications() {
        const items = [];
        const apps = DesktopEntries.applications.values;
        if (apps) {
            for (let i = 0; i < apps.length; i++) {
                const app = apps[i];
                items.push({
                    name: app.name || "",
                    kind: "app",
                    appObject: app,
                    genericName: app.genericName || "",
                    metadata: [app.comment || "", app.id || "", app.execString || ""].join(" ")
                });
            }
        }
        allItems = items;
        statusText = items.length > 0 ? "" : "No applications found";
        updateFilter(searchField.text);
    }

    function loadPasswords(text) {
        if (passwordScanSerial !== initSerial)
            return;
        const prefix = passwordStoreDir.endsWith("/") ? passwordStoreDir : passwordStoreDir + "/";
        const items = [];
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            let name = lines[i].trim();
            if (name.startsWith(prefix)) name = name.slice(prefix.length);
            if (name.endsWith(".gpg")) name = name.slice(0, -4);
            if (name) items.push({ name: name, kind: "pass", genericName: "", metadata: "" });
        }
        allItems = items;
        statusText = items.length > 0 ? "" : "No passwords found";
        updateFilter(searchField.text);
    }

    function loadMenuLines(text) {
        if (menuScanSerial !== initSerial)
            return;
        const lines = String(text || "").split("\n").map(line => line.replace(/\r$/, "")).filter(line => line.trim().length > 0);
        allItems = lines.map(line => ({ name: line, kind: "menu", genericName: "", metadata: "" }));
        statusText = lines.length > 0 ? "" : "No menu items";
        updateFilter(searchField.text);
    }

    function populateMenu() {
        if (payload && payload.items instanceof Array) {
            loadMenuLines(payload.items.join("\n"));
        } else if (menuFile) {
            menuScanSerial = initSerial;
            menuFileProcess.exec(["sed", "-n", "1,1000p", menuFile]);
        } else {
            statusText = "No menu items";
            allItems = [];
            updateFilter("");
        }
    }

    function populatePower() {
        allItems = [
            { name: "lock", kind: "power", command: [] },
            { name: "display off", kind: "power", command: [] },
            { name: "shutdown", kind: "power", command: ["systemctl", "poweroff"] },
            { name: "reboot", kind: "power", command: ["systemctl", "reboot"] },
            { name: "suspend", kind: "power", command: ["systemctl", "suspend"] },
            { name: "logout", kind: "power", command: ["uwsm", "stop"] }
        ];
        statusText = "";
        updateFilter(searchField.text);
    }

    function updateFilter(text) {
        currentMatches = PickerModel.filter(allItems, text, 100);
        resultsModel.clear();
        for (let i = 0; i < currentMatches.length; i++)
            resultsModel.append({ name: currentMatches[i].name || "", glyph: currentMatches[i].glyph || "" });
        resultsList.currentIndex = resultsModel.count > 0 ? 0 : -1;
    }

    // Copy the glyph to the clipboard; when ydotoold is running, type it into
    // the previously focused window instead of requiring a manual paste.
    property Process emojiCopyProcess: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    property Timer emojiPasteTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: {
            // The picker has closed by now, so typed keys land in the
            // previously focused window.
            root.emojiPasteProcess.command = ["ydotool", "type", root.pasteGlyph];
            root.emojiPasteProcess.running = true;
        }
    }

    property Process emojiPasteProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: Osd.showMessage("check", "Inserted " + root.pasteGlyph)
        }
        stderr: StdioCollector {
            onStreamFinished: Osd.showMessage("copy", "Copied " + root.pasteGlyph)
        }
    }

    property string pasteGlyph: ""

    function copyEmoji(glyph) {
        if (!glyph)
            return;
        pasteGlyph = glyph;
        emojiCopyProcess.command = ["sh", "-c", "printf %s \"$1\" | wl-copy", "emoji-copy", glyph];
        emojiCopyProcess.running = true;
        requestClose("emoji-selected");
        if (pasteAvailable) {
            emojiPasteTimer.restart();
        } else {
            Osd.showMessage("copy", "Copied " + glyph);
        }
    }

    function selectItem(index) {
        if (actionPending || index < 0 || index >= currentMatches.length)
            return;

        const item = currentMatches[index];
        if (item.kind === "app" && item.appObject) {
            const app = item.appObject;
            if (app.runInTerminal && app.command && app.command.length > 0) {
                const command = terminalCommand.slice();
                for (let i = 0; i < app.command.length; i++) command.push(app.command[i]);
                Quickshell.execDetached({ command: command, workingDirectory: app.workingDirectory });
            } else {
                app.execute();
            }
            requestClose("application-selected");
        } else if (item.kind === "pass") {
            actionPending = true;
            passwordCopyProcess.exec({
                command: ["pass", "-c", item.name],
                environment: ({ PASSWORD_STORE_DIR: passwordStoreDir })
            });
        } else if (item.kind === "emoji") {
            copyEmoji(item.glyph || item.name);
        } else if (item.kind === "power") {
            requestClose("power-selected");
            if (item.name === "lock")
                Lock.requestLock();
            else if (item.name === "display off")
                Power.displayOff();
            else if (item.name === "suspend")
                Power.suspend();
            else
                Quickshell.execDetached(item.command);
        } else {
            print("SELECTED: " + item.name);
            requestClose("menu-selected");
        }
    }

    function populateEmoji() {
        if (emojiItems.length === 0) {
            statusText = "Loading emojis...";
            emojiFile.reload();
            return;
        }
        allItems = emojiItems;
        statusText = "";
        updateFilter(searchField.text);
    }

    // Emojis come from a bundled Unicode keyword list: [{e, k}, ...].
    property var emojiItems: []
    property FileView emojiFile: FileView {
        path: Quickshell.shellPath("assets/emojis.json")
        printErrors: false
        onLoaded: {
            const items = [];
            try {
                const parsed = JSON.parse(text());
                if (Array.isArray(parsed)) {
                    for (let i = 0; i < parsed.length; i++) {
                        const entry = parsed[i];
                        if (!entry || !entry.e || !entry.k) continue;
                        const words = String(entry.k).trim().split(/\s+/);
                        items.push({
                            // Label shows the leading keywords; the full
                            // keyword string stays searchable via genericName.
                            name: words.slice(0, 4).join(" "),
                            genericName: words.join(" "),
                            metadata: "",
                            kind: "emoji",
                            glyph: entry.e
                        });
                    }
                }
            } catch (error) {
                console.warn("PickerOverlay: invalid emoji data: " + error);
            }
            root.emojiItems = items;
            if (root.mode === "emoji") {
                root.statusText = items.length > 0 ? "" : "No emojis loaded";
                root.allItems = items;
                root.updateFilter(root.searchField.text);
            }
        }
    }

    function initialize() {
        const gen = ++initSerial;
        passwordListProcess.running = false;
        searchField.text = "";
        allItems = [];
        currentMatches = [];
        statusText = "";
        actionPending = false;
        if (mode === "pass") {
            statusText = "Loading passwords...";
            passwordScanSerial = gen;
            passwordListProcess.running = true;
        } else if (mode === "power") {
            populatePower();
        } else if (mode === "menu") {
            populateMenu();
        } else if (mode === "emoji") {
            populateEmoji();
        } else {
            populateApplications();
        }
        Qt.callLater(() => searchField.forceActiveFocus());
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillHeight: true
            implicitWidth: promptText.implicitWidth + Theme.space(20)
            color: Theme.selBg
            Text {
                id: promptText
                anchors.centerIn: parent
                text: root.prompt
                color: Theme.selFg
                font.bold: true
                font.pixelSize: Theme.fontSizeBar
                font.family: Theme.fontMono
            }
        }

        TextField {
            id: searchField
            Layout.preferredWidth: Theme.space(root.mode === "pass" ? 260 : 200)
            Layout.fillHeight: true
            focus: true
            background: Item {}
            color: Theme.selFg
            selectionColor: Theme.selBg
            selectedTextColor: Theme.selFg
            font.pixelSize: Theme.fontSizeBar
            font.family: Theme.fontMono
            verticalAlignment: TextInput.AlignVCenter
            leftPadding: Theme.space(Theme.controlPadding)
            onTextChanged: root.updateFilter(text)
            onAccepted: root.selectItem(resultsList.currentIndex)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    event.accepted = true;
                    root.requestClose("escape");
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                    event.accepted = true;
                    resultsList.currentIndex = Math.min(resultsList.count - 1, resultsList.currentIndex + 1);
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    event.accepted = true;
                    resultsList.currentIndex = Math.max(0, resultsList.currentIndex - 1);
                }
            }
        }

        Text {
            visible: resultsModel.count === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: root.statusText
            color: Theme.fg
            font.pixelSize: Theme.fontSizeBar
            font.family: Theme.fontMono
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        ListView {
            id: resultsList
            visible: resultsModel.count > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            clip: true
            model: resultsModel
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Item {
                id: resultItem
                required property int index
                required property string name
                required property string glyph
                width: glyph !== ""
                    ? Math.min(itemGlyph.implicitWidth + labelText.implicitWidth + Theme.space(24), Theme.space(340))
                    : Math.min(itemText.implicitWidth + Theme.space(20), Theme.space(340))
                height: root.implicitHeight
                Rectangle {
                    anchors.fill: parent
                    color: Theme.controlFill(false, itemTap.hovered, resultsList.currentIndex === resultItem.index)
                }
                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.space(8)
                    visible: resultItem.glyph !== ""
                    leftPadding: Theme.space(Theme.controlPadding)
                    rightPadding: Theme.space(Theme.controlPadding)

                    Text {
                        id: itemGlyph
                        text: resultItem.glyph
                        font.pixelSize: Theme.fontSizeHeadingLarge
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        id: labelText
                        text: resultItem.name
                        color: Theme.controlText(false, itemTap.hovered, resultsList.currentIndex === resultItem.index, true)
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontMono
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
                Text {
                    id: itemText
                    visible: resultItem.glyph === ""
                    anchors.fill: parent
                    leftPadding: Theme.space(Theme.controlPadding)
                    rightPadding: Theme.space(Theme.controlPadding)
                    text: resultItem.name
                    color: Theme.controlText(false, itemTap.hovered, resultsList.currentIndex === resultItem.index, true)
                    font.pixelSize: Theme.fontSizeBar
                    font.family: Theme.fontMono
                    font.bold: resultsList.currentIndex === resultItem.index
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideMiddle
                }
                HoverHandler { id: itemTap }
                TapHandler { onTapped: root.selectItem(resultItem.index) }
            }
        }
    }

    Connections {
        target: DesktopEntries
        enabled: root.mode === "launcher"
        function onApplicationsChanged() { root.populateApplications(); }
    }

    onRequestSerialChanged: if (ready) initialize()

    Component.onCompleted: {
        ready = true;
        pasteProbe.running = true;
        initialize();
    }

    // One-shot probe: typing via ydotool only works while its daemon runs.
    property Process pasteProbe: Process {
        command: ["sh", "-c", "pgrep -x ydotoold >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: root.pasteAvailable = text.trim() === "yes"
        }
    }

    Component.onDestruction: {
        allItems = [];
        currentMatches = [];
        searchField.text = "";
    }
}
