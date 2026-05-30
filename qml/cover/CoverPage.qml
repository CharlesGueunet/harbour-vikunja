import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    id: cover

    property int taskCount: taskModel ? taskModel.rowCount() : 0

    Connections {
        target: vikunjaApi
        onTasksReceived: taskCount = taskModel.rowCount()
        onTaskDeleted: taskCount = taskModel.rowCount()
        onTaskCreated: taskCount = taskModel.rowCount()
    }

    CoverPlaceholder {
        text: qsTr("All done!")
        icon.source: "../../icons/cover-icon.png"
        visible: cover.taskCount === 0
    }

    Column {
        anchors {
            fill: parent
            margins: Theme.paddingMedium
        }
        spacing: Theme.paddingSmall
        visible: cover.taskCount > 0

        Label {
            text: "Vikunja"
            font.bold: true
            color: Theme.primaryColor
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Separator {
            width: parent.width
            color: Theme.highlightColor
        }

        Repeater {
            model: Math.min(cover.taskCount, 5)
            delegate: Label {
                property variant taskInfo: taskModel.getTask(index)
                width: parent.width
                text: "• " + (taskInfo ? taskInfo.title : "")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                truncationMode: TruncationMode.Fade
            }
        }
    }
}
