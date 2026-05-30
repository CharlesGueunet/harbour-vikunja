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
        // Initial fetch of tasks for the active project
        vikunjaApi.fetchTasks(currentProjectId);
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
                    var dialog = pageStack.push(Qt.resolvedUrl("AddEditTaskDialog.qml"), {
                        "initialProjectId": currentProjectId > 0 ? currentProjectId : 1
                    });
                    dialog.accepted.connect(function() {
                        vikunjaApi.fetchTasks(currentProjectId);
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
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                color: done ? Theme.secondaryColor : Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
                font.strikeout: done
                elide: Text.ElideRight
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
                        currentProjectId = projId;
                        currentProjectTitle = projTitle;
                        vikunjaApi.fetchTasks(projId);
                        pageStack.pop();
                    }
                }
            }
        }
    }
}
