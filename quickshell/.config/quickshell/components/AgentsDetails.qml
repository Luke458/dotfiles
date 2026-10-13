pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services"
import "."

// Agent usage dashboard, ported from Omarchy's agents panel. One section per
// subscription: hero, limits (or balance), tokens by day, and tokens by model.
Item {
    id: root

    implicitWidth: 460
    implicitHeight: contentColumn.implicitHeight + Theme.sectionPadding * 2

    readonly property var providers: AgentsUsage.enabledProviders
    readonly property int providerIndex: AgentsUsage.providerIndex
    readonly property var provider: AgentsUsage.currentProvider
    readonly property var limits: limitWindows(provider)
    readonly property var models: modelRows(provider)
    readonly property var binding: AgentsUsage.bindingWindow(provider)
    readonly property var balance: provider ? provider.balance : null
    readonly property bool balanceAlarming: !!balance && balance.funded > 0
        && balance.remaining / balance.funded <= 0.1

    // Countdowns and "today" read this so an open panel keeps telling the
    // truth as the clock moves.
    property double nowMs: Date.now()

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    Component.onCompleted: {
        if (AgentsUsage.selectedProviderId === "")
            AgentsUsage.selectProvider(AgentsUsage.providerIndex);
        forceActiveFocus();
    }

    // ---------------------------------------------------------------- limits
    function windowIsLong(text) {
        return text.indexOf("week") >= 0 || text.indexOf("7-day") >= 0 || text.indexOf("seven") >= 0
            || text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0;
    }

    function windowSpanMs(label) {
        const text = String(label || "").toLowerCase();
        if (text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0) return 30 * 24 * 3600 * 1000;
        if (windowIsLong(text)) return 7 * 24 * 3600 * 1000;
        const hours = text.match(/(\d+)\s*-?\s*h(?:our)?\b/);
        if (hours) return Number(hours[1]) * 3600 * 1000;
        const minutes = text.match(/(\d+)\s*-?\s*m(?:in(?:ute)?s?)?\b/);
        if (minutes) return Number(minutes[1]) * 60 * 1000;
        return 0;
    }

    function windowTitle(label) {
        const text = String(label || "").toLowerCase();
        if (text.indexOf("month") >= 0) return "Monthly";
        if (windowIsLong(text)) return "Weekly";
        if (text.indexOf("session") >= 0 || windowSpanMs(label) > 0) return "Session";
        const plain = String(label || "").replace(/\s*\(.*\)\s*/, "").trim();
        return plain === "" ? "Limit" : plain;
    }

    function limitWindow(label, percent, resetAt, title) {
        return {
            title: String(title || "") !== "" ? String(title) : windowTitle(label),
            percent: Number(percent),
            resetAt: String(resetAt || "")
        };
    }

    function limitWindows(p) {
        if (!p) return [];
        const out = [];
        const list = p.limits || [];
        for (let i = 0; i < list.length; i++) {
            const entry = list[i] || {};
            const percent = Number(entry.percent);
            if (percent >= 0) out.push(limitWindow(entry.label, percent, entry.resetsAt, entry.title));
        }
        return out;
    }

    function resetMsFor(w) {
        if (!w || w.resetAt === "") return -1;
        const ms = new Date(w.resetAt).getTime();
        return isFinite(ms) ? ms - root.nowMs : -1;
    }

    function formatDuration(ms) {
        if (!(ms > 0)) return "now";
        const minutes = Math.floor(ms / 60000);
        const hours = Math.floor(minutes / 60);
        const days = Math.floor(hours / 24);
        if (days > 0) return days + "d " + (hours % 24) + "h";
        if (hours > 0) return hours + "h " + (minutes % 60) + "m";
        return Math.max(1, minutes) + "m";
    }

    // --------------------------------------------------------------- balance
    function currencyPrefix(currency) {
        const code = String(currency || "USD").toUpperCase();
        if (code === "USD") return "$";
        if (code === "EUR") return "€";
        if (code === "GBP") return "£";
        return code + " ";
    }

    function formatMoney(value, currency) {
        let amount = Number(value);
        if (!isFinite(amount)) amount = 0;
        return currencyPrefix(currency) + amount.toFixed(2);
    }

    function balanceDetailText(b) {
        if (!b || !(b.funded > 0)) return "";
        let text = formatMoney(b.spent, b.currency) + " spent of " + formatMoney(b.funded, b.currency) + " funded";
        if (b.estimated) text += " · estimated";
        return text;
    }

    // ---------------------------------------------------------------- content
    function heroMeta(p) {
        if (!p) return "";
        if (String(p.usageStatusText || "") !== "") return p.usageStatusText;
        const tier = String(p.tierLabel || "");
        if (tier === "") return "Subscription";
        return tier.charAt(0).toUpperCase() + tier.slice(1);
    }

    function todayDate() {
        const now = new Date(root.nowMs);
        return now.getFullYear()
            + "-" + String(now.getMonth() + 1).padStart(2, "0")
            + "-" + String(now.getDate()).padStart(2, "0");
    }

    function dayName(date) {
        const parsed = new Date(String(date || "") + "T00:00:00");
        if (isNaN(parsed.getTime())) return String(date || "");
        return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][parsed.getDay()];
    }

    function dayLabel(date, today) {
        if (today) return "Today";
        return dayName(date);
    }

    function dayTooltip(day, today) {
        if (!day) return "";
        const parsed = new Date(String(day.date) + "T00:00:00");
        const label = isNaN(parsed.getTime())
            ? String(day.date)
            : dayName(day.date) + " " + (parsed.getMonth() + 1) + "/" + parsed.getDate();
        let text = label + " · " + AgentsUsage.formatTokenCount(Number(day.messageCount || 0)) + " tokens";
        if (today && provider && provider.hasPromptStats !== false)
            text += " · " + Number(provider.todayPrompts || 0) + " prompts · "
                + Number(provider.todaySessions || 0) + " sessions";
        return text;
    }

    function weekPeak(p) {
        const days = p ? (p.recentDays || []) : [];
        let peak = 0;
        for (let i = 0; i < days.length; i++) peak = Math.max(peak, Number(days[i].messageCount || 0));
        return peak;
    }

    function modelRows(p) {
        const usageByModel = p ? (p.modelUsage || {}) : {};
        const rows = [];
        for (const id in usageByModel) {
            const bucket = usageByModel[id] || {};
            const input = Number(bucket.inputTokens || 0);
            const output = Number(bucket.outputTokens || 0);
            const cacheRead = Number(bucket.cacheReadInputTokens || 0);
            const cacheWrite = Number(bucket.cacheCreationInputTokens || 0);
            rows.push({
                name: AgentsUsage.friendlyModelName(id),
                total: input + output + cacheRead + cacheWrite,
                input: input,
                output: output,
                cacheRead: cacheRead,
                cacheWrite: cacheWrite
            });
        }
        rows.sort((a, b) => b.total - a.total);
        return rows.slice(0, 4);
    }

    function modelTooltipText(row) {
        if (!row) return "";
        return "In " + AgentsUsage.formatTokenCount(row.input)
            + " · out " + AgentsUsage.formatTokenCount(row.output)
            + " · cache read " + AgentsUsage.formatTokenCount(row.cacheRead)
            + " · cache write " + AgentsUsage.formatTokenCount(row.cacheWrite);
    }

    function footerText() {
        if (AgentsUsage.syncStatusText !== "") return AgentsUsage.syncStatusText;
        if (provider && provider.syncEnabled && provider.syncDeviceCount > 0)
            return "Merged from " + provider.syncDeviceCount + " device" + (provider.syncDeviceCount === 1 ? "" : "s");
        return "Read-only · credentials stay with the CLIs";
    }

    function resetCreditsText(credits) {
        if (!credits || !(Number(credits.available) > 0)) return "";
        const count = Number(credits.available);
        let text = count + " free reset" + (count === 1 ? "" : "s");
        const expires = new Date(String(credits.nextExpiresAt || "")).getTime();
        if (isFinite(expires) && expires > root.nowMs)
            text += " · next expires in " + root.formatDuration(expires - root.nowMs);
        return text;
    }

    function iconSource(p) {
        if (!p) return "";
        return Qt.resolvedUrl("../assets/agents/" + p.providerId + ".svg");
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }

    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_H || event.key === Qt.Key_Left)
                AgentsUsage.cycleProvider(-1);
            else if (event.key === Qt.Key_L || event.key === Qt.Key_Right)
                AgentsUsage.cycleProvider(1);
            else if (event.key === Qt.Key_R || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                AgentsUsage.refresh();
            else
                return;
            event.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.bgSolid
            radius: Theme.radiusMedium
        }

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.sectionPadding
            spacing: Theme.spacingSection

            // ---------- Hero ----------
            RowLayout {
                width: parent.width
                spacing: Theme.spacingComfortable
                visible: !!root.provider

                Image {
                    id: heroMark
                    source: root.iconSource(root.provider)
                    sourceSize: Qt.size(Theme.fontSizeDisplayLarge * 2, Theme.fontSizeDisplayLarge * 2)
                    Layout.preferredWidth: Theme.fontSizeDisplayLarge
                    Layout.preferredHeight: Theme.fontSizeDisplayLarge
                    fillMode: Image.PreserveAspectFit
                    visible: source !== "" && status !== Image.Error
                }

                Text {
                    visible: !heroMark.visible
                    text: "\u{f121}"
                    color: Theme.selBg
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontSizeDisplayLarge
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingTiny

                    Text {
                        text: root.provider ? root.provider.providerName : ""
                        color: Theme.selFg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.panelTitleSize
                        font.bold: true
                    }

                    Text {
                        text: root.heroMeta(root.provider)
                        color: Theme.fg
                        opacity: Theme.opacityStrong
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.panelCaptionSize
                    }
                }

                StyledButton {
                    iconText: "\uf021"
                    Accessible.name: "Refresh"
                    fixedWidth: 30
                    bordered: true
                    onClicked: AgentsUsage.refresh()
                }
            }

            Text {
                visible: root.providers.length === 0
                width: parent.width
                topPadding: Theme.spacingPage
                text: "No AI coding subscriptions found.\nAgents show up here once you have used them."
                color: Theme.fg
                opacity: Theme.opacitySecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelBodySize
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            // ---------- Provider switch ----------
            RowLayout {
                visible: root.providers.length > 1
                width: parent.width
                spacing: Theme.spacingSmall

                Repeater {
                    model: root.providers

                    StyledButton {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        text: modelData.providerName
                        selected: index === root.providerIndex
                        bordered: true
                        onClicked: AgentsUsage.selectProvider(index)
                    }
                }
            }

            // ---------- Auth status ----------
            Rectangle {
                visible: !!root.provider && String(root.provider.authHelpText || "") !== ""
                    && String(root.provider.usageStatusText || "") !== ""
                width: parent.width
                implicitHeight: authText.implicitHeight + Theme.spacingXLarge
                color: root.alpha(Theme.negative, 0.10)
                radius: Theme.radiusMedium
                border.color: root.alpha(Theme.negative, 0.35)
                border.width: 1

                Text {
                    id: authText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.spacingSection
                    anchors.rightMargin: Theme.spacingSection
                    text: root.provider ? String(root.provider.authHelpText || "") : ""
                    color: Theme.fg
                    opacity: Theme.opacitySecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.panelCaptionSize
                    wrapMode: Text.WordWrap
                }
            }

            // ---------- Free resets (Codex) ----------
            Text {
                visible: text !== ""
                width: parent.width
                text: root.resetCreditsText(root.provider ? root.provider.resetCredits : null)
                color: Theme.fg
                opacity: Theme.opacitySecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
            }

            // ---------- Balance ----------
            Column {
                visible: !!root.balance
                width: parent.width
                spacing: Theme.spacingMedium

                readonly property real ratio: root.balance && root.balance.funded > 0
                    ? root.clamp(root.balance.remaining / root.balance.funded, 0, 1)
                    : -1

                SectionHeader {
                    width: parent.width
                    text: "BALANCE"
                }

                Item {
                    width: parent.width
                    implicitHeight: Math.max(balanceLabel.implicitHeight, balanceValue.implicitHeight)

                    Text {
                        id: balanceLabel
                        text: "Prepaid credits"
                        color: Theme.fg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.panelBodySize
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: balanceValue
                        text: root.balance ? root.formatMoney(root.balance.remaining, root.balance.currency) : ""
                        color: root.balanceAlarming ? Theme.negative : Theme.fg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.panelBodySize
                        font.bold: true
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Meter {
                    visible: parent.ratio >= 0
                    width: parent.width
                    value: parent.ratio
                    alarming: root.balanceAlarming
                }

                Text {
                    visible: text !== ""
                    width: parent.width
                    text: root.balanceDetailText(root.balance)
                    color: Theme.fg
                    opacity: Theme.opacitySecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.panelCaptionSize
                }
            }

            // ---------- Limits ----------
            Column {
                visible: root.limits.length > 0
                width: parent.width
                spacing: Theme.spacingMedium

                SectionHeader {
                    width: parent.width
                    text: "LIMITS"
                }

                Repeater {
                    model: root.limits

                    LimitRow {
                        required property var modelData
                        width: parent.width
                        window: modelData
                    }
                }
            }

            // ---------- Tokens by day ----------
            Column {
                id: daysSection
                visible: !!root.provider && root.provider.recentDays && root.provider.recentDays.length > 0
                width: parent.width
                spacing: Theme.spacingMedium

                readonly property var days: root.provider ? (root.provider.recentDays || []) : []
                readonly property real peak: Math.max(1, root.weekPeak(root.provider))

                SectionHeader {
                    width: parent.width
                    text: "TOKENS BY DAY"
                }

                Repeater {
                    model: daysSection.days

                    DayRow {
                        required property var modelData
                        width: parent.width
                        day: modelData
                        ratio: Number(modelData.messageCount || 0) / daysSection.peak
                        today: String(modelData.date || "") === root.todayDate()
                    }
                }
            }

            // ---------- Tokens by model ----------
            Column {
                visible: root.models.length > 0
                width: parent.width
                spacing: Theme.spacingMedium

                SectionHeader {
                    width: parent.width
                    text: "TOKENS BY MODEL"
                }

                Repeater {
                    model: root.models

                    ModelRow {
                        required property var modelData
                        width: parent.width
                        row: modelData
                        share: modelData.total / Math.max(1, root.models[0].total)
                    }
                }
            }

            Text {
                visible: text !== ""
                width: parent.width
                text: root.footerText()
                color: Theme.fg
                opacity: Theme.opacitySecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }

    // ------------------------------------------------------------- components
    component SectionHeader: Text {
        color: Theme.selFg
        font.family: Theme.fontMono
        font.pixelSize: Theme.panelBodySize
        font.bold: true
    }

    component Meter: Item {
        id: meter
        property real value: -1
        property bool alarming: false
        implicitHeight: Math.max(4, Math.round(Theme.spacingSection * 0.55))

        Rectangle {
            id: meterTrack
            anchors.fill: parent
            radius: height / 2
            color: Theme.surfaceSubtle
        }

        Rectangle {
            anchors.left: meterTrack.left
            anchors.verticalCenter: meterTrack.verticalCenter
            height: meterTrack.height
            radius: meterTrack.radius
            width: meterTrack.width * root.clamp(meter.value, 0, 1)
            color: meter.alarming ? Theme.negative : Theme.selBg

            Behavior on width {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }
    }

    component LimitRow: Column {
        id: limitRow
        property var window: null
        readonly property bool alarming: window && window.percent >= 0.9
        spacing: Theme.spacingCompact

        Item {
            width: parent.width
            implicitHeight: Math.max(limitLabel.implicitHeight, limitValue.implicitHeight)

            Text {
                id: limitLabel
                text: limitRow.window ? limitRow.window.title : ""
                color: Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelBodySize
                elide: Text.ElideRight
                anchors.left: parent.left
                anchors.right: limitValue.left
                anchors.rightMargin: Theme.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: limitValue
                text: limitRow.window && limitRow.window.percent >= 0
                    ? Math.round(limitRow.window.percent * 100) + "%"
                    : "—"
                color: limitRow.alarming ? Theme.negative : Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelBodySize
                font.bold: true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Meter {
            width: parent.width
            value: limitRow.window ? limitRow.window.percent : -1
            alarming: limitRow.alarming
        }

        Text {
            width: parent.width
            text: {
                const remainingMs = root.resetMsFor(limitRow.window);
                return remainingMs > 0 ? "Resets in " + root.formatDuration(remainingMs) : "";
            }
            color: Theme.fg
            opacity: Theme.opacitySecondary
            font.family: Theme.fontMono
            font.pixelSize: Theme.panelCaptionSize
        }
    }

    component DayRow: Item {
        id: dayRow
        property var day: null
        property real ratio: 0
        property bool today: false
        implicitHeight: Math.max(dayLabel.implicitHeight, dayValue.implicitHeight) + Theme.spacingSmall

        Text {
            id: dayLabel
            text: root.dayLabel(dayRow.day ? dayRow.day.date : "", dayRow.today)
            color: dayRow.today ? Theme.selFg : Theme.fg
            opacity: dayRow.today ? 1 : Theme.opacitySecondary
            font.family: Theme.fontMono
            font.pixelSize: Theme.panelCaptionSize
            font.bold: dayRow.today
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 46
        }

        Rectangle {
            id: dayTrack
            anchors.left: dayLabel.right
            anchors.right: dayValue.left
            anchors.leftMargin: Theme.spacingComfortable
            anchors.rightMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(4, Math.round(Theme.spacingSection * 0.55))
            radius: height / 2
            color: Theme.surfaceSubtle

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                radius: parent.radius
                width: parent.width * root.clamp(dayRow.ratio, 0, 1)
                color: dayRow.today ? Theme.selBg : root.alpha(Theme.selBg, 0.55)

                Behavior on width {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }
        }

        Text {
            id: dayValue
            text: AgentsUsage.formatTokenCount(dayRow.day ? Number(dayRow.day.messageCount || 0) : 0)
            color: dayRow.today ? Theme.selFg : Theme.fg
            opacity: dayRow.today ? 1 : Theme.opacitySecondary
            font.family: Theme.fontMono
            font.pixelSize: Theme.panelCaptionSize
            font.bold: true
            horizontalAlignment: Text.AlignRight
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 52
        }

        MouseArea {
            id: dayHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Text {
            visible: dayHover.containsMouse
            text: root.dayTooltip(dayRow.day, dayRow.today)
            color: Theme.fg
            opacity: Theme.opacitySecondary
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
            anchors.right: parent.right
            anchors.top: parent.bottom
            z: 10
        }
    }

    component ModelRow: Item {
        id: modelRow
        property var row: null
        property real share: 0
        implicitHeight: modelName.implicitHeight + Theme.spacingLarge

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMedium
            color: root.alpha(Theme.selBg, 0.05)
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.clamp(modelRow.share, 0, 1)
            radius: Theme.radiusMedium
            color: root.alpha(Theme.selBg, 0.14)

            Behavior on width {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        Text {
            id: modelName
            text: modelRow.row ? modelRow.row.name : ""
            color: Theme.fg
            font.family: Theme.fontMono
            font.pixelSize: Theme.panelBodySize
            elide: Text.ElideRight
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingComfortable
            anchors.right: modelTokens.left
            anchors.rightMargin: Theme.spacingComfortable
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: modelTokens
            text: modelRow.row ? AgentsUsage.formatTokenCount(modelRow.row.total) : ""
            color: Theme.fg
            opacity: Theme.opacitySecondary
            font.family: Theme.fontMono
            font.pixelSize: Theme.panelBodySize
            font.bold: true
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingComfortable
            anchors.verticalCenter: parent.verticalCenter
        }

        MouseArea {
            id: modelHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Text {
            visible: modelHover.containsMouse
            text: root.modelTooltipText(modelRow.row)
            color: Theme.fg
            opacity: Theme.opacitySecondary
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption
            anchors.left: parent.left
            anchors.top: parent.bottom
            z: 10
        }
    }
}
