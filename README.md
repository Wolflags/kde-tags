# kde-tags — KDE Plasma widget

Panel plasmoid for reaching your coworkers: a chat icon in the panel that opens
a popup with a coworker grid (styled like Plasma's virtual desktops pager, with
translucent "glass" cells). Select someone and either **request their
presence** ("X is requesting your presence at their desk") or **send them a
written message**. Sending is an HTTP POST to that person's ntfy topic; on
their machine a small service (`receiver/`) shows the desktop notification
with sound. Coworkers on the same local network are **discovered
automatically** via mDNS.

Requires Plasma 5 (developed and tested on 5.27 / Qt 5.15).

Repository: **https://github.com/Wolflags/kde-tags**

## Install (one command)

Run this on any Plasma 5 machine and you are done — it installs the widget,
sets up the receiver, installs the LAN-discovery dependency, and drops the
widget onto your panel next to the system tray:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/Wolflags/kde-tags/main/install.sh)
```

It will ask for your display name (for the notification and LAN discovery) and
for your sudo password once (to install `avahi-utils`). Everything else is
automatic; the topic is generated for you and printed at the end. Re-running
the command updates an existing install without losing your topic.

Prefer to read the script first? It lives at
[`install.sh`](install.sh) — download and inspect it, then run `bash install.sh`.

Unattended / custom values (flags are forwarded to the receiver installer):

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/Wolflags/kde-tags/main/install.sh) \
    --name "Ana" --topic my-secret-topic-x7k2 --server https://ntfy.sh
# or --no-announce to skip the mDNS LAN announcement
```

## Uninstall

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/Wolflags/kde-tags/main/uninstall.sh)
```

Removes the widget from the panel, uninstalls the plasmoid, stops and deletes
the receiver/announce services, and deletes `~/.config/kde-tags` and the
notification helper. It **keeps** the `ntfy` binary (in case something else
uses it) and the source checkout; the command at the end tells you how to
remove those too. Also runnable from a clone as `bash uninstall.sh`.

## Layout

- `install.sh` — the one-command installer (widget + receiver + panel placement).
- `uninstall.sh` — the uninstaller.
- `package/` — the plasmoid (`com.josej.kdetags`): QML + config.
- `receiver/` — what each coworker installs to receive notifications (ntfy + notify-send + systemd user service). See `receiver/README.md`.

## Manual installation (advanced)

If you would rather do it step by step:

```sh
git clone https://github.com/Wolflags/kde-tags.git
cd kde-tags

# widget (whoever sends notifications)
kpackagetool5 -t Plasma/Applet -i package      # -u to update
systemctl --user restart plasma-plasmashell.service
# then: right-click the panel → Add Widgets → kde-tags,
# and in edit mode drag it next to the system tray.

# receiver (whoever receives notifications), on each machine
cd receiver
./install-receiver.sh
```

The receiver installer downloads ntfy if needed, asks for the server (Enter =
`https://ntfy.sh`) and your personal topic, leaves the
`kde-tags-receiver.service` running and sends a test notification. At the end
it prints the topic: **that is the value to share** with anyone who should be
able to reach you (it goes in the widget's settings next to your name).

### Custom topic

If you leave the topic empty, the installer generates a random one like
`kde-tags-ana-x7k2m9q4pz`. To pick your own:

```sh
# with a flag (--server also works, for a self-hosted ntfy server)
./install-receiver.sh --topic my-secret-topic-x7k2

# or with environment variables (non-interactive mode, useful for rollouts)
KDE_TAGS_TOPIC=my-secret-topic-x7k2 KDE_TAGS_SERVER=https://ntfy.sh ./install-receiver.sh
```

The topic works like a password: pick something hard to guess and share it
only with your team. Full details in `receiver/README.md`.

## Automatic discovery on the local network (mDNS)

If everyone is on the same LAN, there is no need to exchange topics by hand:
the receiver installer asks for your **display name** and announces an mDNS
service `_kdetags._tcp` (with your name and topic); everyone else's widget
detects it when the popup opens and shows you automatically with your
initials.

Requirement on **both** sides (announcing and discovering):

```sh
sudo apt install avahi-utils    # avahi-daemon is usually already running
```

Notes:
- It can be disabled per machine (`./install-receiver.sh --no-announce`) or in
  the widget (Settings → "Discover coworkers automatically").
- Manual entries take precedence: add someone with their same topic to rename
  them; they also cover people outside the LAN (mDNS discovery does not cross
  routers/VPNs).
- If a machine shuts down abruptly, its announcement may take a while to
  expire from the mDNS cache (cosmetic).

## Usage

1. Click the chat icon in the panel → the popup opens.
2. With many people, type in the **search field** (it has focus on open; it
   filters by name, case- and accent-insensitive). Enter with a single match
   selects it and jumps to the message field. With large teams the grid caps
   at 4 columns and scrolls vertically.
3. Click a coworker to select them (highlighted; click again to deselect).
4. **Request presence** button (fixed high-priority notification) or type a
   text and **Send message** (Enter in the field also sends).
5. The cell shows the result: spinner → ✓ (accepted by the server) or red +
   error (no network, bad server, 10 s timeout). The draft is only cleared if
   the send succeeded.

The coworker sees your **name in the notification title** (e.g. "👋 Pedro" for
a presence request, "💬 Pedro" for a message). Your name is taken from the one
you chose at install time; change it anytime under Settings → Your name.

## Settings

Gear button in the popup (or right-click → *Configure kde-tags*):

- **Language** — English or Español; translates the whole interface (and the
  notifications you send) for this user. Default: English.
- **ntfy server** — `https://ntfy.sh` or your own server.
- **Your name** — shown as the title of the coworker's notification;
  pre-filled from the name you chose during installation.
- **Local network** — toggle for automatic mDNS discovery.
- **Coworkers** — name + ntfy topic for each one (the topic comes from their
  `install-receiver.sh`). Topics from older versions (`teamcall-*`) keep
  working: the prefix is cosmetic.

## Debugging

```sh
journalctl --user -u plasma-plasmashell.service -b -f | grep -iE 'kde-tags|qml'
```

If you change defaults in `contents/config/main.xml` after the widget was
added, remove and re-add the instance (old values are kept in
`~/.config/plasma-org.kde.plasma.desktop-appletsrc`).

## Privacy

On ntfy.sh the topic is effectively a password: use random suffixes
(`kde-tags-jose-8f3k2q9x`) and share them only within your team. For more
privacy, self-host an ntfy server with tokens (future extension: an
`Authorization: Bearer` header in the widget).

**With the mDNS announcement enabled, your topic is broadcast to the whole
local network**: anyone connected to that LAN can see it (and therefore send
you notifications or subscribe to it). On a trusted office network that is
usually acceptable; otherwise install with `--no-announce` and exchange topics
by hand.
