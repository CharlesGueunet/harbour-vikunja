import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    id: cover

    CoverPlaceholder {
        text: qsTr("All done!")
        icon.source: "../../icons/cover-icon.png"
        visible: taskModel.count === 0
    }

    Column {
        anchors {
            fill: parent
            margins: Theme.paddingMedium
        }
        spacing: Theme.paddingSmall
        visible: taskModel.count > 0

        Label {
            text: appWindow.activeProjectTitle
            font.bold: true
            color: Theme.primaryColor
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Separator {
            width: parent.width
            color: Theme.highlightColor
        }

        Repeater {
            model: Math.min(taskModel.count, 5)
            delegate: Label {
                property variant taskInfo: taskModel.getTask(index)
                width: parent.width
                text: "• " + (taskInfo ? taskInfo.title : "")
                color: {
                    if (taskInfo) {
                        if (taskInfo.done) return Theme.secondaryColor;
                        if (taskInfo.priority >= 3) return "red";
                        if (taskInfo.priority === 2) return "orange";
                    }
                    return Theme.secondaryColor;
                }
                font.pixelSize: Theme.fontSizeExtraSmall
                truncationMode: TruncationMode.Fade
            }
        }
    }
}
