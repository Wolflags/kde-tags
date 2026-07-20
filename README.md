# kde-tags — widget de KDE Plasma

Plasmoide de panel para avisar a compañeros de trabajo: un icono de chat en el
panel que al hacer clic abre un popup con la cuadrícula de compañeros (estilo
escritorios múltiples de Plasma, con celdas "vidrio" semitransparentes).
Seleccionas a alguien y puedes **solicitar su presencia** ("X solicita tu
presencia en su escritorio") o **enviarle un mensaje escrito**. El envío es un
POST HTTP al topic ntfy de esa persona; en su máquina un servicio (`receiver/`)
muestra la notificación de escritorio con sonido.

Requiere Plasma 5 (desarrollado y probado en 5.27 / Qt 5.15).

Repositorio: **https://github.com/Wolflags/kde-tags**

## Estructura

- `package/` — el plasmoide (`com.josej.kdetags`): QML + config.
- `receiver/` — lo que instala cada compañero para recibir avisos (ntfy + notify-send + servicio systemd de usuario). Ver `receiver/README.md`.

## 1. Descargar

Todo parte de clonar este repositorio (vale tanto para instalar el widget como el receptor):

```sh
git clone https://github.com/Wolflags/kde-tags.git
cd kde-tags
```

## 2. Instalar el widget (quien envía avisos)

Desde la carpeta clonada:

```sh
# primera vez
kpackagetool5 -t Plasma/Applet -i package

# para actualizar (tras un git pull o editar archivos)
kpackagetool5 -t Plasma/Applet -u package

# Plasma cachea el QML: reiniciar plasmashell tras instalar/actualizar
systemctl --user restart plasma-plasmashell.service
```

Luego: clic derecho en el panel → *Añadir elementos gráficos* → **kde-tags**.
Para tenerlo junto a los iconos de red/volumen: en el modo de edición del
panel, arrastra el widget hasta dejarlo pegado a la bandeja del sistema.

## 3. Instalar el receptor (quien recibe avisos)

Desde la carpeta clonada, en la máquina de cada compañero:

```sh
cd receiver
./install-receiver.sh
```

El instalador descarga ntfy si hace falta, pregunta el servidor (Enter =
`https://ntfy.sh`) y el topic personal, deja corriendo el servicio
`kde-tags-receiver.service` y envía un aviso de prueba. Al final imprime el
topic: **ese es el valor que se comparte** con quien deba poder avisarte
(va en la configuración del widget junto a tu nombre).

### Topic personalizado

Si dejas el topic vacío, el instalador genera uno aleatorio tipo
`kde-tags-ana-x7k2m9q4pz`. Para elegir uno propio:

```sh
# con flag (también sirve --server para un servidor ntfy propio)
./install-receiver.sh --topic mi-topic-secreto-x7k2

# o con variables de entorno (modo no interactivo, útil para desplegar)
KDE_TAGS_TOPIC=mi-topic-secreto-x7k2 KDE_TAGS_SERVER=https://ntfy.sh ./install-receiver.sh
```

El topic funciona como una contraseña: elige algo difícil de adivinar y
compártelo solo con el equipo. Detalle completo en `receiver/README.md`.

## Descubrimiento automático en la red local (mDNS)

Si todos están en la misma LAN, no hace falta intercambiar topics a mano: el
instalador del receptor pregunta tu **nombre visible** y anuncia un servicio
mDNS `_kdetags._tcp` (con tu nombre y topic); los widgets de los demás lo
detectan al abrir el popup y te muestran automáticamente con tus iniciales.

Requisito en **ambos** lados (anunciar y descubrir):

```sh
sudo apt install avahi-utils    # avahi-daemon suele venir ya activo
```

Notas:
- Se puede desactivar por máquina (`./install-receiver.sh --no-announce`) o en
  el widget (Configuración → "Descubrir compañeros automáticamente").
- Las entradas manuales tienen prioridad: añade a alguien con su mismo topic
  para renombrarlo; y sirven para gente fuera de la LAN (el descubrimiento
  mDNS no cruza routers/VPN).
- Si un equipo se apaga de golpe, su anuncio puede tardar un rato en expirar
  de la caché mDNS (cosmético).

## Uso

1. Clic en el icono de chat del panel → se abre el popup.
2. Si son muchos, escribe en el **buscador** (tiene el foco al abrir; filtra por
   nombre, sin distinguir mayúsculas ni acentos). Enter con un único resultado
   lo selecciona y salta al campo de mensaje. Con muchas personas la cuadrícula
   se limita a 4 columnas y hace scroll vertical.
3. Clic en un compañero para seleccionarlo (se resalta; otro clic lo deselecciona).
4. Botón **Solicitar presencia** (aviso prioritario fijo) o escribe un texto y
   **Enviar mensaje** (Enter en el campo también envía).
5. La celda muestra el resultado: giratorio → ✓ (aceptado por el servidor) o
   rojo + error (sin red, servidor mal, timeout de 10 s). El borrador solo se
   borra si el envío tuvo éxito.

## Configuración

Botón de engranaje en el popup (o clic derecho → *Configurar kde-tags*):

- **Servidor ntfy** — `https://ntfy.sh` o tu servidor propio.
- **Tu nombre** — aparece en el aviso del compañero.
- **Compañeros** — nombre + topic ntfy de cada uno (el topic se lo da su
  `install-receiver.sh`). Los topics `teamcall-*` de la v1 siguen funcionando:
  el prefijo es cosmético.

## Depuración

```sh
journalctl --user -u plasma-plasmashell.service -b -f | grep -iE 'kde-tags|qml'
```

Si cambias defaults en `contents/config/main.xml` después de haber añadido el
widget, quita y vuelve a añadir la instancia (los valores viejos quedan en
`~/.config/plasma-org.kde.plasma.desktop-appletsrc`).

## Privacidad

En ntfy.sh el topic es efectivamente una contraseña: usa sufijos aleatorios
(`kde-tags-jose-8f3k2q9x`) y compártelos solo dentro del equipo. Para más
privacidad, servidor ntfy propio con tokens (extensión futura: cabecera
`Authorization: Bearer` en el widget).

**Con el anuncio mDNS activado, tu topic se difunde a toda la red local**:
cualquiera conectado a esa LAN puede verlo (y por tanto enviarte avisos o
suscribirse a él). En una red de oficina de confianza suele ser aceptable;
si no, instala con `--no-announce` e intercambia topics a mano.
