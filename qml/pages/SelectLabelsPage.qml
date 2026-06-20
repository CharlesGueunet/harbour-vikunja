import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: selectLabelsPage
    allowedOrientations: defaultAllowedOrientations

    property int taskId
    property int taskIndex
    property var taskLabels: []

    Component.onCompleted: {
        vikunjaApi.labelsReceived.connect(selectLabelsPage.handleLabelsReceived);
        vikunjaApi.taskReceived.connect(selectLabelsPage.handleTaskReceived);
        vikunjaApi.fetchLabels();
    }

    Component.onDestruction: {
        vikunjaApi.labelsReceived.disconnect(selectLabelsPage.handleLabelsReceived);
        vikunjaApi.taskReceived.disconnect(selectLabelsPage.handleTaskReceived);
    }

    function handleLabelsReceived(labels) {
        labelsModel.clear();
        for (var i = 0; i < labels.length; ++i) {
            labelsModel.append({
                "labelId": labels[i].id,
                "labelTitle": labels[i].title,
                "labelHexColor": labels[i].hex_color ? (labels[i].hex_color.indexOf("#") === 0 ? labels[i].hex_color : "#" + labels[i].hex_color) : Theme.secondaryColor
            });
        }
    }

    function handleTaskReceived(tId, task) {
        if (tId === taskId) {
            taskLabels = taskModel.getTask(taskIndex).labels || [];
        }
    }

    function isLabelAssociated(labelId) {
        for (var i = 0; i < taskLabels.length; ++i) {
            if (taskLabels[i].id === labelId) {
                return true;
            }
        }
        return false;
    }

    SilicaListView {
        anchors.fill: parent
        header: PageHeader {
            title: qsTr("Edit Labels")
            extraContent.children: [
                BusyIndicator {
                    running: vikunjaApi.busy
                    size: BusyIndicatorSize.Small
                    anchors.verticalCenter: parent.verticalCenter
                }
            ]
        }

        model: ListModel {
            id: labelsModel
        }

        delegate: BackgroundItem {
            id: delegateItem
            width: parent.width
            height: Theme.itemSizeSmall

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.right: statusSwitch.left
                anchors.rightMargin: Theme.paddingMedium
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingMedium

                Rectangle {
                    width: Theme.paddingLarge
                    height: Theme.paddingLarge
                    radius: 4
                    color: labelHexColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                Label {
                    text: labelTitle
                    color: delegateItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                    elide: Text.ElideRight
                    width: parent.width - Theme.paddingLarge - Theme.paddingMedium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Switch {
                id: statusSwitch
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                checked: isLabelAssociated(labelId)

                // Prevent automatic binding loop and only trigger on user interaction
                onClicked: {
                    if (checked) {
                        vikunjaApi.associateLabel(taskId, labelId);
                    } else {
                        vikunjaApi.dissociateLabel(taskId, labelId);
                    }
                }
            }
        }

        ViewPlaceholder {
            enabled: labelsModel.count === 0 && !vikunjaApi.busy
            text: qsTr("No labels found")
            hintText: qsTr("Create labels in your Vikunja web interface")
        }
    }
}
