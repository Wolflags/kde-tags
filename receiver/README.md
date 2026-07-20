# kde-tags — receptor (para cada compañero)

Cada persona que quiera **recibir** avisos de kde-tags instala esto en su máquina
Linux. Corre un pequeño servicio que se suscribe a su topic personal de ntfy y
muestra cada aviso como notificación de escritorio (con sonido). Las solicitudes
de presencia llegan con urgencia crítica (persisten en pantalla); los mensajes,
como notificación normal.

## Instalación automática

```sh
./install-receiver.sh                       # interactivo
./install-receiver.sh --topic X --server Y --name "Ana"   # no interactivo
./install-receiver.sh --no-announce         # sin anuncio mDNS en la LAN
# también por entorno: KDE_TAGS_TOPIC / KDE_TAGS_SERVER / KDE_TAGS_NAME / KDE_TAGS_ANNOUNCE=no
```

El script:
1. Usa el binario `ntfy` del sistema (o `~/.local/bin/ntfy`) o descarga el binario estático oficial.
2. Si detecta una instalación previa (kde-tags, d8tags o Team Call), apaga los servicios
   viejos y ofrece conservar el mismo topic.
3. Pregunta servidor (por defecto `https://ntfy.sh`) y topic personal; si lo dejas vacío
   genera uno aleatorio tipo `kde-tags-ana-x7k2m9q4pz`.
4. Escribe `~/.config/kde-tags/client.yml` y el helper `~/.local/bin/kde-tags-notify.sh`.
5. Instala y arranca el servicio de usuario `kde-tags-receiver.service`.
6. Envía un aviso de prueba: debería aparecer en tu escritorio.
7. Pregunta tu **nombre visible** y (salvo `--no-announce`) te anuncia por mDNS en la
   red local con el servicio `kde-tags-announce.service`: así apareces automáticamente,
   con tu nombre e iniciales, en el widget de cualquier compañero de tu misma LAN.
   Requiere `avahi-utils` (`sudo apt install avahi-utils`); si falta, lo avisa y sigue sin anuncio.

Al final imprime tu topic: **compártelo con el equipo** — es lo que ponen en el
widget para poder avisarte.

## Instalación manual (resumen)

```sh
# ~/.config/kde-tags/client.yml
default-host: https://ntfy.sh
subscribe:
  - topic: TU-TOPIC
    command: ~/.local/bin/kde-tags-notify.sh

# probar en primer plano:
ntfy subscribe --config ~/.config/kde-tags/client.yml --from-config
```

Y el servicio (`~/.config/systemd/user/kde-tags-receiver.service`) con
`ExecStart=/ruta/a/ntfy subscribe --config %h/.config/kde-tags/client.yml --from-config`,
luego `systemctl --user enable --now kde-tags-receiver.service`.

## Notas

- **El topic es una contraseña.** En ntfy.sh cualquiera que conozca el topic puede
  enviarte avisos y leer los que lleguen. Usa siempre sufijos aleatorios, o monta
  un servidor ntfy propio con tokens de acceso si el equipo necesita más privacidad.
  Los topics `teamcall-*` de la v1 siguen siendo válidos (el prefijo es cosmético).
- Si tu máquina está apagada/offline, ntfy.sh cachea el aviso ~12 h y lo entrega
  al reconectar: "enviado" en el widget significa que el servidor lo aceptó, no que
  ya lo viste.
- **Anuncio mDNS**: tu topic se difunde a toda la red local — cualquiera en esa LAN
  puede verlo. Desactívalo con `--no-announce` si la red no es de confianza.
- `notify-send` funciona desde el servicio de usuario porque el bus de sesión está en
  `$XDG_RUNTIME_DIR/bus`; no hace falta configurar DISPLAY ni DBUS a mano.
- Diagnóstico:
  - `journalctl --user -u kde-tags-receiver.service -f` (recepción)
  - `journalctl --user -u kde-tags-announce.service -f` (anuncio)
  - `avahi-browse -rt _kdetags._tcp` (ver quién se anuncia en la LAN)
