import QtQuick 2.15
import QtQuick.Controls 2.5 as QQC2
import QtQuick.Layouts 1.1
import org.kde.kirigami 2.5 as Kirigami

ColumnLayout {
    id: page

    property alias cfg_serverUrl: serverField.text
    property alias cfg_senderName: senderField.text
    property alias cfg_lanDiscovery: lanDiscoveryBox.checked
    // Stored as a JSON string: [{"name": ..., "topic": ...}, ...]
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

            Kirigami.FormData.label: "ntfy server:"
            placeholderText: "https://ntfy.sh"
        }

        QQC2.TextField {
            id: senderField

            Kirigami.FormData.label: "Your name:"
            placeholderText: "How your coworkers will see you"
        }

        QQC2.CheckBox {
            id: lanDiscoveryBox

            Kirigami.FormData.label: "Local network:"
            text: "Discover coworkers automatically (mDNS)"
        }
    }

    Kirigami.Heading {
        level: 2
        text: "Coworkers"
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: "Where does the topic come from? Each coworker runs the receiver installer "
              + "(the project's receiver/ folder: ./install-receiver.sh) on their PC. When it "
              + "finishes, the script prints their personal topic (e.g. kde-tags-ana-x7k2m9q4pz): "
              + "ask them for it and paste it here next to their name. They can also pick their "
              + "own by running ./install-receiver.sh --topic whatever-they-want. With local "
              + "network discovery enabled, anyone who installs the receiver on your network "
              + "shows up in the widget automatically (this manual list is for people outside "
              + "the LAN, or to rename a discovered coworker by adding them with the same topic)."
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
                placeholderText: "Name"
                onEditingFinished: {
                    coworkerModel.setProperty(index, "name", text);
                    page.save();
                }
            }

            QQC2.TextField {
                Layout.fillWidth: true
                text: model.topic
                placeholderText: "ntfy topic"
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
                QQC2.ToolTip.text: "Remove"
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
            placeholderText: "Name"
        }

        QQC2.TextField {
            id: newTopic

            Layout.fillWidth: true
            placeholderText: "ntfy topic (e.g. kde-tags-ana-x7k2m9q4pz)"
        }

        QQC2.Button {
            icon.name: "list-add"
            text: "Add"
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
        text: "The topic works like a password: anyone who knows it can send and read notifications. Use randomly-suffixed topics (the installer generates them that way) and share them only within your team."
    }

    Item {
        Layout.fillHeight: true
    }
}
