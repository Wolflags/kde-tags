#!/usr/bin/env bash
# Installs the kde-tags notification receiver (ntfy -> notify-send) for the
# current user, and optionally announces it over mDNS on the local network so
# you automatically show up in your coworkers' widgets.
# Usage: ./install-receiver.sh [--topic TOPIC] [--server URL] [--name NAME] [--no-announce]
#        (server, topic and announce default automatically; only the display name
#         prompts when interactive; also honors KDE_TAGS_TOPIC / KDE_TAGS_SERVER /
#         KDE_TAGS_NAME / KDE_TAGS_ANNOUNCE=no)
set -euo pipefail

# System login name (e.g. josej): announced over mDNS and shown on hover so a
# free-text display name can't be used to impersonate someone. Ensure it is set
# (topic and the announcement instance also rely on $USER).
USER="${USER:-$(id -un)}"

BIN_DIR="$HOME/.local/bin"
CONF_DIR="$HOME/.config/kde-tags"
UNIT_DIR="$HOME/.config/systemd/user"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SERVER="${KDE_TAGS_SERVER:-}"
TOPIC="${KDE_TAGS_TOPIC:-}"
NAME="${KDE_TAGS_NAME:-}"
ANNOUNCE="${KDE_TAGS_ANNOUNCE:-}"
while [ $# -gt 0 ]; do
    case "$1" in
        --topic)       TOPIC="$2"; shift 2 ;;
        --server)      SERVER="$2"; shift 2 ;;
        --name)        NAME="$2"; shift 2 ;;
        --no-announce) ANNOUNCE="no"; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Escape a value for use as a sed s|...|...| replacement
sed_escape() {
    printf '%s' "$1" | sed -e 's/[&\\|]/\\&/g'
}

echo "== kde-tags: receiver installation =="

# 1. ntfy binary: system one, previously downloaded one, or download the static binary.
if command -v ntfy >/dev/null 2>&1; then
    NTFY_BIN="$(command -v ntfy)"
elif [ -x "$BIN_DIR/ntfy" ]; then
    NTFY_BIN="$BIN_DIR/ntfy"
else
    mkdir -p "$BIN_DIR"
    case "$(uname -m)" in
        x86_64)  ARCH=amd64 ;;
        aarch64) ARCH=arm64 ;;
        armv7l)  ARCH=armv7 ;;
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
    esac
    TAG="$(curl -fsSL https://api.github.com/repos/binwiederhier/ntfy/releases/latest 2>/dev/null \
        | grep -om1 '"tag_name": *"[^"]*"' | cut -d'"' -f4 || true)"
    TAG="${TAG:-v2.11.0}"
    VER="${TAG#v}"
    URL="https://github.com/binwiederhier/ntfy/releases/download/${TAG}/ntfy_${VER}_linux_${ARCH}.tar.gz"
    echo "Downloading ntfy ${TAG} (${ARCH})..."
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    curl -fsSL "$URL" -o "$TMP/ntfy.tar.gz"
    tar -xzf "$TMP/ntfy.tar.gz" -C "$TMP"
    install -m 755 "$TMP/ntfy_${VER}_linux_${ARCH}/ntfy" "$BIN_DIR/ntfy"
    NTFY_BIN="$BIN_DIR/ntfy"
fi
echo "ntfy: $NTFY_BIN"

# 2. Migration/re-run: recover the topic from a previous kde-tags install or
#    from older versions (d8tags, Team Call), and shut down old services.
OLD_TOPIC=""
for OLDCONF in "$CONF_DIR/client.yml" "$HOME/.config/d8tags/client.yml" "$HOME/.config/teamcall/client.yml"; do
    if [ -z "$OLD_TOPIC" ] && [ -f "$OLDCONF" ]; then
        OLD_TOPIC="$(awk '/- topic:/{print $3; exit}' "$OLDCONF" || true)"
    fi
done
for OLDUNIT in d8tags-receiver teamcall-receiver; do
    if [ -f "$UNIT_DIR/$OLDUNIT.service" ]; then
        systemctl --user disable --now "$OLDUNIT.service" 2>/dev/null || true
        rm -f "$UNIT_DIR/$OLDUNIT.service"
        echo "Old service $OLDUNIT disabled."
    fi
done

# 3. Server and personal topic — resolved automatically, no prompts. Override
#    with --server/--topic or KDE_TAGS_SERVER/KDE_TAGS_TOPIC if you need to.
SERVER="${SERVER:-https://ntfy.sh}"
if [ -z "$TOPIC" ]; then
    if [ -n "$OLD_TOPIC" ]; then
        TOPIC="$OLD_TOPIC"
        echo "Reusing existing topic: $TOPIC"
    else
        # head first and no trailing pipe: avoids the SIGPIPE that would
        # abort the script under pipefail
        RAND="$(head -c 256 /dev/urandom | tr -dc 'a-z0-9')"
        TOPIC="kde-tags-$USER-${RAND:0:10}"
        echo "Generated topic: $TOPIC"
    fi
fi

# 4. ntfy client configuration.
mkdir -p "$CONF_DIR"
cat > "$CONF_DIR/client.yml" <<EOF
default-host: $SERVER
subscribe:
  - topic: $TOPIC
    command: $BIN_DIR/kde-tags-notify.sh
EOF

# 5. Notification helper.
mkdir -p "$BIN_DIR"
install -m 755 "$SCRIPT_DIR/kde-tags-notify.sh" "$BIN_DIR/kde-tags-notify.sh"

# 6. systemd user service.
mkdir -p "$UNIT_DIR"
sed "s|@NTFY_BIN@|$NTFY_BIN|g" "$SCRIPT_DIR/kde-tags-receiver.service" \
    > "$UNIT_DIR/kde-tags-receiver.service"
systemctl --user daemon-reload
# enable + restart (not `enable --now`): restart re-reads the unit so re-running
# the installer actually applies changes to an already-running service.
systemctl --user enable kde-tags-receiver.service
systemctl --user restart kde-tags-receiver.service

# 7. Self-test: the notification should show up within a few seconds.
sleep 2
echo "Sending test notification..."
curl -fsS -d "If you can see this, the receiver works" \
    -H "X-Title: kde-tags ready" -H "X-Tags: wave" "$SERVER/$TOPIC" >/dev/null

# 8. Resolve the display name (used both as the widget's sender name and for the
#    mDNS announcement) and save it so the widget can adopt it automatically.
if [ -z "$NAME" ] && [ -t 0 ]; then
    read -rp "Your display name [$USER]: " NAME || true
fi
NAME="${NAME:-$USER}"
# Sanitize: no double quotes/backslashes/semicolons (they would break the unit
# or the avahi-browse output format) and no control characters.
NAME="$(printf '%s' "$NAME" | tr -d '"\\;' | tr -d '\n\r\t')"
printf '%s' "$NAME" > "$CONF_DIR/name"

# 9. mDNS announcement: on by default (no prompt) so you show up automatically in
#    widgets on the local network. Opt out with --no-announce / KDE_TAGS_ANNOUNCE=no.
ANNOUNCE="${ANNOUNCE:-yes}"

if [ "$ANNOUNCE" = "no" ]; then
    # Idempotent: turn off a previous announcement if there was one.
    systemctl --user disable --now kde-tags-announce.service 2>/dev/null || true
    rm -f "$UNIT_DIR/kde-tags-announce.service"
    systemctl --user daemon-reload
    echo "mDNS announcement disabled (--no-announce)."
elif ! command -v avahi-publish >/dev/null 2>&1; then
    echo "WARNING: avahi-publish is missing (avahi-utils package); not announcing on the LAN." >&2
    echo "         Install it with:  sudo apt install avahi-utils   and re-run this installer." >&2
elif ! systemctl is-active --quiet avahi-daemon 2>/dev/null; then
    echo "WARNING: avahi-daemon is not active; cannot announce on the LAN." >&2
else
    # $NAME is already resolved and sanitized above (step 8).
    # systemd escaping: % and $ are special in ExecStart.
    NAME_UNIT="${NAME//%/%%}"
    NAME_UNIT="${NAME_UNIT//\$/\$\$}"
    USER_UNIT="${USER//%/%%}"
    USER_UNIT="${USER_UNIT//\$/\$\$}"
    INSTANCE="kde-tags $USER@$(hostname -s)"
    sed -e "s|@AVAHI_PUBLISH@|$(sed_escape "$(command -v avahi-publish)")|g" \
        -e "s|@INSTANCE@|$(sed_escape "$INSTANCE")|g" \
        -e "s|@NAME@|$(sed_escape "$NAME_UNIT")|g" \
        -e "s|@TOPIC@|$(sed_escape "$TOPIC")|g" \
        -e "s|@SERVER@|$(sed_escape "$SERVER")|g" \
        -e "s|@USER@|$(sed_escape "$USER_UNIT")|g" \
        "$SCRIPT_DIR/kde-tags-announce.service" > "$UNIT_DIR/kde-tags-announce.service"
    systemctl --user daemon-reload
    # enable + restart so a changed announcement (e.g. new TXT fields) takes
    # effect when re-running the installer, not just on first install.
    systemctl --user enable kde-tags-announce.service
    systemctl --user restart kde-tags-announce.service
    echo "Announcing you on the local network as \"$NAME\" (kde-tags-announce service)."
fi

echo
echo "== Done =="
echo "Share this topic with anyone who should be able to reach you:"
echo "    $TOPIC"
echo "(server: $SERVER)"
echo "In the sender's widget: Name = your name, Topic = $TOPIC"
echo "(if you are both on the same local network with the mDNS announcement on,"
echo " you will show up in their widget automatically, no manual entry needed)"
echo "Service status:"
echo "  systemctl --user status kde-tags-receiver.service"
echo "  systemctl --user status kde-tags-announce.service"
if [ -d "$HOME/.config/teamcall" ] || [ -f "$BIN_DIR/teamcall-notify.sh" ] \
   || [ -d "$HOME/.config/d8tags" ] || [ -f "$BIN_DIR/d8tags-notify.sh" ]; then
    echo
    echo "Leftovers from previous versions (Team Call / d8tags); remove them with:"
    echo "  rm -rf ~/.config/teamcall ~/.config/d8tags \\"
    echo "         ~/.local/bin/teamcall-notify.sh ~/.local/bin/d8tags-notify.sh"
fi
