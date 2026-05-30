import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    Column {
        anchors.centerIn: parent
        spacing: Theme.paddingLarge
        width: parent.width - 2 * Theme.paddingMedium

        Image {
            id: coverIcon
            source: "../../icons/cover-icon.png"
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.iconSizeLauncher
            height: Theme.iconSizeLauncher
            smooth: true
        }

        Label {
            text: "Vikunja"
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Label {
            text: taskModel.rowCount() > 0 
                ? qsTr("%n Active Task(s)", "", taskModel.rowCount()) 
                : qsTr("All done!")
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeSmall
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
