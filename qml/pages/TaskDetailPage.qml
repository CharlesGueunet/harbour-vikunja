import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: detailPage
    allowedOrientations: defaultAllowedOrientations

    property int taskId
    property int taskIndex

    // Reactively extract details from the taskModel
    property var taskData: taskModel.getTask(taskIndex)

    property bool commentSubmitting: false

    onStatusChanged: {
        if (status === PageStatus.Active) {
            vikunjaApi.fetchTask(detailPage.taskId);
            vikunjaApi.fetchComments(detailPage.taskId);
        }
    }

    Component.onCompleted: {
        vikunjaApi.taskUpdated.connect(detailPage.handleTaskUpdated);
        vikunjaApi.taskReceived.connect(detailPage.handleTaskReceived);
        vikunjaApi.tasksReceived.connect(detailPage.handleTasksReceived);
        vikunjaApi.labelAssociated.connect(detailPage.handleLabelUpdated);
        vikunjaApi.labelDissociated.connect(detailPage.handleLabelUpdated);
        vikunjaApi.commentsReceived.connect(detailPage.handleCommentsReceived);
        vikunjaApi.commentCreated.connect(detailPage.handleCommentCreated);
    }

    Component.onDestruction: {
        vikunjaApi.taskUpdated.disconnect(detailPage.handleTaskUpdated);
        vikunjaApi.taskReceived.disconnect(detailPage.handleTaskReceived);
        vikunjaApi.tasksReceived.disconnect(detailPage.handleTasksReceived);
        vikunjaApi.labelAssociated.disconnect(detailPage.handleLabelUpdated);
        vikunjaApi.labelDissociated.disconnect(detailPage.handleLabelUpdated);
        vikunjaApi.commentsReceived.disconnect(detailPage.handleCommentsReceived);
        vikunjaApi.commentCreated.disconnect(detailPage.handleCommentCreated);
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

    function handleCommentsReceived(tId, comments) {
        if (tId === detailPage.taskId) {
            commentsModel.clear();
            for (var i = 0; i < comments.length; ++i) {
                var c = comments[i];
                var authorName = "";
                var authorUsername = "";
                if (c.author) {
                    authorName = c.author.name || "";
                    authorUsername = c.author.username || "";
                }
                commentsModel.append({
                    "commentId": c.id,
                    "commentText": c.comment || "",
                    "createdAt": c.created || "",
                    "authorName": authorName,
                    "authorUsername": authorUsername
                });
            }
        }
    }

    function handleCommentCreated(tId, success, errorMsg) {
        if (tId === detailPage.taskId) {
            commentSubmitting = false;
            if (success) {
                newCommentTextArea.text = "";
                vikunjaApi.fetchComments(detailPage.taskId);
            }
        }
    }

    function formatCommentDate(dateStr) {
        if (!dateStr || dateStr === "") return "";
        var datePart = dateStr.substring(0, 10);
        var timePart = dateStr.substring(11, 16);
        return datePart + " " + timePart;
    }

    ListModel {
        id: commentsModel
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
                        "taskIndex": taskIndex,
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

            BackgroundItem {
                id: labelsDetailItem
                width: parent.width
                height: Math.max(detailLabel.implicitHeight, (taskData.labels && taskData.labels.length > 0) ? labelBadgesFlow.implicitHeight : noneLabel.implicitHeight) + Theme.paddingMedium * 2

                onClicked: {
                    pageStack.push(Qt.resolvedUrl("SelectLabelsPage.qml"), {
                        "taskId": taskId,
                        "taskIndex": taskIndex,
                        "taskLabels": taskData.labels || []
                    });
                }

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
                    visible: taskData.labels && taskData.labels.length > 0

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

                Label {
                    id: noneLabel
                    text: qsTr("None")
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.left: detailLabel.right
                    anchors.leftMargin: Theme.paddingLarge
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !taskData.labels || taskData.labels.length === 0
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

            SectionHeader {
                text: commentsModel.count > 0 ? qsTr("Comments (%1)").arg(commentsModel.count) : qsTr("Comments")
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("No comments yet")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                visible: commentsModel.count === 0
            }

            Repeater {
                model: commentsModel
                delegate: Item {
                    width: parent.width
                    height: commentRow.height + Theme.paddingMedium

                    Row {
                        id: commentRow
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.paddingMedium

                        // Avatar
                        Rectangle {
                            id: avatarRect
                            width: Theme.iconSizeMedium
                            height: Theme.iconSizeMedium
                            radius: width / 2
                            color: Theme.secondaryHighlightColor
                            clip: true

                            Image {
                                id: avatarImg
                                anchors.fill: parent
                                source: (authorUsername !== "") ? (settingsManager.serverUrl + (settingsManager.serverUrl.endsWith("/") ? "" : "/") + "api/v1/avatar/" + authorUsername) : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                            }

                            Label {
                                anchors.centerIn: parent
                                text: {
                                    if (authorName) {
                                        var parts = authorName.split(" ");
                                        if (parts.length >= 2) {
                                            return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
                                        }
                                        return authorName.substring(0, 2).toUpperCase();
                                    } else if (authorUsername) {
                                        return authorUsername.substring(0, 2).toUpperCase();
                                    }
                                    return "?";
                                }
                                color: Theme.primaryColor
                                font.bold: true
                                font.pixelSize: Theme.fontSizeSmall
                                visible: avatarImg.status !== Image.Ready
                            }
                        }

                        // Right side: Name row and bubble containing the comment text
                        Column {
                            id: rightColumn
                            width: parent.width - avatarRect.width - commentRow.spacing
                            spacing: Theme.paddingSmall

                            Row {
                                id: headerRow
                                width: parent.width
                                spacing: Theme.paddingSmall

                                Label {
                                    text: authorName !== "" ? authorName : authorUsername
                                    color: Theme.primaryColor
                                    font.bold: true
                                    font.pixelSize: Theme.fontSizeSmall
                                    truncationMode: TruncationMode.Fade
                                    width: Math.min(implicitWidth, parent.width * 0.5)
                                }

                                Label {
                                    text: authorName !== "" ? "@" + authorUsername : ""
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeTiny
                                    visible: authorName !== "" && authorUsername !== ""
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Label {
                                    text: formatCommentDate(createdAt)
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeTiny
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle {
                                id: bubbleRect
                                width: parent.width
                                height: commentTextLabel.implicitHeight + Theme.paddingMedium * 2
                                color: Theme.rgba(Theme.primaryColor, 0.05)
                                border.color: Theme.rgba(Theme.primaryColor, 0.1)
                                border.width: 1
                                radius: 8

                                Label {
                                    id: commentTextLabel
                                    anchors.fill: parent
                                    anchors.margins: Theme.paddingMedium
                                    text: commentText
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeSmall
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
            }

            SectionHeader {
                text: qsTr("Add Comment")
            }

            Column {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingMedium

                TextArea {
                    id: newCommentTextArea
                    width: parent.width
                    placeholderText: qsTr("Write a comment...")
                    label: qsTr("New Comment")
                    wrapMode: TextEdit.Wrap
                }

                Row {
                    width: parent.width
                    spacing: Theme.paddingMedium
                    layoutDirection: Qt.RightToLeft

                    Button {
                        id: submitButton
                        text: qsTr("Comment")
                        enabled: newCommentTextArea.text.replace(/^\s+|\s+$/g, '') !== "" && !commentSubmitting
                        onClicked: {
                            commentSubmitting = true;
                            vikunjaApi.createComment(detailPage.taskId, newCommentTextArea.text);
                        }
                    }

                    BusyIndicator {
                        running: commentSubmitting
                        visible: commentSubmitting
                        size: BusyIndicatorSize.Small
                        anchors.verticalCenter: submitButton.verticalCenter
                    }
                }
            }
        }

        RemorsePopup {
            id: remorse
        }
    }
}
