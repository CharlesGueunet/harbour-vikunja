import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: taskDialog
    allowedOrientations: defaultAllowedOrientations

    property bool isEdit: false
    property int taskId: -1
    property string initialTitle: ""
    property string initialDescription: ""
    property string initialDueDate: ""
    property bool initialDone: false
    property int initialProjectId: 1

    property string dueDate: initialDueDate
    property int taskIndex: -1
    property var taskData: isEdit && taskIndex >= 0 ? taskModel.getTask(taskIndex) : null

    property int selectedProjectId: initialProjectId
    property string selectedProjectTitle: qsTr("Loading...")

    // Retrieve active projects list from the API
    Connections {
        target: vikunjaApi
        onProjectsReceived: {
            if (projects.length > 0) {
                // Always try to match the initialProjectId first (works for both new and edit)
                var matched = false;
                for (var i = 0; i < projects.length; ++i) {
                    if (projects[i].id === initialProjectId) {
                        selectedProjectId = projects[i].id;
                        selectedProjectTitle = projects[i].title;
                        matched = true;
                        break;
                    }
                }
                // Only fall back to projects[0] if no match found (e.g. initialProjectId=0)
                if (!matched) {
                    selectedProjectId = projects[0].id;
                    selectedProjectTitle = projects[0].title;
                }
            }
        }
    }

    Component.onCompleted: {
        vikunjaApi.fetchProjects();
        if (isEdit) {
            titleField.text = initialTitle;
            descriptionField.text = initialDescription;
            dueDate = initialDueDate;
            vikunjaApi.taskReceived.connect(taskDialog.handleTaskReceived);
        }
    }

    Component.onDestruction: {
        if (isEdit) {
            vikunjaApi.taskReceived.disconnect(taskDialog.handleTaskReceived);
        }
    }

    function handleTaskReceived(tId, task) {
        if (tId === taskId) {
            taskData = taskModel.getTask(taskIndex);
        }
    }

    onAccepted: {
        if (isEdit) {
            vikunjaApi.updateTask(taskId, initialDone, titleField.text, descriptionField.text, dueDate);
            taskModel.updateTaskStatus(taskId, initialDone);
        } else {
            vikunjaApi.createTask(selectedProjectId, titleField.text, descriptionField.text, dueDate);
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: dialogColumn.height + Theme.paddingLarge

        Column {
            id: dialogColumn
            width: parent.width
            spacing: Theme.paddingLarge

            DialogHeader {
                title: isEdit ? qsTr("Edit Task") : qsTr("New Task")
                acceptText: isEdit ? qsTr("Save") : qsTr("Create")
            }

            TextField {
                id: titleField
                width: parent.width - 2 * Theme.paddingLarge
                anchors.horizontalCenter: parent.horizontalCenter
                label: qsTr("Task Title")
                placeholderText: qsTr("What needs to be done?")
                focus: true
                EnterKey.enabled: text.length > 0
                EnterKey.onClicked: descriptionField.focus = true
            }

            TextArea {
                id: descriptionField
                width: parent.width - 2 * Theme.paddingLarge
                anchors.horizontalCenter: parent.horizontalCenter
                label: qsTr("Description")
                placeholderText: qsTr("Add more details...")
            }

            ValueButton {
                label: qsTr("Due Date")
                value: (dueDate !== "" && dueDate.indexOf("0001-01-01") !== 0) ? dueDate.substring(0, 10) : qsTr("None")
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.paddingLarge
                
                onClicked: {
                    var dialog = pageStack.push("Sailfish.Silica.DatePickerDialog", {
                        date: (dueDate !== "" && dueDate.indexOf("0001-01-01") !== 0) ? new Date(dueDate) : new Date()
                    });
                    dialog.accepted.connect(function() {
                        // Vikunja expects due_date in ISO 8601 format
                        dueDate = dialog.date.toISOString();
                    });
                }
            }

            ValueButton {
                label: qsTr("Project")
                value: selectedProjectTitle
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.paddingLarge
                enabled: !isEdit // Only allow changing project on creation for simplicity
                
                onClicked: {
                    pageStack.push(projectSelectComponent);
                }
            }

            ValueButton {
                label: qsTr("Labels")
                value: (isEdit && taskData && taskData.labels && taskData.labels.length > 0) ? (taskData.labels.map(function(l) { return l.title; }).join(", ")) : qsTr("None")
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.paddingLarge
                visible: isEdit

                onClicked: {
                    pageStack.push(Qt.resolvedUrl("SelectLabelsPage.qml"), {
                        "taskId": taskId,
                        "taskIndex": taskIndex,
                        "taskLabels": taskData.labels || []
                    });
                }
            }
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
                        selectedProjectId = projId;
                        selectedProjectTitle = projTitle;
                        pageStack.pop();
                    }
                }
            }
        }
    }
}

