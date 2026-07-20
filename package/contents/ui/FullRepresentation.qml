/*
    Popup de kde-tags: cuadrícula de compañeros estilo escritorios múltiples,
    campo de mensaje y botones de acción.
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
    readonly property int gridColumns: Math.max(1, Math.ceil(Math.sqrt(root.count)))
    readonly property int gridRows: Math.max(1, Math.ceil(root.count / gridColumns))

    property int selectedIndex: -1
    readonly property var selectedCoworker: selectedIndex >= 0 && selectedIndex < root.count
        ? root.roster[selectedIndex]
        : null

    function selectedCell() {
        return repeater.itemAt(selectedIndex); // puede ser null: siempre con guard
    }

    collapseMarginsHint: true
    focus: true

    Layout.minimumWidth: PlasmaCore.Units.gridUnit * 14
    Layout.preferredWidth: Math.max(Layout.minimumWidth,
        gridColumns * cellWidth + (gridColumns + 3) * PlasmaCore.Units.smallSpacing)
    Layout.maximumWidth: PlasmaCore.Units.gridUnit * 24
    Layout.minimumHeight: PlasmaCore.Units.gridUnit * 10
    Layout.preferredHeight: Math.min(Layout.maximumHeight, Math.max(Layout.minimumHeight,
        gridRows * cellHeight + (gridRows + 3) * PlasmaCore.Units.smallSpacing
        + (header ? header.implicitHeight : 0) + (footer ? footer.implicitHeight : 0)))
    Layout.maximumHeight: PlasmaCore.Units.gridUnit * 24

    // Al abrir el popup se limpia la selección (observador de propiedad:
    // Connections sobre Plasmoid no resuelve expandedChanged en Plasma 5).
    readonly property bool popupExpanded: Plasmoid.expanded
    onPopupExpandedChanged: {
        if (popupExpanded) {
            selectedIndex = -1;
        }
    }

    Connections {
        target: root
        function onRosterChanged() {
            fullRep.selectedIndex = -1;
        }
    }

    header: PlasmaExtras.PlasmoidHeading {
        contentItem: RowLayout {
            spacing: PlasmaCore.Units.smallSpacing

            PlasmaExtras.Heading {
                Layout.fillWidth: true
                level: 3
                text: "kde-tags"
            }

            PlasmaComponents3.ToolButton {
                icon.name: "configure"
                onClicked: Plasmoid.action("configure").trigger()
                PlasmaComponents3.ToolTip.text: "Configurar…"
                PlasmaComponents3.ToolTip.visible: hovered
            }
        }
    }

    Item {
        anchors.fill: parent

        Grid {
            anchors.centerIn: parent
            visible: root.count > 0
            columns: fullRep.gridColumns
            spacing: PlasmaCore.Units.smallSpacing

            Repeater {
                id: repeater

                model: root.roster

                PersonCell {
                    width: fullRep.cellWidth
                    height: fullRep.cellHeight
                    coworker: modelData
                    selected: index === fullRep.selectedIndex
                    onActivated: fullRep.selectedIndex =
                        (fullRep.selectedIndex === index ? -1 : index)
                }
            }
        }

        PlasmaExtras.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - PlasmaCore.Units.gridUnit * 2
            visible: root.count === 0
            iconName: "dialog-messages"
            text: "No hay compañeros configurados ni detectados en la red local"
            helpfulAction: QQC2.Action {
                icon.name: "configure"
                text: "Configurar…"
                onTriggered: Plasmoid.action("configure").trigger()
            }
        }
    }

    footer: PlasmaExtras.PlasmoidHeading {
        contentItem: ColumnLayout {
            spacing: PlasmaCore.Units.smallSpacing

            PlasmaComponents3.TextField {
                id: messageField

                Layout.fillWidth: true
                placeholderText: "Mensaje (opcional, para \"Enviar mensaje\")"
                // Se re-evalúa en cada apertura del popup → el campo recupera el foco
                focus: Plasmoid.expanded
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
                    text: "Solicitar presencia"
                    enabled: fullRep.selectedCoworker !== null
                    onClicked: {
                        const cell = fullRep.selectedCell();
                        if (cell) {
                            root.requestPresence(fullRep.selectedCoworker, cell);
                        }
                    }
                }

                PlasmaComponents3.Button {
                    id: sendButton

                    Layout.fillWidth: true
                    icon.name: "document-send"
                    text: "Enviar mensaje"
                    enabled: fullRep.selectedCoworker !== null
                             && messageField.text.trim().length > 0
                    onClicked: {
                        const cell = fullRep.selectedCell();
                        if (cell) {
                            root.sendMessage(fullRep.selectedCoworker,
                                messageField.text.trim(), cell,
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
}
