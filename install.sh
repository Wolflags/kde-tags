#!/usr/bin/env bash
# kde-tags one-command installer: sets up the widget AND the receiver.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/Wolflags/kde-tags/main/install.sh)
#
# Any extra flags are forwarded to receiver/install-receiver.sh, e.g.
#   bash <(curl -fsSL .../install.sh) --name "Ana" --no-announce
set -euo pipefail

REPO_GIT="https://github.com/Wolflags/kde-tags.git"
REPO_TARBALL="https://codeload.github.com/Wolflags/kde-tags/tar.gz/refs/heads/main"
SRC_HOME="$HOME/.local/share/kde-tags/src"
WIDGET_ID="com.josej.kdetags"

# Make prompts (name/topic, sudo password) work even under `curl ... | bash`.
# Probe whether /dev/tty is actually openable (headless has no controlling
# terminal); only then reattach stdin to it. Silent when there is none.
if [ ! -t 0 ] && { : < /dev/tty; } 2>/dev/null; then
    exec < /dev/tty
fi

echo "== kde-tags installer =="

# --- 1. Locate or fetch the sources ---------------------------------------
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/package/metadata.json" ]; then
    SRC="$SELF_DIR"
    echo "Using local sources: $SRC"
else
    echo "Fetching sources into $SRC_HOME ..."
    if command -v git >/dev/null 2>&1; then
        if [ -d "$SRC_HOME/.git" ]; then
            git -C "$SRC_HOME" pull --ff-only --quiet || true
        else
            rm -rf "$SRC_HOME"
            mkdir -p "$(dirname "$SRC_HOME")"
            git clone --depth 1 "$REPO_GIT" "$SRC_HOME"
        fi
    else
        rm -rf "$SRC_HOME"
        mkdir -p "$SRC_HOME"
        curl -fsSL "$REPO_TARBALL" | tar -xz -C "$SRC_HOME" --strip-components=1
    fi
    SRC="$SRC_HOME"
fi

# --- 2. Require Plasma 5 ----------------------------------------------------
if ! command -v kpackagetool5 >/dev/null 2>&1; then
    echo "kpackagetool5 not found. This widget needs KDE Plasma 5." >&2
    exit 1
fi

# --- 3. Install avahi-utils (LAN discovery) if missing ----------------------
install_avahi() {
    if command -v avahi-browse >/dev/null 2>&1 && command -v avahi-publish >/dev/null 2>&1; then
        return 0
    fi
    local pm pkg
    if   command -v apt-get >/dev/null 2>&1; then pm="apt-get"; pkg="avahi-utils"
    elif command -v dnf     >/dev/null 2>&1; then pm="dnf";     pkg="avahi-tools"
    elif command -v pacman  >/dev/null 2>&1; then pm="pacman";  pkg="avahi"
    elif command -v zypper  >/dev/null 2>&1; then pm="zypper";  pkg="avahi-utils"
    else
        echo "NOTE: could not detect the package manager; install avahi-utils manually" >&2
        echo "      to enable automatic LAN discovery." >&2
        return 0
    fi
    if ! command -v sudo >/dev/null 2>&1; then
        echo "NOTE: sudo not available; skipping avahi-utils. Install it manually for LAN discovery." >&2
        return 0
    fi
    echo "Installing avahi-utils (LAN discovery) via sudo $pm ..."
    case "$pm" in
        apt-get) sudo apt-get update -qq && sudo apt-get install -y avahi-utils || true ;;
        dnf)     sudo dnf install -y avahi-tools || true ;;
        pacman)  sudo pacman -S --needed --noconfirm avahi || true ;;
        zypper)  sudo zypper install -y avahi-utils || true ;;
    esac
    command -v avahi-browse >/dev/null 2>&1 \
        || echo "NOTE: avahi-utils still missing; continuing without LAN discovery." >&2
}
install_avahi

# --- 4. Install / update the widget ----------------------------------------
if kpackagetool5 -t Plasma/Applet -l 2>/dev/null | grep -q "^${WIDGET_ID}\$"; then
    echo "Updating widget ..."
    kpackagetool5 -t Plasma/Applet -u "$SRC/package"
else
    echo "Installing widget ..."
    kpackagetool5 -t Plasma/Applet -i "$SRC/package"
fi
kbuildsycoca5 >/dev/null 2>&1 || true

# --- 5. Install the receiver (idempotent; keeps existing topic) -------------
echo "Setting up the receiver ..."
bash "$SRC/receiver/install-receiver.sh" "$@"

# --- 6. Place the widget on the panel next to the system tray ---------------
restart_plasmashell() {
    systemctl --user restart plasma-plasmashell.service 2>/dev/null \
        || (kquitapp5 plasmashell 2>/dev/null; sleep 1; kstart5 plasmashell >/dev/null 2>&1 &)
}

add_to_panel() {
    command -v qdbus >/dev/null 2>&1 || { restart_plasmashell; return 0; }

    # Add the widget (only if absent) and report containment/new/tray ids.
    local out
    out="$(qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
        var pnls = panels();
        var present = false;
        for (var i = 0; i < pnls.length; ++i) {
            if (pnls[i].widgets("com.josej.kdetags").length > 0) { present = true; }
        }
        if (present) {
            print("PRESENT");
        } else {
            var target = null, trayId = -1, sepId = -1;
            for (var i = 0; i < pnls.length; ++i) {
                var ws = pnls[i].widgetIds;
                for (var j = 0; j < ws.length; ++j) {
                    if (pnls[i].widgetById(ws[j]).type === "org.kde.plasma.systemtray") {
                        target = pnls[i]; trayId = ws[j];
                    }
                }
            }
            if (!target && pnls.length > 0) { target = pnls[0]; }
            if (!target) {
                print("NOPANEL");
            } else {
                // Anchor before the margins separator (keeps the icon at full
                // panel-thickness size), else before the tray.
                var ws = target.widgetIds;
                for (var j = 0; j < ws.length; ++j) {
                    if (target.widgetById(ws[j]).type === "org.kde.plasma.marginsseparator") {
                        sepId = ws[j];
                    }
                }
                var w = target.addWidget("com.josej.kdetags");
                print("CONT=" + target.id + " NEW=" + w.id + " TRAY=" + trayId + " SEP=" + sepId);
            }
        }
    ' 2>/dev/null || true)"

    if printf '%s' "$out" | grep -q "PRESENT"; then
        echo "Widget already on the panel."
        restart_plasmashell
        return 0
    fi

    local cont new tray sep anchor
    cont="$(printf '%s' "$out" | sed -n 's/.*CONT=\([0-9]*\).*/\1/p')"
    new="$(printf '%s' "$out"  | sed -n 's/.*NEW=\([0-9]*\).*/\1/p')"
    tray="$(printf '%s' "$out" | sed -n 's/.*TRAY=\(-\?[0-9]*\).*/\1/p')"
    sep="$(printf '%s' "$out"  | sed -n 's/.*SEP=\(-\?[0-9]*\).*/\1/p')"
    # Prefer the margins separator as the insertion anchor, else the tray.
    if [ -n "$sep" ] && [ "$sep" != "-1" ]; then anchor="$sep"; else anchor="$tray"; fi

    if [ -z "$cont" ] || [ -z "$new" ]; then
        echo "Widget installed; add it to the panel from 'Add Widgets' if it is not visible."
        restart_plasmashell
        return 0
    fi

    # Reorder AppletOrder so the widget sits just before the system tray.
    local file="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    systemctl --user stop plasma-plasmashell.service 2>/dev/null || kquitapp5 plasmashell 2>/dev/null || true
    sleep 1
    local order
    order="$(kreadconfig5 --file "$file" --group Containments --group "$cont" --group General --key AppletOrder 2>/dev/null || true)"
    if [ -n "$order" ]; then
        # Rebuild the order token by token: drop any stale copy of the new id,
        # then insert it right before the tray (or append it if there is no tray).
        local newlist="" inserted=0 t
        IFS=';' read -ra toks <<< "$order"
        for t in "${toks[@]}"; do
            [ -z "$t" ] && continue
            [ "$t" = "$new" ] && continue                       # drop stale copy
            if [ -n "$anchor" ] && [ "$anchor" != "-1" ] && [ "$t" = "$anchor" ] && [ "$inserted" = 0 ]; then
                newlist="${newlist:+$newlist;}$new"
                inserted=1
            fi
            newlist="${newlist:+$newlist;}$t"
        done
        [ "$inserted" = 0 ] && newlist="${newlist:+$newlist;}$new"   # no anchor found → append
        kwriteconfig5 --file "$file" --group Containments --group "$cont" --group General --key AppletOrder "$newlist"
    fi
    restart_plasmashell
    echo "Widget added to the panel next to the system tray."
}
add_to_panel

echo
echo "== All set =="
echo "kde-tags is installed and on your panel. Open it and pick a coworker to reach them."
echo "Change language or settings from the gear button in the popup."
