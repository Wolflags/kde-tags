/*
    Popup de kde-tags: buscador, cuadrícula de compañeros estilo escritorios
    múltiples con scroll, campo de mensaje y botones de acción.
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

    // Filtro insensible a mayúsculas y acentos.
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

    // La geometría se calcula sobre el roster completo (no el filtrado) para
    // que el popup no cambie de tamaño mientras se escribe en el buscador.
    readonly property int gridColumns: Math.max(1, Math.min(4, Math.ceil(Math.sqrt(root.count))))
    readonly property int gridRowsAll: Math.max(1, Math.ceil(root.count / gridColumns))

    // Selección por topic: sobrevive al filtrado y a reordenados del roster.
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
        return null; // el seleccionado ya no está en el roster
    }

    function selectedCell() {
        for (let i = 0; i < shownRoster.length; ++i) {
            if (String(shownRoster[i].topic || "").trim() === selectedTopic) {
                return repeater.itemAt(i); // puede ser null: siempre con guard
            }
        }
        return null; // seleccionado pero filtrado: sin feedback visible
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

    // Al abrir el popup: limpiar búsqueda y selección (observador de propiedad:
    // Connections sobre Plasmoid no resuelve expandedChanged en Plasma 5).
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
                placeholderText: "Buscar compañero…"
                // Se re-evalúa en cada apertura → el buscador recibe el foco
                focus: Plasmoid.expanded
                onAccepted: {
                    // Enter con un único resultado: seleccionarlo y pasar al mensaje
                    if (fullRep.shownRoster.length === 1) {
                        fullRep.selectedTopic = String(fullRep.shownRoster[0].topic || "").trim();
                        messageField.forceActiveFocus();
                    }
                }
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

        PlasmaComponents3.ScrollView {
            id: scroll

            anchors.fill: parent
            visible: fullRep.shownRoster.length > 0
            contentWidth: availableWidth // solo scroll vertical

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
            visible: root.count === 0
            iconName: "dialog-messages"
            text: "No hay compañeros configurados ni detectados en la red local"
            helpfulAction: QQC2.Action {
                icon.name: "configure"
                text: "Configurar…"
                onTriggered: Plasmoid.action("configure").trigger()
            }
        }

        PlasmaExtras.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - PlasmaCore.Units.gridUnit * 2
            visible: root.count > 0 && fullRep.shownRoster.length === 0
            iconName: "edit-none"
            text: "Sin resultados"
        }
    }

    footer: PlasmaExtras.PlasmoidHeading {
        contentItem: ColumnLayout {
            spacing: PlasmaCore.Units.smallSpacing

            PlasmaComponents3.TextField {
                id: messageField

                Layout.fillWidth: true
                placeholderText: "Mensaje (opcional, para \"Enviar mensaje\")"
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
                        } else if (fullRep.selectedCoworker) {
                            // seleccionado pero filtrado de la vista: enviar sin feedback de celda
                            root.requestPresence(fullRep.selectedCoworker, dummyCell);
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

    // Receptor de callbacks cuando la celda seleccionada está filtrada de la
    // vista: implementa la misma interfaz mínima que PersonCell.
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
