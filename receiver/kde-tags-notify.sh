#!/bin/sh
# Lo invoca `ntfy subscribe` en cada aviso recibido.
# ntfy exporta NTFY_TITLE, NTFY_MESSAGE, NTFY_PRIORITY, NTFY_TAGS, etc.

# Prioridad ntfy >= 4 (solicitudes de presencia) => notificación persistente.
if [ "${NTFY_PRIORITY:-3}" -ge 4 ] 2>/dev/null; then
    URGENCY=critical
else
    URGENCY=normal
fi

# El CLI de ntfy entrega los tags sin convertir a emoji; se hace aquí.
case "${NTFY_TAGS:-}" in
    *wave*)           PREFIX="👋 " ;;
    *speech_balloon*) PREFIX="💬 " ;;
    *)                PREFIX="" ;;
esac

notify-send -u "$URGENCY" -a "kde-tags" -i im-user \
    "${PREFIX}${NTFY_TITLE:-kde-tags}" "${NTFY_MESSAGE:-}"

if command -v paplay >/dev/null 2>&1; then
    for f in /usr/share/sounds/freedesktop/stereo/message-new-instant.oga \
             /usr/share/sounds/freedesktop/stereo/bell.oga; do
        if [ -f "$f" ]; then
            paplay "$f" 2>/dev/null &
            break
        fi
    done
fi
