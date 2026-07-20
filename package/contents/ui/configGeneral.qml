import QtQuick 2.15
import QtQuick.Controls 2.5 as QQC2
import QtQuick.Layouts 1.1
import org.kde.kirigami 2.5 as Kirigami

ColumnLayout {
    id: page

    property alias cfg_serverUrl: serverField.text
    property alias cfg_senderName: senderField.text
    // Se guarda como string JSON: [{"name": ..., "topic": ...}, ...]
    property string cfg_coworkers

    spacing: Kirigami.Units.largeSpacing

    ListModel {
        id: coworkerModel
    }

    Component.onCompleted: {
        try {
            const parsed = JSON.parse(cfg_coworkers);
            if (Array.isArray(parsed)) {
                for (let i = 0; i < parsed.length; ++i) {
                    coworkerModel.append({
                        name: String(parsed[i].name || ""),
                        topic: String(parsed[i].topic || "")
                    });
                }
            }
        } catch (e) {
        }
    }

    function save() {
        const arr = [];
        for (let i = 0; i < coworkerModel.count; ++i) {
            const item = coworkerModel.get(i);
            arr.push({ name: item.name, topic: item.topic });
        }
        cfg_coworkers = JSON.stringify(arr);
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        QQC2.TextField {
            id: serverField

            Kirigami.FormData.label: "Servidor ntfy:"
            placeholderText: "https://ntfy.sh"
        }

        QQC2.TextField {
            id: senderField

            Kirigami.FormData.label: "Tu nombre:"
            placeholderText: "Cómo te verán tus compañeros"
        }
    }

    Kirigami.Heading {
        level: 2
        text: "Compañeros"
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: "¿De dónde sale el topic? Cada compañero ejecuta el instalador del receptor "
              + "(carpeta receiver/ del proyecto: ./install-receiver.sh) en su PC. Al terminar, "
              + "el script imprime su topic personal (p. ej. kde-tags-ana-x7k2m9q4pz): pídeselo y "
              + "pégalo aquí junto a su nombre. También puede elegir uno propio ejecutando "
              + "./install-receiver.sh --topic el-topic-que-quiera."
    }

    ListView {
        id: coworkerList

        Layout.fillWidth: true
        implicitHeight: contentHeight
        interactive: false
        model: coworkerModel
        spacing: Kirigami.Units.smallSpacing

        delegate: RowLayout {
            width: coworkerList.width
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                Layout.fillWidth: true
                text: model.name
                placeholderText: "Nombre"
                onEditingFinished: {
                    coworkerModel.setProperty(index, "name", text);
                    page.save();
                }
            }

            QQC2.TextField {
                Layout.fillWidth: true
                text: model.topic
                placeholderText: "Topic de ntfy"
                onEditingFinished: {
                    coworkerModel.setProperty(index, "topic", text);
                    page.save();
                }
            }

            QQC2.ToolButton {
                icon.name: "edit-delete-remove"
                onClicked: {
                    coworkerModel.remove(index);
                    page.save();
                }
                QQC2.ToolTip.text: "Eliminar"
                QQC2.ToolTip.visible: hovered
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        QQC2.TextField {
            id: newName

            Layout.fillWidth: true
            placeholderText: "Nombre"
        }

        QQC2.TextField {
            id: newTopic

            Layout.fillWidth: true
            placeholderText: "Topic de ntfy (p. ej. kde-tags-ana-x7k2m9q4pz)"
        }

        QQC2.Button {
            icon.name: "list-add"
            text: "Añadir"
            enabled: newName.text.trim().length > 0 && newTopic.text.trim().length > 0
            onClicked: {
                coworkerModel.append({
                    name: newName.text.trim(),
                    topic: newTopic.text.trim()
                });
                page.save();
                newName.text = "";
                newTopic.text = "";
                newName.forceActiveFocus();
            }
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: "El topic funciona como una contraseña: cualquiera que lo conozca puede enviar y leer avisos. Usa topics con sufijo aleatorio (el instalador los genera así) y compártelos solo con el equipo."
    }

    Item {
        Layout.fillHeight: true
    }
}
