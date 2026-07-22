/*
    Panel icon: toggles the popup on click.
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

MouseArea {
    id: compactRoot

    // Captured in onPressed: the popup auto-closes when it loses focus, so a
    // click while it is open should close it instead of reopening it.
    property bool wasExpanded: false

    anchors.fill: parent
    hoverEnabled: true
    activeFocusOnTab: true
    Accessible.name: "kde-tags"
    Accessible.description: root.tr("tooltip.configure")
    Accessible.role: Accessible.Button

    onPressed: wasExpanded = Plasmoid.expanded
    onClicked: Plasmoid.expanded = !wasExpanded

    PlasmaCore.IconItem {
        id: icon
        anchors.fill: parent
        source: Plasmoid.icon
        active: compactRoot.containsMouse
        // Dimmed when offline.
        opacity: root.offline ? 0.5 : 1.0
    }

    // Offline badge: a small grey "user-offline" mark in the corner.
    PlasmaCore.IconItem {
        visible: root.offline
        source: "user-offline"
        width: Math.round(parent.width * 0.5)
        height: width
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }
}
