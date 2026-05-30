import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: detailPage
    allowedOrientations: defaultAllowedOrientations

    property int taskId
    property int taskIndex

    // Reactively extract details from the taskModel
    property var taskData: taskModel.getTask(taskIndex)

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Delete Task")
                onClicked: {
                    remorse.execute(qsTr("Deleting task"), function() {
                        vikunjaApi.deleteTask(taskId);
                        pageStack.pop();
                    });
                }
            }

            MenuItem {
                text: qsTr("Edit Task")
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("AddEditTaskDialog.qml"), {
                        "isEdit": true,
                        "taskId": taskId,
                        "initialTitle": taskData.title,
                        "initialDescription": taskData.description,
                        "initialDueDate": taskData.dueDate,
                        "initialDone": taskData.done,
                        "initialProjectId": taskData.projectId
                    });
                    dialog.accepted.connect(function() {
                        // Refresh the view's data
                        taskData = taskModel.getTask(taskIndex);
                    });
                }
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Task Details")
            }

            SectionHeader {
                text: qsTr("Task Info")
            }

            DetailItem {
                label: qsTr("Title")
                value: taskData.title
            }

            DetailItem {
                label: qsTr("Status")
                value: taskData.done ? qsTr("Completed") : qsTr("Active")
            }

            DetailItem {
                label: qsTr("Due Date")
                value: taskData.dueDate !== "" ? taskData.dueDate.substring(0, 10) : qsTr("No due date")
            }

            SectionHeader {
                text: qsTr("Description")
                visible: taskData.description !== ""
            }

            Label {
                width: parent.width - 2 * Theme.paddingLarge
                anchors.horizontalCenter: parent.horizontalCenter
                text: taskData.description
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
                wrapMode: Text.Wrap
                visible: taskData.description !== ""
            }
        }

        RemorsePopup {
            id: remorse
        }
    }
}
