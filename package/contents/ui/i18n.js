/*
    Shared translation dictionary for kde-tags (English / Spanish).
    SPDX-License-Identifier: GPL-2.0-or-later

    Use %1 as a positional placeholder; substitute it at the call site.
*/
.pragma library

var M = {
    // Applet tooltip
    "tooltip.configure":    { en: "Configure me",             es: "Configúrame" },
    "tooltip.one":          { en: "1 coworker",               es: "1 compañero" },
    "tooltip.many":         { en: "%1 coworkers",             es: "%1 compañeros" },
    "tooltip.offline":      { en: "Offline",                  es: "Sin conexión" },

    // Offline mode
    "popup.goOffline":      { en: "Go offline",               es: "Ponerse offline" },
    "popup.goOnline":       { en: "Go online",                es: "Volver a online" },
    "popup.offlineTitle":   { en: "You're offline",           es: "Estás offline" },
    "popup.offlineHelp":    { en: "Not announced on the network and not receiving notifications. Your coworkers can't see you.",
                              es: "No te anuncias en la red ni recibes notificaciones. Tus compañeros no te ven." },

    // Notification content. The title is the sender's name (goes via the ntfy
    // ?title= query param, so UTF-8 is fine); this is only the presence body.
    "notif.sender":         { en: "A coworker",               es: "Un compañero" },
    "notif.presenceBody":   { en: "Requests your presence at their desk",
                              es: "Solicita tu presencia en su escritorio" },

    // Popup
    "popup.search":         { en: "Search coworker…",         es: "Buscar compañero…" },
    "popup.configure":      { en: "Configure…",               es: "Configurar…" },
    "popup.empty":          { en: "No coworkers configured or detected on the local network",
                              es: "No hay compañeros configurados ni detectados en la red local" },
    "popup.noMatches":      { en: "No matches",               es: "Sin resultados" },
    "popup.message":        { en: "Message (optional, for \"Send message\")",
                              es: "Mensaje (opcional, para \"Enviar mensaje\")" },
    "popup.requestPresence":{ en: "Request presence",         es: "Solicitar presencia" },
    "popup.sendMessage":    { en: "Send message",             es: "Enviar mensaje" },

    // Coworker cell
    "cell.systemUser":      { en: "System user: %1",          es: "Usuario del sistema: %1" },
    "cell.couldNotSend":    { en: "Could not send",           es: "No se pudo enviar" },
    "cell.detected":        { en: "Detected on local network · ",
                              es: "Detectado en la red local · " },
    "cell.selected":        { en: "Selected",                 es: "Seleccionado" },
    "cell.clickToSelect":   { en: "Click to select",          es: "Clic para seleccionar" },
    "cell.select":          { en: "Select %1",                es: "Seleccionar a %1" },

    // Settings page
    "cfg.language":         { en: "Language:",                es: "Idioma:" },
    "cfg.systemUser":       { en: "System user:",             es: "Usuario del sistema:" },
    "cfg.server":           { en: "ntfy server:",             es: "Servidor ntfy:" },
    "cfg.yourName":         { en: "Your name:",               es: "Tu nombre:" },
    "cfg.yourNamePlaceholder": { en: "How your coworkers will see you",
                              es: "Cómo te verán tus compañeros" },
    "cfg.localNetwork":     { en: "Local network:",           es: "Red local:" },
    "cfg.discover":         { en: "Discover coworkers automatically (mDNS)",
                              es: "Descubrir compañeros automáticamente (mDNS)" },
    "cfg.coworkers":        { en: "Coworkers",                es: "Compañeros" },
    "cfg.topicHelp":        { en: "Where does the topic come from? Each coworker runs the receiver installer "
                                + "(the project's receiver/ folder: ./install-receiver.sh) on their PC. When it "
                                + "finishes, the script prints their personal topic (e.g. kde-tags-ana-x7k2m9q4pz): "
                                + "ask them for it and paste it here next to their name. They can also pick their "
                                + "own by running ./install-receiver.sh --topic whatever-they-want. With local "
                                + "network discovery enabled, anyone who installs the receiver on your network "
                                + "shows up in the widget automatically (this manual list is for people outside "
                                + "the LAN, or to rename a discovered coworker by adding them with the same topic).",
                              es: "¿De dónde sale el topic? Cada compañero ejecuta el instalador del receptor "
                                + "(carpeta receiver/ del proyecto: ./install-receiver.sh) en su PC. Al terminar, "
                                + "el script imprime su topic personal (p. ej. kde-tags-ana-x7k2m9q4pz): pídeselo y "
                                + "pégalo aquí junto a su nombre. También puede elegir uno propio ejecutando "
                                + "./install-receiver.sh --topic el-topic-que-quiera. Con el descubrimiento en red "
                                + "local activado, quienes instalen el receptor en tu misma red aparecen solos en el "
                                + "widget (esta lista manual sirve para gente fuera de la LAN, o para renombrar a "
                                + "alguien descubierto añadiéndolo con el mismo topic)." },
    "cfg.name":             { en: "Name",                     es: "Nombre" },
    "cfg.topic":            { en: "ntfy topic",               es: "Topic de ntfy" },
    "cfg.topicPlaceholder": { en: "ntfy topic (e.g. kde-tags-ana-x7k2m9q4pz)",
                              es: "Topic de ntfy (p. ej. kde-tags-ana-x7k2m9q4pz)" },
    "cfg.add":              { en: "Add",                      es: "Añadir" },
    "cfg.remove":           { en: "Remove",                   es: "Eliminar" },
    "cfg.privacy":          { en: "The topic works like a password: anyone who knows it can send and read "
                                + "notifications. Use randomly-suffixed topics (the installer generates them that "
                                + "way) and share them only within your team.",
                              es: "El topic funciona como una contraseña: cualquiera que lo conozca puede enviar y "
                                + "leer avisos. Usa topics con sufijo aleatorio (el instalador los genera así) y "
                                + "compártelos solo con el equipo." }
};

// Return the string for `key` in `lang`, falling back to English, then to the key itself.
function t(lang, key) {
    var entry = M[key];
    if (!entry) {
        return key;
    }
    return entry[lang] !== undefined ? entry[lang] : entry.en;
}
