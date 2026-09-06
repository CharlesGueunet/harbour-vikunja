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

    property bool isSaving: false
    property bool isServerConfirmed: false
    property string errorMessage: ""

    canAccept: isServerConfirmed

    onAcceptBlocked: {
        if (!isSaving && titleField.text.trim().length > 0) {
            saveTask();
        }
    }

    onRejected: {
        if (isSaving) {
            isSaving = false;
            saveTimeoutTimer.stop();
        }
        if (!isEdit && !isServerConfirmed) {
            if (titleField.text.trim().length > 0 || descriptionField.text.trim().length > 0) {
                if (typeof appWindow !== "undefined" && appWindow) {
                    appWindow.taskDraft = {
                        "title": titleField.text,
                        "description": descriptionField.text,
                        "dueDate": dueDate,
                        "projectId": selectedProjectId
                    };
                }
            } else {
                if (typeof appWindow !== "undefined" && appWindow) {
                    appWindow.taskDraft = null;
                }
            }
        }
    }

    // Retrieve active projects list from the API and listen to task creation / update status
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
        onTaskCreated: {
            if (!isEdit && isSaving) {
                saveTimeoutTimer.stop();
                if (success) {
                    isSaving = false;
                    isServerConfirmed = true;
                    if (typeof appWindow !== "undefined" && appWindow && appWindow.taskDraft) {
                        appWindow.taskDraft = null;
                    }
                    taskDialog.accept();
                } else {
                    isSaving = false;
                    errorMessage = errorMsg ? errorMsg : qsTr("Failed to create task");
                }
            }
        }
        onTaskUpdated: {
            if (isEdit && isSaving && taskId === taskDialog.taskId) {
                saveTimeoutTimer.stop();
                if (success) {
                    isSaving = false;
                    isServerConfirmed = true;
                    taskDialog.accept();
                } else {
                    isSaving = false;
                    errorMessage = errorMsg ? errorMsg : qsTr("Failed to update task");
                }
            }
        }
    }

    Component.onCompleted: {
        vikunjaApi.fetchProjects();
        if (isEdit) {
            titleField.text = initialTitle;
            descriptionField.text = htmlToMarkdown(initialDescription);
            dueDate = initialDueDate;
            vikunjaApi.taskReceived.connect(taskDialog.handleTaskReceived);
        } else if (typeof appWindow !== "undefined" && appWindow && appWindow.taskDraft) {
            if (appWindow.taskDraft.title) titleField.text = appWindow.taskDraft.title;
            if (appWindow.taskDraft.description) descriptionField.text = appWindow.taskDraft.description;
            if (appWindow.taskDraft.dueDate) dueDate = appWindow.taskDraft.dueDate;
            if (appWindow.taskDraft.projectId) {
                initialProjectId = appWindow.taskDraft.projectId;
                selectedProjectId = appWindow.taskDraft.projectId;
            }
        }
    }

    Component.onDestruction: {
        saveTimeoutTimer.stop();
        if (isEdit) {
            vikunjaApi.taskReceived.disconnect(taskDialog.handleTaskReceived);
        }
    }

    function handleTaskReceived(tId, task) {
        if (tId === taskId) {
            taskData = taskModel.getTask(taskIndex);
        }
    }

    function htmlToMarkdown(html) {
        if (!html || html === "") return "";
        var res = html;

        // 1. Convert checklist items (specific to Vikunja Tiptap HTML editor format)
        res = res.replace(/<li\s+data-checked="false"[^>]*>\s*<label>\s*<input[^>]*>\s*<span>\s*<\/span>\s*<\/label>\s*<div>\s*<p>([\s\S]*?)<\/p>\s*<\/div>\s*<\/li>/gi, "- [ ] $1\n");
        res = res.replace(/<li\s+data-checked="true"[^>]*>\s*<label>\s*<input[^>]*>\s*<span>\s*<\/span>\s*<\/label>\s*<div>\s*<p>([\s\S]*?)<\/p>\s*<\/div>\s*<\/li>/gi, "- [x] $1\n");

        // Fallback for HTML checklists without label/input wrapper
        res = res.replace(/<li\s+data-checked="false"[^>]*>\s*(?:<p>)?([\s\S]*?)(?:<\/p>)?\s*<\/li>/gi, "- [ ] $1\n");
        res = res.replace(/<li\s+data-checked="true"[^>]*>\s*(?:<p>)?([\s\S]*?)(?:<\/p>)?\s*<\/li>/gi, "- [x] $1\n");

        // 2. Convert standard list items
        res = res.replace(/<li>([\s\S]*?)<\/li>/gi, "- $1\n");
        res = res.replace(/<ul[^>]*>/gi, "");
        res = res.replace(/<\/ul>/gi, "\n");
        res = res.replace(/<ol[^>]*>/gi, "");
        res = res.replace(/<\/ol>/gi, "\n");

        // 3. Convert headers
        res = res.replace(/<h1[^>]*>([\s\S]*?)<\/h1>/gi, "# $1\n\n");
        res = res.replace(/<h2[^>]*>([\s\S]*?)<\/h2>/gi, "## $1\n\n");
        res = res.replace(/<h3[^>]*>([\s\S]*?)<\/h3>/gi, "### $1\n\n");
        res = res.replace(/<h4[^>]*>([\s\S]*?)<\/h4>/gi, "#### $1\n\n");

        // 4. Convert paragraphs & line breaks
        res = res.replace(/<p>\s*<\/p>/gi, "\n");
        res = res.replace(/<p>([\s\S]*?)<\/p>/gi, "$1\n\n");
        res = res.replace(/<br\s*\/?>/gi, "\n");

        // 5. Convert formatting tags
        res = res.replace(/<strong[^>]*>([\s\S]*?)<\/strong>/gi, "**$1**");
        res = res.replace(/<b[^>]*>([\s\S]*?)<\/b>/gi, "**$1**");
        res = res.replace(/<em[^>]*>([\s\S]*?)<\/em>/gi, "*$1*");
        res = res.replace(/<i[^>]*>([\s\S]*?)<\/i>/gi, "*$1*");
        res = res.replace(/<code[^>]*>([\s\S]*?)<\/code>/gi, "`$1`");

        // 6. Convert links
        res = res.replace(/<a\s+href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/gi, "[$2]($1)");

        // 7. Clean up extra spaces/newlines
        res = res.replace(/\n{3,}/g, "\n\n");
        res = res.trim();

        return res;
    }

    function markdownToHtml(md) {
        if (!md || md === "") return "";
        var lines = md.split(/\r?\n/);
        var html = "";
        var inTaskList = false;
        var inNormalList = false;

        function generateTaskId() {
            var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
            var result = '';
            for (var i = 0; i < 8; i++) {
                result += chars.charAt(Math.floor(Math.random() * chars.length));
            }
            return result;
        }

        // Helper to convert inline markdown to HTML (bold, italic, links, etc.)
        function convertInline(text) {
            var inline = text;
            // Bold
            inline = inline.replace(/\*\*([\s\S]*?)\*\*/g, "<strong>$1</strong>");
            inline = inline.replace(/__([\s\S]*?)__/g, "<strong>$1</strong>");
            // Italic
            inline = inline.replace(/\*([\s\S]*?)\*/g, "<em>$1</em>");
            inline = inline.replace(/_([\s\S]*?)_/g, "<em>$1</em>");
            // Code inline
            inline = inline.replace(/`([\s\S]*?)`/g, "<code>$1</code>");
            // Links
            inline = inline.replace(/\[([\s\S]*?)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
            return inline;
        }

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            
            // Check for checklist items: e.g., "- [ ] task" or "* [x] task"
            var taskMatch = line.match(/^\s*[-*+]\s+\[([ xX])\]\s*(.*)$/);
            if (taskMatch) {
                // If we were in a normal list, close it first
                if (inNormalList) {
                    html += "</ul>";
                    inNormalList = false;
                }
                // If not in task list, open it
                if (!inTaskList) {
                    html += '<ul data-type="taskList">';
                    inTaskList = true;
                }
                var checked = (taskMatch[1].toLowerCase() === 'x');
                var text = convertInline(taskMatch[2]);
                var taskId = generateTaskId();
                if (checked) {
                    html += '<li data-checked="true" data-task-id="' + taskId + '" data-type="taskItem">' +
                            '<label><input type="checkbox" checked="checked"><span></span></label>' +
                            '<div><p>' + text + '</p></div></li>';
                } else {
                    html += '<li data-checked="false" data-task-id="' + taskId + '" data-type="taskItem">' +
                            '<label><input type="checkbox"><span></span></label>' +
                            '<div><p>' + text + '</p></div></li>';
                }
                continue;
            }

            // Check for standard bullet list items: e.g., "- item" or "* item"
            var listMatch = line.match(/^\s*[-*+]\s+(.*)$/);
            if (listMatch) {
                // If we were in a task list, close it first
                if (inTaskList) {
                    html += "</ul>";
                    inTaskList = false;
                }
                // If not in a normal list, open it
                if (!inNormalList) {
                    html += "<ul>";
                    inNormalList = true;
                }
                var text = convertInline(listMatch[1]);
                html += "<li>" + text + "</li>";
                continue;
            }

            // Close any open lists if the line is not a list item
            if (inTaskList) {
                html += "</ul>";
                inTaskList = false;
            }
            if (inNormalList) {
                html += "</ul>";
                inNormalList = false;
            }

            // Check for headers
            var headerMatch = line.match(/^(#{1,6})\s+(.*)$/);
            if (headerMatch) {
                var level = headerMatch[1].length;
                var text = convertInline(headerMatch[2]);
                html += "<h" + level + ">" + text + "</h" + level + ">";
                continue;
            }

            // Paragraph or empty line
            var trimmed = line.trim();
            if (trimmed === "") {
                html += "<p></p>";
            } else {
                html += "<p>" + convertInline(line) + "</p>";
            }
        }

        // Close any remaining open lists
        if (inTaskList) {
            html += "</ul>";
        }
        if (inNormalList) {
            html += "</ul>";
        }

        return html;
    }

    onAccepted: {
        // Handled asynchronously in saveTask() via vikunjaApi confirmation
    }

    Timer {
        id: saveTimeoutTimer
        interval: 30000
        repeat: false
        onTriggered: {
            if (isSaving) {
                isSaving = false;
                errorMessage = qsTr("Server request timed out. Please check your network connection.");
            }
        }
    }

    function saveTask() {
        if (isSaving) return;
        var trimmedTitle = titleField.text.trim();
        if (trimmedTitle.length === 0) {
            errorMessage = qsTr("Task title cannot be empty");
            return;
        }

        titleField.focus = false;
        descriptionField.focus = false;

        errorMessage = "";
        isSaving = true;
        saveTimeoutTimer.restart();

        var htmlDescription = markdownToHtml(descriptionField.text);
        if (isEdit) {
            vikunjaApi.updateTask(taskId, initialDone, trimmedTitle, htmlDescription, dueDate);
        } else {
            vikunjaApi.createTask(selectedProjectId, trimmedTitle, htmlDescription, dueDate);
        }
    }

    Item {
        id: dialogProxy
        width: taskDialog.width
        property bool canAccept: !taskDialog.isSaving && titleField.text.trim().length > 0
        property bool isPortrait: taskDialog.isPortrait
        property int orientation: taskDialog.orientation
        property int _depth: taskDialog._depth
        property int _navigationPending: taskDialog._navigationPending
        property bool backNavigation: taskDialog.backNavigation
        property var background: taskDialog.background
        property int status: taskDialog.status
        property var _dialogHeader: null

        function accept() {
            taskDialog.saveTask();
        }
        function reject() {
            if (taskDialog.isSaving) {
                taskDialog.isSaving = false;
                saveTimeoutTimer.stop();
            }
            taskDialog.reject();
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
                id: dialogHeaderItem
                dialog: dialogProxy
                title: isEdit ? qsTr("Edit Task") : qsTr("New Task")
                acceptText: isSaving ? qsTr("Saving...") : (isEdit ? qsTr("Save") : qsTr("Create"))
                extraContent.children: [
                    BusyIndicator {
                        running: isSaving
                        size: BusyIndicatorSize.Small
                        anchors.verticalCenter: parent.verticalCenter
                    }
                ]
                Component.onCompleted: {
                    taskDialog._dialogHeader = dialogHeaderItem
                }
            }

            Rectangle {
                id: errorBanner
                visible: errorMessage !== ""
                width: parent.width - 2 * Theme.paddingLarge
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.rgba(Theme.highlightColor, 0.15)
                radius: Theme.paddingSmall
                height: visible ? (errorColumn.height + 2 * Theme.paddingMedium) : 0

                Column {
                    id: errorColumn
                    width: parent.width - 2 * Theme.paddingMedium
                    anchors.centerIn: parent
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Task was not accepted by the server")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: errorMessage
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            TextField {
                id: titleField
                enabled: !isSaving
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
                enabled: !isSaving
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
                enabled: !isSaving
                
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
                enabled: !isEdit && !isSaving
                
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
                enabled: !isSaving

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

