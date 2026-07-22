/*
    kde-tags popup: search field, virtual-desktops-style coworker grid with
    scrolling, message field and action buttons.
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Controls 2.5 as QQC2
import QtQuick.Layouts 1.1
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras 2.0 as PlasmaExtras

PlasmaExtras.Representation {
    id: fullRep

    readonly property int cellWidth: PlasmaCore.Units.gridUnit * 6
    readonly property int cellHeight: Math.round(cellWidth / 1.6)

    // Case- and accent-insensitive filter.
    function norm(s) {
        return String(s).toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    }

    readonly property var shownRoster: {
        const q = norm(searchField.text.trim());
        if (q === "") {
            return root.roster;
        }
        return root.roster.filter(function (c) {
            return norm(c.name || "").indexOf(q) !== -1;
        });
    }

    // Geometry is computed over the full roster (not the filtered one) so the
    // popup does not resize while typing in the search field.
    readonly property int gridColumns: Math.max(1, Math.min(4, Math.ceil(Math.sqrt(root.count))))
    readonly property int gridRowsAll: Math.max(1, Math.ceil(root.count / gridColumns))

    // Selection by topic: survives filtering and roster reordering.
    property string selectedTopic: ""
    readonly property var selectedCoworker: {
        if (selectedTopic === "") {
            return null;
        }
        for (let i = 0; i < root.roster.length; ++i) {
            if (String(root.roster[i].topic || "").trim() === selectedTopic) {
                return root.roster[i];
            }
        }
        return null; // the selected coworker is no longer in the roster
    }

    function selectedCell() {
        for (let i = 0; i < shownRoster.length; ++i) {
            if (String(shownRoster[i].topic || "").trim() === selectedTopic) {
                return repeater.itemAt(i); // may be null: always guard
            }
        }
        return null; // selected but filtered out: no visible feedback
    }

    collapseMarginsHint: true
    focus: true

    Layout.minimumWidth: PlasmaCore.Units.gridUnit * 14
    Layout.preferredWidth: Math.max(Layout.minimumWidth,
        gridColumns * cellWidth + (gridColumns + 3) * PlasmaCore.Units.smallSpacing)
    Layout.maximumWidth: PlasmaCore.Units.gridUnit * 26
    Layout.minimumHeight: PlasmaCore.Units.gridUnit * 10
    Layout.preferredHeight: Math.min(Layout.maximumHeight, Math.max(Layout.minimumHeight,
        Math.min(gridRowsAll, 4) * (cellHeight + PlasmaCore.Units.smallSpacing)
        + PlasmaCore.Units.smallSpacing * 3
        + (header ? header.implicitHeight : 0) + (footer ? footer.implicitHeight : 0)))
    Layout.maximumHeight: PlasmaCore.Units.gridUnit * 26

    // On popup open: clear search and selection (property observer, because
    // Connections on Plasmoid cannot resolve expandedChanged in Plasma 5).
    readonly property bool popupExpanded: Plasmoid.expanded
    onPopupExpandedChanged: {
        if (popupExpanded) {
            selectedTopic = "";
            searchField.text = "";
        }
    }

    header: PlasmaExtras.PlasmoidHeading {
        contentItem: RowLayout {
            spacing: PlasmaCore.Units.smallSpacing

            PlasmaExtras.SearchField {
                id: searchField

                Layout.fillWidth: true
                visible: !root.offline
                placeholderText: root.tr("popup.search")
                // Re-evaluated on every open → the search field grabs focus
                focus: Plasmoid.expanded && !root.offline
                onAccepted: {
                    // Enter with a single match: select it and jump to the message
                    if (fullRep.shownRoster.length === 1) {
                        fullRep.selectedTopic = String(fullRep.shownRoster[0].topic || "").trim();
                        messageField.forceActiveFocus();
                    }
                }
            }

            // Title shown in place of the search field when offline.
            PlasmaExtras.Heading {
                Layout.fillWidth: true
                visible: root.offline
                level: 4
                text: "kde-tags"
                elide: Text.ElideRight
            }

            // Online/offline toggle.
            PlasmaComponents3.ToolButton {
                icon.name: root.offline ? "user-offline" : "user-online"
                checkable: true
                checked: !root.offline
                onClicked: root.setOffline(!root.offline)
                PlasmaComponents3.ToolTip.text: root.offline ? root.tr("popup.goOnline") : root.tr("popup.goOffline")
                PlasmaComponents3.ToolTip.visible: hovered
            }

            PlasmaComponents3.ToolButton {
                icon.name: "configure"
                onClicked: Plasmoid.action("configure").trigger()
                PlasmaComponents3.ToolTip.text: root.tr("popup.configure")
                PlasmaComponents3.ToolTip.visible: hovered
            }
        }
    }

    Item {
        anchors.fill: parent

        PlasmaComponents3.ScrollView {
            id: scroll

            anchors.fill: parent
            visible: !root.offline && fullRep.shownRoster.length > 0
            contentWidth: availableWidth // vertical scrolling only

            Item {
                width: scroll.availableWidth
                implicitHeight: grid.height + PlasmaCore.Units.smallSpacing * 2

                Grid {
                    id: grid

                    anchors.top: parent.top
                    anchors.topMargin: PlasmaCore.Units.smallSpacing
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: fullRep.gridColumns
                    spacing: PlasmaCore.Units.smallSpacing

                    Repeater {
                        id: repeater

                        model: fullRep.shownRoster

                        PersonCell {
                            width: fullRep.cellWidth
                            height: fullRep.cellHeight
                            coworker: modelData
                            selected: String(modelData.topic || "").trim() === fullRep.selectedTopic
                            onActivated: {
                                const t = String(modelData.topic || "").trim();
                                fullRep.selectedTopic = (fullRep.selectedTopic === t ? "" : t);
                            }
                        }
                    }
                }
            }
        }

        PlasmaExtras.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - PlasmaCore.Units.gridUnit * 2
            visible: !root.offline && root.count === 0
            iconName: "dialog-messages"
            text: root.tr("popup.empty")
            helpfulAction: QQC2.Action {
                icon.name: "configure"
                text: root.tr("popup.configure")
                onTriggered: Plasmoid.action("configure").trigger()
            }
        }

        PlasmaExtras.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - PlasmaCore.Units.gridUnit * 2
            visible: !root.offline && root.count > 0 && fullRep.shownRoster.length === 0
            iconName: "edit-none"
            text: root.tr("popup.noMatches")
        }

        // Offline state: whole widget is inactive until back online.
        PlasmaExtras.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - PlasmaCore.Units.gridUnit * 2
            visible: root.offline
            iconName: "user-offline"
            text: root.tr("popup.offlineTitle")
            explanation: root.tr("popup.offlineHelp")
            helpfulAction: QQC2.Action {
                icon.name: "user-online"
                text: root.tr("popup.goOnline")
                onTriggered: root.setOffline(false)
            }
        }
    }

    footer: PlasmaExtras.PlasmoidHeading {
        visible: !root.offline
        contentItem: ColumnLayout {
            spacing: PlasmaCore.Units.smallSpacing

            PlasmaComponents3.TextField {
                id: messageField

                Layout.fillWidth: true
                placeholderText: root.tr("popup.message")
                onAccepted: {
                    if (sendButton.enabled) {
                        sendButton.clicked();
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: PlasmaCore.Units.smallSpacing

                PlasmaComponents3.Button {
                    id: presenceButton

                    Layout.fillWidth: true
                    icon.name: "user-available"
                    text: root.tr("popup.requestPresence")
                    enabled: fullRep.selectedCoworker !== null
                    onClicked: {
                        const cell = fullRep.selectedCell();
                        if (cell) {
                            root.requestPresence(fullRep.selectedCoworker, cell);
                        } else if (fullRep.selectedCoworker) {
                            // selected but filtered out of view: send without cell feedback
                            root.requestPresence(fullRep.selectedCoworker, dummyCell);
                        }
                    }
                }

                PlasmaComponents3.Button {
                    id: sendButton

                    Layout.fillWidth: true
                    icon.name: "document-send"
                    text: root.tr("popup.sendMessage")
                    enabled: fullRep.selectedCoworker !== null
                             && messageField.text.trim().length > 0
                    onClicked: {
                        const target = fullRep.selectedCell() || dummyCell;
                        if (fullRep.selectedCoworker) {
                            root.sendMessage(fullRep.selectedCoworker,
                                messageField.text.trim(), target,
                                function (ok) {
                                    if (ok) {
                                        messageField.text = "";
                                    }
                                });
                        }
                    }
                }
            }
        }
    }

    // Callback receiver for when the selected cell is filtered out of view:
    // implements the same minimal interface as PersonCell.
    QtObject {
        id: dummyCell

        property string callState: "idle"
        property var activeXhr: null

        function beginCall(xhr) {
            activeXhr = xhr;
            callState = "sending";
            dummyTimeout.restart();
        }

        function finishCall(ok) {
            dummyTimeout.stop();
            activeXhr = null;
            callState = "idle";
        }
    }

    Timer {
        id: dummyTimeout

        interval: 10000
        onTriggered: {
            if (dummyCell.activeXhr) {
                dummyCell.activeXhr.abort();
            }
            dummyCell.finishCall(false);
        }
    }
}
