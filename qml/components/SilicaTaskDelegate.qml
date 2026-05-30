import QtQuick 2.0
import Sailfish.Silica 1.0

ListItem {
    id: taskDelegate
    width: ListView.view ? ListView.view.width : parent.width
    contentHeight: Math.max(column.height + Theme.paddingMedium * 2, Theme.itemSizeNormal)
    height: contentHeight

    // Swipe to toggle done status
    property real startX: 0
    onPressed: startX = mouse.x
    onReleased: {
        var diffX = mouse.x - startX
        if (Math.abs(diffX) > 120) {
            statusToggled()
        }
    }

    signal clicked()
    signal statusToggled()
    signal deleteClicked()

    menu: ContextMenu {
        MenuItem {
            text: done ? qsTr("Mark Active") : qsTr("Mark Completed")
            onClicked: statusToggled()
        }
        MenuItem {
            text: qsTr("Delete")
            onClicked: {
                remorseAction(qsTr("Deleting task"), function() {
                    deleteClicked();
                });
            }
        }
    }

    onClicked: taskDelegate.clicked()

    // Beautiful custom check box
    BackgroundItem {
        id: checkbox
        x: Theme.paddingLarge
        width: Theme.iconSizeMedium
        height: Theme.iconSizeMedium
        y: (parent.height - height) / 2
        
        onClicked: statusToggled()

        Rectangle {
            anchors.centerIn: parent
            width: Theme.iconSizeMedium - Theme.paddingSmall
            height: Theme.iconSizeMedium - Theme.paddingSmall
            radius: Theme.paddingSmall / 2
            border.color: done ? Theme.highlightColor : Theme.secondaryColor
            border.width: 2
            color: "transparent"

            // Inner check indicator
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 8
                height: parent.height - 8
                radius: Math.max(0, parent.radius - 2)
                color: Theme.highlightColor
                visible: done
            }
        }
    }

    Column {
        id: column
        x: Theme.paddingLarge + Theme.iconSizeMedium + Theme.paddingMedium
        width: parent.width - x - Theme.paddingLarge
        y: Theme.paddingMedium
        spacing: 2

        Label {
            id: titleLabel
            text: title
            textFormat: Text.PlainText
            width: parent.width
            color: done ? Theme.secondaryColor : Theme.primaryColor
            font.pixelSize: Theme.fontSizeMedium
            font.strikeout: done
            elide: Text.ElideRight
            wrapMode: Text.NoWrap

            Behavior on color {
                ColorAnimation { duration: 200 }
            }
        }

        Item {
            id: detailsContainer
            width: parent.width
            height: (description !== "" || dueDate !== "") ? Math.max(descriptionLabel.implicitHeight, dueDateLabel.implicitHeight) : 0
            visible: description !== "" || dueDate !== ""

            Label {
                id: descriptionLabel
                text: description
                textFormat: Text.PlainText
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                width: parent.width - (dueDateLabel.visible ? dueDateLabel.width + Theme.paddingSmall : 0)
                elide: Text.ElideRight
                visible: description !== ""
            }

            Label {
                id: dueDateLabel
                text: dueDate !== "" ? "📅 " + dueDate.substring(0, 10) : ""
                textFormat: Text.PlainText
                color: {
                    if (done) return Theme.secondaryColor;
                    // Check if overdue
                    var due = new Date(dueDate);
                    var now = new Date();
                    if (due < now) return Theme.errorColor;
                    return Theme.highlightColor;
                }
                font.pixelSize: Theme.fontSizeExtraSmall
                font.bold: true
                x: parent.width - width
                visible: dueDate !== ""
            }
        }
    }
}


