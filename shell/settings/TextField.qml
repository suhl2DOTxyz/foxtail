import QtQuick
import qs.services
import qs.components

// Single-line text input with a placeholder.
Rectangle {
    id: tf
    property alias text: input.text
    property string placeholder: ""
    property bool secret: false
    signal accepted()
    width: 200
    height: 26
    radius: Theme.liquid ? 13 : 6
    color: Theme.control
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? Theme.accent : Theme.separator
    function focusInput() { input.forceActiveFocus(); }
    TextInput {
        selectionColor: Theme.accent
        selectedTextColor: "white"
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.px(13)
        clip: true
        echoMode: tf.secret ? TextInput.Password : TextInput.Normal
        selectByMouse: true
        onAccepted: tf.accepted()
        Label {
            visible: !input.text && !input.activeFocus
            anchors.verticalCenter: parent.verticalCenter
            text: tf.placeholder
            color: Theme.textTertiary
        }
    }
}
