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

## Uso

1. Clic en el icono de chat del panel → se abre el popup.
2. Clic en un compañero para seleccionarlo (se resalta; otro clic lo deselecciona).
3. Botón **Solicitar presencia** (aviso prioritario fijo) o escribe un texto y
   **Enviar mensaje** (Enter en el campo también envía).
4. La celda muestra el resultado: giratorio → ✓ (aceptado por el servidor) o
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
