/*
    Icono del panel: alterna el popup al hacer clic.
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

MouseArea {
    id: compactRoot

    // Capturado en onPressed: el popup se auto-cierra al perder el foco,
    // así el clic con popup abierto lo cierra en vez de reabrirlo.
    property bool wasExpanded: false

    anchors.fill: parent
    hoverEnabled: true
    activeFocusOnTab: true
    Accessible.name: "kde-tags"
    Accessible.role: Accessible.Button

    onPressed: wasExpanded = Plasmoid.expanded
    onClicked: Plasmoid.expanded = !wasExpanded

    PlasmaCore.IconItem {
        anchors.fill: parent
        source: Plasmoid.icon
        active: compactRoot.containsMouse
    }
}
