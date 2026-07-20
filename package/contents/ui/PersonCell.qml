/*
    Coworker cell: translucent "glass" rectangle with initials and name;
    selectable (highlighted like the Pager's active desktop).
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3

PlasmaCore.ToolTipArea {
    id: cell

    property var coworker: ({})
    property bool selected: false
    signal activated()

    // Send state (idle | sending | sent | error), with feedback on the cell.
    property string callState: "idle"
    property var activeXhr: null

    readonly property bool discovered: !!coworker && coworker.discovered === true
    readonly property string coworkerName: String(coworker.name || "")
    readonly property string initials: {
        const name = coworkerName.trim();
        if (name === "") {
            return "?";
        }
        return name.split(/\s+/).slice(0, 2).map(function (part) {
            return part.charAt(0).toUpperCase();
        }).join("");
    }

    readonly property color textCol: PlasmaCore.Theme.textColor
    readonly property color hlCol: PlasmaCore.Theme.highlightColor

    mainText: coworkerName
    subText: callState === "error"
        ? root.tr("cell.couldNotSend")
        : (discovered ? root.tr("cell.detected") : "")
          + (selected ? root.tr("cell.selected") : root.tr("cell.clickToSelect"))

    function beginCall(xhr) {
        activeXhr = xhr;
        callState = "sending";
        timeoutTimer.restart();
    }

    function finishCall(ok) {
        if (callState !== "sending") {
            return;
        }
        timeoutTimer.stop();
        activeXhr = null;
        callState = ok ? "sent" : "error";
        resetTimer.interval = ok ? 2000 : 4000;
        resetTimer.restart();
    }

    Timer {
        id: timeoutTimer

        interval: 10000
        onTriggered: {
            const xhr = cell.activeXhr;
            if (xhr) {
                xhr.abort(); // fires DONE with status 0 → finishCall(false)
            }
            cell.finishCall(false);
        }
    }

    Timer {
        id: resetTimer

        onTriggered: cell.callState = "idle"
    }

    Rectangle {
        // glass
        anchors.fill: parent
        z: 1
        radius: PlasmaCore.Units.smallSpacing
        color: cell.selected
            ? Qt.rgba(cell.hlCol.r, cell.hlCol.g, cell.hlCol.b, 0.35)
            : Qt.rgba(cell.textCol.r, cell.textCol.g, cell.textCol.b,
                      (mouseArea.containsMouse || mouseArea.activeFocus) ? 0.15 : 0.08)
        border.width: 1
        border.color: cell.selected
            ? cell.hlCol
            : Qt.rgba(cell.textCol.r, cell.textCol.g, cell.textCol.b, 0.25)
        Behavior on color {
            ColorAnimation { duration: PlasmaCore.Units.longDuration }
        }
        Behavior on border.color {
            ColorAnimation { duration: PlasmaCore.Units.longDuration }
        }
    }

    Rectangle {
        // error tint
        anchors.fill: parent
        z: 2
        radius: PlasmaCore.Units.smallSpacing
        color: PlasmaCore.Theme.negativeTextColor
        opacity: cell.callState === "error" ? 0.25 : 0
        Behavior on opacity {
            OpacityAnimator { duration: PlasmaCore.Units.longDuration }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: cell.width - PlasmaCore.Units.smallSpacing * 4
        z: 3
        spacing: 0
        opacity: cell.callState === "idle" ? 1 : 0.4

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: cell.initials
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            font.weight: Font.Bold
            font.pixelSize: Math.max(PlasmaCore.Theme.smallestFont.pixelSize,
                                     Math.round(cell.height * 0.35))
            elide: Text.ElideRight
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: cell.coworkerName
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            font: PlasmaCore.Theme.smallestFont
            opacity: 0.8
            elide: Text.ElideRight
        }
    }

    PlasmaComponents3.BusyIndicator {
        anchors.centerIn: parent
        z: 4
        width: Math.round(Math.min(cell.width, cell.height) * 0.5)
        height: width
        visible: cell.callState === "sending"
        running: visible
    }

    PlasmaCore.IconItem {
        anchors.centerIn: parent
        z: 4
        width: Math.round(Math.min(cell.width, cell.height) * 0.5)
        height: width
        visible: cell.callState === "sent" || cell.callState === "error"
        source: cell.callState === "error" ? "dialog-error" : "dialog-ok"
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        z: 5
        hoverEnabled: true
        activeFocusOnTab: true
        cursorShape: Qt.PointingHandCursor
        Accessible.name: root.tr("cell.select").replace("%1", cell.coworkerName)
        Accessible.role: Accessible.Button
        onClicked: cell.activated()
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Space:
            case Qt.Key_Enter:
            case Qt.Key_Return:
            case Qt.Key_Select:
                cell.activated();
                break;
            }
        }
    }
}
