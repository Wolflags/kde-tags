#!/bin/sh
# Invoked by `ntfy subscribe` for every received notification.
# ntfy exports NTFY_TITLE, NTFY_MESSAGE, NTFY_PRIORITY, NTFY_TAGS, etc.

# ntfy priority >= 4 (presence requests) => persistent notification.
if [ "${NTFY_PRIORITY:-3}" -ge 4 ] 2>/dev/null; then
    URGENCY=critical
else
    URGENCY=normal
fi

# The ntfy CLI delivers tags without converting them to emoji; do it here.
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
