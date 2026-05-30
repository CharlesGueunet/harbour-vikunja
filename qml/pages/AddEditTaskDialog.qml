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

    property int selectedProjectId: initialProjectId
    property string selectedProjectTitle: qsTr("Default Project")

    // Retrieve active projects list from the API
    Connections {
        target: vikunjaApi
        onProjectsReceived: {
            if (projects.length > 0) {
                // If not editing, default to the first project
                if (!isEdit) {
                    selectedProjectId = projects[0].id;
                    selectedProjectTitle = projects[0].title;
                } else {
                    // Match initial project
                    for (var i = 0; i < projects.length; ++i) {
                        if (projects[i].id === initialProjectId) {
                            selectedProjectTitle = projects[i].title;
                            break;
                        }
                    }
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
        }
    }

    onAccepted: {
        if (isEdit) {
            vikunjaApi.updateTask(taskId, initialDone, titleField.text, descriptionField.text, dueDate);
            taskModel.updateTaskStatus(taskId, initialDone);
        } else {
            console.log("[AddEditTaskDialog] Submitting createTask with projId:", selectedProjectId, "title:", titleField.text)
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
                value: dueDate !== "" ? dueDate.substring(0, 10) : qsTr("None")
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.paddingLarge
                
                onClicked: {
                    var dialog = pageStack.push("Sailfish.Silica.DatePickerDialog", {
                        date: dueDate !== "" ? new Date(dueDate) : new Date()
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

