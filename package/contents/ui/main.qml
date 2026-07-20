/*
    kde-tags — request a coworker's presence or send them messages via ntfy.
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

    // Coworkers announced via mDNS on the local network (filled by discoverySource).
    property var discovered: []

    // Final list: manual entries first; on duplicate topics the manual entry
    // wins (lets you rename a discovered coworker).
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
        ? "Configure me"
        : (count === 1 ? "1 coworker" : count + " coworkers")

    function senderName() {
        return String(Plasmoid.configuration.senderName || "").trim() || "A coworker";
    }

    // ntfy reads headers as latin-1: titles/tags must stay ASCII, while
    // UTF-8 text (names, accents) travels in the body.
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
            // network failure/abort = status 0
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
        sendNtfy(coworker.topic, "Presence request", "wave", "high",
                 senderName() + " is requesting your presence at their desk", cell, onDone);
    }

    function sendMessage(coworker, text, cell, onDone) {
        sendNtfy(coworker.topic, "New message", "speech_balloon", "",
                 senderName() + ": " + text, cell, onDone);
    }

    // --- mDNS (Avahi) discovery on the local network ---

    // One round-trip: first line = own topic (to exclude yourself), rest =
    // one-shot avahi-browse dump. exit 127 = avahi-browse not installed.
    readonly property string discoverCmd:
        "echo \"SELF:$(awk '/- topic:/{print $3; exit}' \"$HOME/.config/kde-tags/client.yml\" 2>/dev/null)\"; "
        + "avahi-browse -rtp _kdetags._tcp 2>/dev/null"

    PlasmaCore.DataSource {
        id: discoverySource

        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName); // required to be able to re-run the same command
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
            return; // a scan is already running
        }
        discoverySource.connectSource(discoverCmd);
    }

    // avahi-browse -p escapes non-ASCII bytes as \nnn (decimal) even inside
    // TXT records ("ó" arrives as \195\179): rebuild the bytes and decode UTF-8.
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
            return s; // malformed sequence: raw text is better than nothing
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
            // TXT (field 9 onwards) may contain ';': re-join and extract the
            // quoted "key=value" pairs with a regex, never a naive split.
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
                continue; // no topic, self, or IPv4/IPv6/interface duplicate
            }
            found[topic] = {
                name: String(kv.name || "").trim() || topic,
                topic: topic,
                discovered: true
            };
        }
        const list = Object.keys(found).map(function (t) { return found[t]; })
            .sort(function (a, b) { return a.name.localeCompare(b.name); });
        // No real changes => leave the list alone (avoids resetting the selection).
        if (JSON.stringify(list) !== JSON.stringify(discovered)) {
            discovered = list;
        }
    }

    // Property observers (Connections on Plasmoid/configuration cannot
    // resolve these signals in Plasma 5).
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
