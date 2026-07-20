/*
    kde-tags — solicita presencia o envía mensajes a compañeros vía ntfy.
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: root

    readonly property var coworkers: {
        try {
            const parsed = JSON.parse(Plasmoid.configuration.coworkers);
            return Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            return [];
        }
    }
    readonly property int count: coworkers.length

    Plasmoid.switchWidth: PlasmaCore.Units.gridUnit * 12
    Plasmoid.switchHeight: PlasmaCore.Units.gridUnit * 10
    Plasmoid.icon: "dialog-messages"
    Plasmoid.toolTipMainText: "kde-tags"
    Plasmoid.toolTipSubText: count === 0
        ? "Configúrame"
        : (count === 1 ? "1 compañero" : count + " compañeros")

    function senderName() {
        return String(Plasmoid.configuration.senderName || "").trim() || "Un compañero";
    }

    // ntfy lee las cabeceras como latin-1: títulos/tags solo ASCII,
    // el texto con UTF-8 (nombres, acentos) viaja en el cuerpo.
    function sendNtfy(topic, title, tags, priority, body, cell, onDone) {
        if (cell.callState === "sending") {
            return;
        }
        const base = String(Plasmoid.configuration.serverUrl || "https://ntfy.sh").replace(/\/+$/, "");
        const cleanTopic = String(topic || "").trim();
        if (cleanTopic === "") {
            cell.beginCall(null);
            cell.finishCall(false);
            if (onDone) {
                onDone(false);
            }
            return;
        }
        const xhr = new XMLHttpRequest();
        xhr.open("POST", base + "/" + encodeURIComponent(cleanTopic));
        xhr.setRequestHeader("X-Title", title);
        xhr.setRequestHeader("X-Tags", tags);
        if (priority !== "") {
            xhr.setRequestHeader("X-Priority", priority);
        }
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            // fallo de red/abort = status 0
            const ok = xhr.status >= 200 && xhr.status < 300;
            cell.finishCall(ok);
            if (onDone) {
                onDone(ok);
            }
        };
        cell.beginCall(xhr);
        try {
            xhr.send(body);
        } catch (e) {
            cell.finishCall(false);
            if (onDone) {
                onDone(false);
            }
        }
    }

    function requestPresence(coworker, cell, onDone) {
        sendNtfy(coworker.topic, "Solicitud de presencia", "wave", "high",
                 senderName() + " solicita tu presencia en su escritorio", cell, onDone);
    }

    function sendMessage(coworker, text, cell, onDone) {
        sendNtfy(coworker.topic, "Mensaje nuevo", "speech_balloon", "",
                 senderName() + ": " + text, cell, onDone);
    }

    Plasmoid.compactRepresentation: CompactRepresentation { }
    Plasmoid.fullRepresentation: FullRepresentation { }
}
