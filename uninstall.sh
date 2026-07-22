#!/usr/bin/env bash
# kde-tags uninstaller: removes the widget and the receiver.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/Wolflags/kde-tags/main/uninstall.sh)
#
# Keeps the ntfy binary (~/.local/bin/ntfy) in case something else uses it.
set -uo pipefail   # no -e: keep going even if a step is already undone

BIN_DIR="$HOME/.local/bin"
CONF_DIR="$HOME/.config/kde-tags"
UNIT_DIR="$HOME/.config/systemd/user"
WIDGET_ID="com.josej.kdetags"

echo "== kde-tags uninstaller =="

restart_plasmashell() {
    systemctl --user restart plasma-plasmashell.service 2>/dev/null \
        || (kquitapp5 plasmashell 2>/dev/null; sleep 1; kstart5 plasmashell >/dev/null 2>&1 &)
}

# 1. Remove the widget from every panel.
if command -v qdbus >/dev/null 2>&1; then
    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
        panels().forEach(function (p) {
            p.widgets("com.josej.kdetags").forEach(function (w) { w.remove(); });
        });
    ' >/dev/null 2>&1 || true
fi

# 2. Uninstall the plasmoid package.
if command -v kpackagetool5 >/dev/null 2>&1; then
    kpackagetool5 -t Plasma/Applet -r "$WIDGET_ID" 2>/dev/null || true
fi

# 3. Stop and remove the user services.
for unit in kde-tags-receiver kde-tags-announce; do
    systemctl --user disable --now "$unit.service" 2>/dev/null || true
    rm -f "$UNIT_DIR/$unit.service"
done
systemctl --user daemon-reload 2>/dev/null || true

# 4. Remove configuration and the notification helper.
rm -rf "$CONF_DIR"
rm -f "$BIN_DIR/kde-tags-notify.sh"

# 5. Kept on purpose: the ntfy binary and the source checkout.
#    ~/.local/bin/ntfy  and  ~/.local/share/kde-tags

# 6. Restart the shell so the panel updates.
restart_plasmashell

echo
echo "== Done =="
echo "kde-tags has been removed."
echo "Kept: ~/.local/bin/ntfy (shared ntfy client) and ~/.local/share/kde-tags (sources)."
echo "Remove them too if you want:  rm -f ~/.local/bin/ntfy; rm -rf ~/.local/share/kde-tags"
