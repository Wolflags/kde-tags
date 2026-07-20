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

    // Compañeros anunciados por mDNS en la red local (rellenado por discoverySource).
    property var discovered: []

    // Lista final: manuales primero; ante topic duplicado gana la entrada manual
    // (permite renombrar a alguien descubierto).
    readonly property var roster: {
        const seen = {};
        const out = [];
        for (let i = 0; i < coworkers.length; ++i) {
            out.push(coworkers[i]);
            seen[String(coworkers[i].topic || "").trim()] = true;
        }
        for (let j = 0; j < discovered.length; ++j) {
            if (!seen[discovered[j].topic]) {
                out.push(discovered[j]);
            }
        }
        return out;
    }
    readonly property int count: roster.length

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

    // --- Descubrimiento mDNS (Avahi) en la red local ---

    // Un solo viaje: primera línea = topic propio (para excluirse), resto =
    // volcado one-shot de avahi-browse. exit 127 = avahi-browse no instalado.
    readonly property string discoverCmd:
        "echo \"SELF:$(awk '/- topic:/{print $3; exit}' \"$HOME/.config/kde-tags/client.yml\" 2>/dev/null)\"; "
        + "avahi-browse -rtp _kdetags._tcp 2>/dev/null"

    PlasmaCore.DataSource {
        id: discoverySource

        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName); // imprescindible para poder relanzar el mismo comando
            if (data["exit code"] === 127) {
                root.discovered = [];
                return;
            }
            root.applyDiscovery(String(data["stdout"] || ""));
        }
    }

    function discoverNow() {
        if (Plasmoid.configuration.lanDiscovery !== true) {
            return;
        }
        if (discoverySource.connectedSources.length > 0) {
            return; // ya hay un escaneo en marcha
        }
        discoverySource.connectSource(discoverCmd);
    }

    // avahi-browse -p escapa los bytes no-ASCII como \nnn (decimal) incluso
    // dentro del TXT ("ó" llega como \195\179): reconstruir y decodificar UTF-8.
    function unescapeAvahi(s) {
        let pct = "";
        for (let i = 0; i < s.length; ++i) {
            const c = s.charAt(i);
            if (c === "\\" && /^[0-9]{3}$/.test(s.substr(i + 1, 3))) {
                pct += "%" + ("0" + parseInt(s.substr(i + 1, 3), 10).toString(16)).slice(-2);
                i += 3;
            } else if (c === "%") {
                pct += "%25";
            } else {
                pct += c;
            }
        }
        try {
            return decodeURIComponent(pct);
        } catch (e) {
            return s; // secuencia malformada: mejor el texto crudo que nada
        }
    }

    function applyDiscovery(out) {
        let self = "";
        const found = {};
        const lines = out.split("\n");
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i];
            if (line.indexOf("SELF:") === 0) {
                self = line.slice(5).trim();
                continue;
            }
            if (line.charAt(0) !== "=") {
                continue;
            }
            const parts = line.split(";");
            if (parts.length < 10) {
                continue;
            }
            // El TXT (campo 9 en adelante) puede contener ';': se re-une y se
            // extraen los pares "clave=valor" entre comillas con regex.
            const txt = parts.slice(9).join(";");
            const kv = {};
            const re = /"([^"]*)"/g;
            let m;
            while ((m = re.exec(txt)) !== null) {
                const eq = m[1].indexOf("=");
                if (eq > 0) {
                    kv[m[1].slice(0, eq)] = unescapeAvahi(m[1].slice(eq + 1));
                }
            }
            const topic = String(kv.topic || "").trim();
            if (topic === "" || topic === self || found[topic]) {
                continue; // sin topic, uno mismo, o duplicado IPv4/IPv6/interfaz
            }
            found[topic] = {
                name: String(kv.name || "").trim() || topic,
                topic: topic,
                discovered: true
            };
        }
        const list = Object.keys(found).map(function (t) { return found[t]; })
            .sort(function (a, b) { return a.name.localeCompare(b.name); });
        // Sin cambios reales => no tocar la lista (evita resetear la selección).
        if (JSON.stringify(list) !== JSON.stringify(discovered)) {
            discovered = list;
        }
    }

    // Observadores de propiedad (Connections sobre Plasmoid/configuration no
    // resuelve estas señales en Plasma 5).
    readonly property bool popupExpanded: Plasmoid.expanded
    onPopupExpandedChanged: {
        if (popupExpanded) {
            discoverNow();
        }
    }

    readonly property bool lanDiscoveryOn: Plasmoid.configuration.lanDiscovery === true
    onLanDiscoveryOnChanged: {
        if (lanDiscoveryOn) {
            discoverNow();
        } else {
            discovered = [];
        }
    }

    Component.onCompleted: discoverNow()

    Plasmoid.compactRepresentation: CompactRepresentation { }
    Plasmoid.fullRepresentation: FullRepresentation { }
}
