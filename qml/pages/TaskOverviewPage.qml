import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

Page {
    id: overviewPage
    allowedOrientations: defaultAllowedOrientations

    property int currentProjectId: 0
    property string currentProjectTitle: qsTr("All Projects")

    function updateActiveProjectTitle() {
        if (currentProjectTitle === qsTr("All Projects")) {
            appWindow.activeProjectTitle = "Vikunja"
        } else {
            appWindow.activeProjectTitle = currentProjectTitle
        }
    }

    onCurrentProjectTitleChanged: updateActiveProjectTitle()

    Component.onCompleted: {
        updateActiveProjectTitle();
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            vikunjaApi.fetchTasks(currentProjectId);
        }
    }

    // Refresh the task list once the server confirms a new task was created.
    // This fires after the network request completes, ensuring the server has persisted changes.
    Connections {
        target: vikunjaApi
        onTaskCreated: {
            if (success) {
                vikunjaApi.fetchTasks(currentProjectId);
            }
        }
    }

    SilicaListView {
        id: taskListView
        anchors.fill: parent
        model: taskModel

        VerticalScrollDecorator {}

        PullDownMenu {
            MenuItem {
                text: qsTr("Disconnect")
                onClicked: {
                    settingsManager.clear();
                    pageStack.replace(Qt.resolvedUrl("LoginPage.qml"));
                }
            }

            MenuItem {
                text: qsTr("Refresh")
                onClicked: vikunjaApi.fetchTasks(currentProjectId)
            }

            MenuItem {
                text: qsTr("Select Project...")
                onClicked: {
                    pageStack.push(projectSelectComponent);
                }
            }

            MenuItem {
                text: qsTr("Add Task")
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("AddEditTaskDialog.qml"), {
                        "initialProjectId": currentProjectId
                    });
                }
            }
        }

        header: PageHeader {
            title: currentProjectTitle
            extraContent.children: [
                BusyIndicator {
                    running: vikunjaApi.busy
                    size: BusyIndicatorSize.Small
                    anchors.verticalCenter: parent.verticalCenter
                }
            ]
        }

        delegate: ListItem {
            id: taskDelegate
            width: taskListView.width
            contentHeight: Theme.itemSizeSmall

            function toggleStatus() {
                vikunjaApi.updateTask(id, !done, title, description, dueDate);
                taskModel.updateTaskStatus(id, !done);
            }

            function deleteTask() {
                vikunjaApi.deleteTask(id);
            }

            menu: ContextMenu {
                MenuItem {
                    text: done ? qsTr("Mark Active") : qsTr("Mark Completed")
                    onClicked: toggleStatus()
                }
                MenuItem {
                    text: qsTr("Delete")
                    onClicked: {
                        remorseAction(qsTr("Deleting task"), function() {
                            deleteTask();
                        });
                    }
                }
            }

            onClicked: {
                pageStack.push(Qt.resolvedUrl("TaskDetailPage.qml"), {
                    "taskId": id,
                    "taskIndex": index
                });
            }

            Switch {
                id: doneSwitch
                anchors.left: parent.left
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                checked: done
                onClicked: toggleStatus()
            }

            Label {
                id: titleLabel
                text: title
                textFormat: Text.PlainText
                anchors.left: doneSwitch.right
                anchors.leftMargin: Theme.paddingMedium
                anchors.verticalCenter: parent.verticalCenter
                color: done ? Theme.secondaryColor : (priority >= 3 ? "red" : (priority === 2 ? "orange" : Theme.primaryColor))
                font.pixelSize: Theme.fontSizeMedium
                font.strikeout: done
                elide: Text.ElideRight
                // Prioritize title: let it take as much space as it needs, up to the full remaining screen width (no eliding for metadata space)
                width: Math.min(implicitWidth, parent.width - doneSwitch.width - Theme.horizontalPageMargin * 2 - Theme.paddingMedium)
            }

            Item {
                id: metaContainer
                anchors.left: titleLabel.right
                anchors.leftMargin: Theme.paddingMedium
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                clip: true // Automatically crops metadata on the left when squeezed by a long title
                visible: (labels && labels.length > 0) || (percentDone > 0) || (dueDate !== "" && dueDate.indexOf("0001-01-01") !== 0)

                Row {
                    id: metaRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.paddingSmall

                    // Labels badges
                    Row {
                        spacing: Theme.paddingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        visible: labels && labels.length > 0
                        Repeater {
                            model: labels
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

                    // Progress Badge
                    Rectangle {
                        visible: percentDone > 0
                        width: progressText.implicitWidth + Theme.paddingSmall
                        height: progressText.implicitHeight + Theme.paddingSmall / 2
                        radius: 4
                        color: "transparent"
                        border.color: Theme.highlightColor
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        Label {
                            id: progressText
                            text: Math.round(percentDone) + "%"
                            font.pixelSize: Theme.fontSizeTiny
                            font.bold: true
                            color: Theme.highlightColor
                            anchors.centerIn: parent
                        }
                    }

                    // Due Date Label
                    Label {
                        id: dueDateLabel
                        text: (dueDate !== "" && dueDate.indexOf("0001-01-01") !== 0) ? "📅 " + dueDate.substring(5, 10) : ""
                        textFormat: Text.PlainText
                        color: {
                            if (done) return Theme.secondaryColor;
                            var due = new Date(dueDate);
                            var now = new Date();
                            if (due < now) return Theme.errorColor;
                            return Theme.highlightColor;
                        }
                        font.pixelSize: Theme.fontSizeTiny
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                        visible: dueDate !== "" && dueDate.indexOf("0001-01-01") !== 0
                    }
                }
            }
        }

        ViewPlaceholder {
            enabled: taskListView.count === 0 && !vikunjaApi.busy
            text: qsTr("No tasks found")
            hintText: qsTr("Pull down to add a new task or refresh")
        }
    }

    Component {
        id: projectSelectComponent
        Page {
            allowedOrientations: defaultAllowedOrientations
            Connections {
                target: vikunjaApi
                onProjectsReceived: {
                    projModel.clear();
                    // First option is "All Projects"
                    projModel.append({ "projId": 0, "projTitle": qsTr("All Projects") });
                    for (var i = 0; i < projects.length; ++i) {
                        projModel.append({ "projId": projects[i].id, "projTitle": projects[i].title });
                    }
                }
            }
            SilicaListView {
                anchors.fill: parent
                header: PageHeader { title: qsTr("Select Project") }
                model: ListModel {
                    id: projModel
                    Component.onCompleted: {
                        vikunjaApi.fetchProjects();
                    }
                }
                delegate: BackgroundItem {
                    width: parent.width
                    Label {
                        text: projTitle
                        color: highlighted ? Theme.highlightColor : Theme.primaryColor
                        x: Theme.paddingLarge
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    onClicked: {
                        overviewPage.currentProjectId = projId;
                        overviewPage.currentProjectTitle = projTitle;
                        vikunjaApi.fetchTasks(projId);
                        pageStack.pop();
                    }
                }
            }
        }
    }
}
