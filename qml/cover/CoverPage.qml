import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    id: cover

    ListModel {
        id: coverTaskModel
    }
    function updateCoverTasks() {
        coverTaskModel.clear();
        var activeProjId = appWindow.activeProjectId;
        var count = 0;
        for (var i = 0; i < taskModel.count; ++i) {
            var task = taskModel.getTask(i);
            if (task && !task.done) {
                if (activeProjId === 0 || task.projectId === activeProjId) {
                    coverTaskModel.append({
                        "title": task.title,
                        "priority": task.priority,
                        "done": task.done
                    });
                    count++;
                    if (count >= 5) {
                        break;
                    }
                }
            }
        }
    }
    Connections {
        target: taskModel
        onDataChanged: cover.updateCoverTasks()
        onModelReset: cover.updateCoverTasks()
        onRowsInserted: cover.updateCoverTasks()
        onRowsRemoved: cover.updateCoverTasks()
    }

    Connections {
        target: appWindow
        onActiveProjectIdChanged: cover.updateCoverTasks()
    }

    Component.onCompleted: updateCoverTasks()

    CoverPlaceholder {
        text: qsTr("All done!")
        icon.source: "../../icons/sfos-icon.png"
        visible: coverTaskModel.count === 0
    }

    Column {
        anchors {
            fill: parent
            margins: Theme.paddingMedium
        }
        spacing: Theme.paddingSmall
        visible: coverTaskModel.count > 0

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
            model: coverTaskModel
            delegate: Label {
                width: parent.width
                text: "• " + title
                color: {
                    if (done) return Theme.secondaryColor;
                    if (priority >= 3) return "red";
                    if (priority === 2) return "orange";
                    return Theme.secondaryColor;
                }
                font.pixelSize: Theme.fontSizeExtraSmall
                truncationMode: TruncationMode.Fade
            }
        }
    }
}
