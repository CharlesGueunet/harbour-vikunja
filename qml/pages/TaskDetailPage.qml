import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: detailPage
    allowedOrientations: defaultAllowedOrientations

    property int taskId
    property int taskIndex

    // Reactively extract details from the taskModel
    property var taskData: taskModel.getTask(taskIndex)

    onStatusChanged: {
        if (status === PageStatus.Active) {
            vikunjaApi.fetchTask(detailPage.taskId);
        }
    }

    Component.onCompleted: {
        vikunjaApi.taskUpdated.connect(detailPage.handleTaskUpdated);
        vikunjaApi.taskReceived.connect(detailPage.handleTaskReceived);
        vikunjaApi.tasksReceived.connect(detailPage.handleTasksReceived);
        vikunjaApi.labelAssociated.connect(detailPage.handleLabelUpdated);
        vikunjaApi.labelDissociated.connect(detailPage.handleLabelUpdated);
    }

    Component.onDestruction: {
        vikunjaApi.taskUpdated.disconnect(detailPage.handleTaskUpdated);
        vikunjaApi.taskReceived.disconnect(detailPage.handleTaskReceived);
        vikunjaApi.tasksReceived.disconnect(detailPage.handleTasksReceived);
        vikunjaApi.labelAssociated.disconnect(detailPage.handleLabelUpdated);
        vikunjaApi.labelDissociated.disconnect(detailPage.handleLabelUpdated);
    }

    function handleTaskUpdated(id, success, errorMsg) {
        if (success && id === detailPage.taskId) {
            vikunjaApi.fetchTask(detailPage.taskId);
        }
    }

    function handleLabelUpdated(tId, lId, success, errorMsg) {
        if (success && tId === detailPage.taskId) {
            vikunjaApi.fetchTask(detailPage.taskId);
        }
    }

    function handleTaskReceived(id, task) {
        if (id === detailPage.taskId) {
            for (var i = 0; i < taskModel.count; ++i) {
                if (taskModel.getTask(i).id === detailPage.taskId) {
                    detailPage.taskIndex = i;
                    detailPage.taskData = taskModel.getTask(i);
                    break;
                }
            }
        }
    }

    function handleTasksReceived(projectId, tasks) {
        for (var i = 0; i < taskModel.count; ++i) {
            if (taskModel.getTask(i).id === detailPage.taskId) {
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

            MenuItem {
                text: qsTr("Edit Labels")
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("SelectLabelsPage.qml"), {
                        "taskId": taskId,
                        "taskIndex": taskIndex,
                        "taskLabels": taskData.labels || []
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

            Item {
                width: parent.width
                height: Math.max(detailLabel.implicitHeight, labelBadgesFlow.implicitHeight) + Theme.paddingMedium
                visible: taskData.labels && taskData.labels.length > 0

                Label {
                    id: detailLabel
                    text: qsTr("Labels")
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                }

                Flow {
                    id: labelBadgesFlow
                    anchors.left: detailLabel.right
                    anchors.leftMargin: Theme.paddingLarge
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.paddingSmall

                    Repeater {
                        model: taskData.labels
                        Rectangle {
                            width: labelText.implicitWidth + Theme.paddingSmall
                            height: labelText.implicitHeight + Theme.paddingSmall / 2
                            radius: 4
                            color: (modelData && modelData.hexColor) ? modelData.hexColor : Theme.secondaryColor
                            opacity: 0.8
                            Label {
                                id: labelText
                                text: modelData ? modelData.title : ""
                                font.pixelSize: Theme.fontSizeTiny
                                font.bold: true
                                color: "white"
                                anchors.centerIn: parent
                            }
                        }
                    }
                }
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
