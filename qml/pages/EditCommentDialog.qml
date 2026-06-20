import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: editCommentDialog
    allowedOrientations: defaultAllowedOrientations

    property string initialCommentText: ""
    property string commentText: ""

    Component.onCompleted: {
        commentField.text = initialCommentText;
    }

    onAccepted: {
        commentText = commentField.text;
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: dialogColumn.height + Theme.paddingLarge

        Column {
            id: dialogColumn
            width: parent.width
            spacing: Theme.paddingLarge

            DialogHeader {
                title: qsTr("Edit Comment")
                acceptText: qsTr("Save")
            }

            TextArea {
                id: commentField
                width: parent.width - 2 * Theme.paddingLarge
                anchors.horizontalCenter: parent.horizontalCenter
                label: qsTr("Comment")
                placeholderText: qsTr("Write a comment...")
                wrapMode: TextEdit.Wrap
                focus: true
            }
        }
    }
}
