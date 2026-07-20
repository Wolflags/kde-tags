#!/usr/bin/env bash
# Instala el receptor de avisos kde-tags (ntfy -> notify-send) para el usuario
# actual, y opcionalmente lo anuncia por mDNS en la red local para aparecer
# automáticamente en los widgets de los compañeros.
# Uso: ./install-receiver.sh [--topic TOPIC] [--server URL] [--name NOMBRE] [--no-announce]
#      (sin flags es interactivo; también acepta KDE_TAGS_TOPIC / KDE_TAGS_SERVER /
#       KDE_TAGS_NAME / KDE_TAGS_ANNOUNCE=no)
set -euo pipefail

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
        *) echo "Opción desconocida: $1" >&2; exit 1 ;;
    esac
done

# Escapa un valor para usarlo como reemplazo en sed s|...|...|
sed_escape() {
    printf '%s' "$1" | sed -e 's/[&\\|]/\\&/g'
}

echo "== kde-tags: instalación del receptor =="

# 1. Binario ntfy: el del sistema, el ya descargado, o descarga del binario estático.
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
        *) echo "Arquitectura no soportada: $(uname -m)" >&2; exit 1 ;;
    esac
    TAG="$(curl -fsSL https://api.github.com/repos/binwiederhier/ntfy/releases/latest 2>/dev/null \
        | grep -om1 '"tag_name": *"[^"]*"' | cut -d'"' -f4 || true)"
    TAG="${TAG:-v2.11.0}"
    VER="${TAG#v}"
    URL="https://github.com/binwiederhier/ntfy/releases/download/${TAG}/ntfy_${VER}_linux_${ARCH}.tar.gz"
    echo "Descargando ntfy ${TAG} (${ARCH})..."
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    curl -fsSL "$URL" -o "$TMP/ntfy.tar.gz"
    tar -xzf "$TMP/ntfy.tar.gz" -C "$TMP"
    install -m 755 "$TMP/ntfy_${VER}_linux_${ARCH}/ntfy" "$BIN_DIR/ntfy"
    NTFY_BIN="$BIN_DIR/ntfy"
fi
echo "ntfy: $NTFY_BIN"

# 2. Migración/re-ejecución: recuperar el topic de una instalación kde-tags
#    previa o de versiones anteriores (d8tags, Team Call), y apagar servicios viejos.
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
        echo "Servicio antiguo $OLDUNIT desactivado."
    fi
done

# 3. Servidor y topic personal.
if [ -z "$SERVER" ]; then
    read -rp "Servidor ntfy [https://ntfy.sh]: " SERVER
    SERVER="${SERVER:-https://ntfy.sh}"
fi
if [ -z "$TOPIC" ]; then
    if [ -n "$OLD_TOPIC" ]; then
        read -rp "Tu topic personal [$OLD_TOPIC]: " TOPIC
        TOPIC="${TOPIC:-$OLD_TOPIC}"
    else
        read -rp "Tu topic personal (vacío = generar uno aleatorio): " TOPIC
        if [ -z "$TOPIC" ]; then
            # head primero y sin pipe final: evita el SIGPIPE que abortaría con pipefail
            RAND="$(head -c 256 /dev/urandom | tr -dc 'a-z0-9')"
            TOPIC="kde-tags-$USER-${RAND:0:10}"
            echo "Topic generado: $TOPIC"
        fi
    fi
fi

# 4. Configuración del cliente ntfy.
mkdir -p "$CONF_DIR"
cat > "$CONF_DIR/client.yml" <<EOF
default-host: $SERVER
subscribe:
  - topic: $TOPIC
    command: $BIN_DIR/kde-tags-notify.sh
EOF

# 5. Helper de notificación.
mkdir -p "$BIN_DIR"
install -m 755 "$SCRIPT_DIR/kde-tags-notify.sh" "$BIN_DIR/kde-tags-notify.sh"

# 6. Servicio systemd de usuario.
mkdir -p "$UNIT_DIR"
sed "s|@NTFY_BIN@|$NTFY_BIN|g" "$SCRIPT_DIR/kde-tags-receiver.service" \
    > "$UNIT_DIR/kde-tags-receiver.service"
systemctl --user daemon-reload
systemctl --user enable --now kde-tags-receiver.service

# 7. Auto-test: la notificación debería aparecer en unos segundos.
sleep 2
echo "Enviando aviso de prueba..."
curl -fsS -d "Si ves este aviso, el receptor funciona" \
    -H "X-Title: kde-tags listo" -H "X-Tags: wave" "$SERVER/$TOPIC" >/dev/null

# 8. Anuncio mDNS: aparecer automáticamente en los widgets de la red local.
if [ -z "$ANNOUNCE" ] && [ -t 0 ]; then
    read -rp "¿Anunciarte en la red local para aparecer automáticamente en los widgets? [S/n]: " R
    case "$R" in
        [nN]*) ANNOUNCE=no ;;
        *)     ANNOUNCE=yes ;;
    esac
fi
ANNOUNCE="${ANNOUNCE:-yes}"

if [ "$ANNOUNCE" = "no" ]; then
    # Idempotente: si había un anuncio previo, se apaga.
    systemctl --user disable --now kde-tags-announce.service 2>/dev/null || true
    rm -f "$UNIT_DIR/kde-tags-announce.service"
    systemctl --user daemon-reload
    echo "Anuncio mDNS desactivado (--no-announce)."
elif ! command -v avahi-publish >/dev/null 2>&1; then
    echo "AVISO: falta avahi-publish (paquete avahi-utils); no se anunciará en la LAN." >&2
    echo "       Instálalo con:  sudo apt install avahi-utils   y re-ejecuta este instalador." >&2
elif ! systemctl is-active --quiet avahi-daemon 2>/dev/null; then
    echo "AVISO: avahi-daemon no está activo; no se puede anunciar en la LAN." >&2
else
    if [ -z "$NAME" ] && [ -t 0 ]; then
        read -rp "Tu nombre visible en los widgets [$USER]: " NAME
    fi
    NAME="${NAME:-$USER}"
    # Sanitizar: sin comillas dobles/backslash/punto y coma (romperían la unit o
    # el formato de avahi-browse) ni caracteres de control.
    NAME="$(printf '%s' "$NAME" | tr -d '"\\;' | tr -d '\n\r\t')"
    # Escapado systemd: % y $ tienen significado especial en ExecStart.
    NAME_UNIT="${NAME//%/%%}"
    NAME_UNIT="${NAME_UNIT//\$/\$\$}"
    INSTANCE="kde-tags $USER@$(hostname -s)"
    sed -e "s|@AVAHI_PUBLISH@|$(sed_escape "$(command -v avahi-publish)")|g" \
        -e "s|@INSTANCE@|$(sed_escape "$INSTANCE")|g" \
        -e "s|@NAME@|$(sed_escape "$NAME_UNIT")|g" \
        -e "s|@TOPIC@|$(sed_escape "$TOPIC")|g" \
        -e "s|@SERVER@|$(sed_escape "$SERVER")|g" \
        "$SCRIPT_DIR/kde-tags-announce.service" > "$UNIT_DIR/kde-tags-announce.service"
    systemctl --user daemon-reload
    systemctl --user enable --now kde-tags-announce.service
    echo "Anunciándote en la red local como \"$NAME\" (servicio kde-tags-announce)."
fi

echo
echo "== Listo =="
echo "Comparte este topic con quien deba poder avisarte:"
echo "    $TOPIC"
echo "(servidor: $SERVER)"
echo "En el widget de quien avisa: Nombre = tu nombre, Topic = $TOPIC"
echo "(si ambos están en la misma red local con el anuncio mDNS activo,"
echo " aparecerás automáticamente en su widget sin que te añada a mano)"
echo "Estado de los servicios:"
echo "  systemctl --user status kde-tags-receiver.service"
echo "  systemctl --user status kde-tags-announce.service"
if [ -d "$HOME/.config/teamcall" ] || [ -f "$BIN_DIR/teamcall-notify.sh" ] \
   || [ -d "$HOME/.config/d8tags" ] || [ -f "$BIN_DIR/d8tags-notify.sh" ]; then
    echo
    echo "Restos de versiones anteriores (Team Call / d8tags); puedes borrarlos con:"
    echo "  rm -rf ~/.config/teamcall ~/.config/d8tags \\"
    echo "         ~/.local/bin/teamcall-notify.sh ~/.local/bin/d8tags-notify.sh"
fi
