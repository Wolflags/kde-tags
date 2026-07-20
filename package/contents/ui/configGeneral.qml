import QtQuick 2.15
import QtQuick.Controls 2.5 as QQC2
import QtQuick.Layouts 1.1
import org.kde.kirigami 2.5 as Kirigami
import "i18n.js" as I18n

ColumnLayout {
    id: page

    property alias cfg_serverUrl: serverField.text
    property alias cfg_senderName: senderField.text
    property alias cfg_lanDiscovery: lanDiscoveryBox.checked
    property string cfg_language
    // Stored as a JSON string: [{"name": ..., "topic": ...}, ...]
    property string cfg_coworkers

    // Reflects the combo's CURRENT choice so the page retranslates live,
    // before Apply. Index-based (avoids valueRole/currentValue, which need
    // QtQuick.Controls 2.14+): 0 = English, 1 = Español.
    readonly property string uiLang: languageCombo.currentIndex === 1 ? "es" : "en"
    function tr(key) {
        return I18n.t(uiLang, key);
    }

    spacing: Kirigami.Units.largeSpacing

    ListModel {
        id: coworkerModel
    }

    Component.onCompleted: {
        // Preselect the stored language in the combo.
        languageCombo.currentIndex = (cfg_language === "es") ? 1 : 0;
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

        QQC2.ComboBox {
            id: languageCombo

            Kirigami.FormData.label: page.tr("cfg.language")
            model: ["English", "Español"]
            onActivated: page.cfg_language = (currentIndex === 1 ? "es" : "en")
        }

        QQC2.TextField {
            id: serverField

            Kirigami.FormData.label: page.tr("cfg.server")
            placeholderText: "https://ntfy.sh"
        }

        QQC2.TextField {
            id: senderField

            Kirigami.FormData.label: page.tr("cfg.yourName")
            placeholderText: page.tr("cfg.yourNamePlaceholder")
        }

        QQC2.CheckBox {
            id: lanDiscoveryBox

            Kirigami.FormData.label: page.tr("cfg.localNetwork")
            text: page.tr("cfg.discover")
        }
    }

    Kirigami.Heading {
        level: 2
        text: page.tr("cfg.coworkers")
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: page.tr("cfg.topicHelp")
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
                placeholderText: page.tr("cfg.name")
                onEditingFinished: {
                    coworkerModel.setProperty(index, "name", text);
                    page.save();
                }
            }

            QQC2.TextField {
                Layout.fillWidth: true
                text: model.topic
                placeholderText: page.tr("cfg.topic")
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
                QQC2.ToolTip.text: page.tr("cfg.remove")
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
            placeholderText: page.tr("cfg.name")
        }

        QQC2.TextField {
            id: newTopic

            Layout.fillWidth: true
            placeholderText: page.tr("cfg.topicPlaceholder")
        }

        QQC2.Button {
            icon.name: "list-add"
            text: page.tr("cfg.add")
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
        text: page.tr("cfg.privacy")
    }

    Item {
        Layout.fillHeight: true
    }
}
