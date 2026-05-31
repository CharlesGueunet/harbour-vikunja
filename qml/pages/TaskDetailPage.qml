import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: detailPage
    allowedOrientations: defaultAllowedOrientations

    property int taskId
    property int taskIndex

    // Reactively extract details from the taskModel
    property var taskData: taskModel.getTask(taskIndex)

    Component.onCompleted: {
        vikunjaApi.taskUpdated.connect(detailPage.handleTaskUpdated);
        vikunjaApi.taskReceived.connect(detailPage.handleTaskReceived);
        vikunjaApi.tasksReceived.connect(detailPage.handleTasksReceived);
    }

    Component.onDestruction: {
        vikunjaApi.taskUpdated.disconnect(detailPage.handleTaskUpdated);
        vikunjaApi.taskReceived.disconnect(detailPage.handleTaskReceived);
        vikunjaApi.tasksReceived.disconnect(detailPage.handleTasksReceived);
    }

    function handleTaskUpdated(id, success, errorMsg) {
        console.log("QML [TaskDetailPage] handleTaskUpdated id:", id, "success:", success);
        if (success && id === detailPage.taskId) {
            vikunjaApi.fetchTask(detailPage.taskId);
        }
    }

    function handleTaskReceived(id, task) {
        console.log("QML [TaskDetailPage] handleTaskReceived id:", id, "detailPage.taskId:", detailPage.taskId);
        if (id === detailPage.taskId) {
            for (var i = 0; i < taskModel.count; ++i) {
                if (taskModel.getTask(i).id === detailPage.taskId) {
                    console.log("QML [TaskDetailPage] found matching task in model at index:", i);
                    detailPage.taskIndex = i;
                    detailPage.taskData = taskModel.getTask(i);
                    break;
                }
            }
        }
    }

    function handleTasksReceived(projectId, tasks) {
        console.log("QML [TaskDetailPage] handleTasksReceived, searching model for taskId:", detailPage.taskId);
        for (var i = 0; i < taskModel.count; ++i) {
            if (taskModel.getTask(i).id === detailPage.taskId) {
                console.log("QML [TaskDetailPage] handleTasksReceived found task at index:", i);
                detailPage.taskIndex = i;
                detailPage.taskData = taskModel.getTask(i);
                break;
            }
        }
    }

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
                    pageStack.push(Qt.resolvedUrl("AddEditTaskDialog.qml"), {
                        "isEdit": true,
                        "taskId": taskId,
                        "initialTitle": taskData.title,
                        "initialDescription": taskData.description,
                        "initialDueDate": taskData.dueDate,
                        "initialDone": taskData.done,
                        "initialProjectId": taskData.projectId
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
