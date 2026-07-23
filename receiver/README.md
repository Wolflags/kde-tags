# kde-tags — receiver (for each coworker)

Anyone who wants to **receive** kde-tags notifications installs this on their
Linux machine. It runs a small service that subscribes to their personal ntfy
topic and shows every notification on the desktop (with sound). Presence
requests arrive with critical urgency (they stay on screen); messages arrive
as regular notifications.

## Automatic installation

```sh
./install-receiver.sh                                     # interactive
./install-receiver.sh --topic X --server Y --name "Ana"   # non-interactive
./install-receiver.sh --no-announce                       # without mDNS LAN announcement
# also via environment: KDE_TAGS_TOPIC / KDE_TAGS_SERVER / KDE_TAGS_NAME / KDE_TAGS_ANNOUNCE=no
```

The script:
1. Uses the system `ntfy` binary (or `~/.local/bin/ntfy`) or downloads the official static binary.
2. If it detects a previous installation (kde-tags, d8tags or Team Call), it shuts down the
   old services and offers to keep the same topic.
3. Asks for the server (default `https://ntfy.sh`) and your personal topic; leave it empty
   to generate a random one like `kde-tags-ana-x7k2m9q4pz`.
4. Writes `~/.config/kde-tags/client.yml` and the helper `~/.local/bin/kde-tags-notify.sh`.
5. Installs and starts the user service `kde-tags-receiver.service`.
6. Sends a test notification: it should show up on your desktop.
7. Asks for your **display name** and (unless `--no-announce`) announces you over mDNS on
   the local network with the `kde-tags-announce.service` unit: you automatically show up,
   with your name and initials, in the widget of any coworker on your LAN.
   Requires `avahi-utils` (`sudo apt install avahi-utils`); if missing, it warns and
   continues without announcing. The announcement's TXT record carries `name`, `topic`,
   `server` and your **system user** (`user`, e.g. `josej`); the widget shows that system
   user on hover so a free-text display name can't be used to impersonate someone.

At the end it prints your topic: **share it with your team** — it is what they
put in the widget to be able to reach you.

## Manual installation (summary)

```sh
# ~/.config/kde-tags/client.yml
default-host: https://ntfy.sh
subscribe:
  - topic: YOUR-TOPIC
    command: ~/.local/bin/kde-tags-notify.sh

# test in the foreground:
ntfy subscribe --config ~/.config/kde-tags/client.yml --from-config
```

Plus the service (`~/.config/systemd/user/kde-tags-receiver.service`) with
`ExecStart=/path/to/ntfy subscribe --config %h/.config/kde-tags/client.yml --from-config`,
then `systemctl --user enable --now kde-tags-receiver.service`.

## Notes

- **The topic is a password.** On ntfy.sh anyone who knows the topic can send you
  notifications and read the ones that arrive. Always use random suffixes, or run
  your own ntfy server with access tokens if your team needs more privacy.
  Topics from older versions (`teamcall-*`, `d8tags-*`) keep working — the prefix
  is cosmetic.
- **mDNS announcement**: your topic is broadcast to the whole local network — anyone
  on that LAN can see it. Disable it with `--no-announce` on untrusted networks.
- If your machine is off/offline, ntfy.sh caches the notification for ~12 h and
  delivers it on reconnect: "sent" in the widget means the server accepted it, not
  that you have seen it.
- `notify-send` works from the user service because the session bus lives at
  `$XDG_RUNTIME_DIR/bus`; no DISPLAY/DBUS setup is needed.
- Diagnostics:
  - `journalctl --user -u kde-tags-receiver.service -f` (receiving)
  - `journalctl --user -u kde-tags-announce.service -f` (announcing)
  - `avahi-browse -rt _kdetags._tcp` (see who is announcing on the LAN)
