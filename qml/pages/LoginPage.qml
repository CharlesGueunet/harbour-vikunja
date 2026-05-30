import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: loginPage
    allowedOrientations: defaultAllowedOrientations

    Connections {
        target: vikunjaApi
        onConnectionTested: {
            if (success) {
                settingsManager.serverUrl = serverUrlField.text;
                settingsManager.apiToken = tokenField.text;
                pageStack.replace(Qt.resolvedUrl("TaskOverviewPage.qml"));
            } else {
                errorLabel.text = errorMessage;
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Setup Vikunja")
            }

            Rectangle {
                width: parent.width - 2 * Theme.paddingLarge
                height: 120
                color: "transparent"
                anchors.horizontalCenter: parent.horizontalCenter

                Label {
                    text: "✓"
                    font.pixelSize: 80
                    color: Theme.highlightColor
                    anchors.centerIn: parent
                    opacity: 0.8
                }
            }

            TextField {
                id: serverUrlField
                width: parent.width - Theme.paddingLarge * 2
                anchors.horizontalCenter: parent.horizontalCenter
                label: qsTr("Server URL")
                placeholderText: "https://vikunja.example.com"
                text: settingsManager.serverUrl !== "" ? settingsManager.serverUrl : "https://demo.vikunja.io"
                inputMethodHints: Qt.ImhUrlCharactersOnly
                EnterKey.enabled: text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: tokenField.focus = true
            }

            TextField {
                id: tokenField
                width: parent.width - Theme.paddingLarge * 2
                anchors.horizontalCenter: parent.horizontalCenter
                label: qsTr("API Token")
                placeholderText: qsTr("Enter your Vikunja API Token")
                text: settingsManager.apiToken
                inputMethodHints: Qt.ImhNoPredictiveText
                EnterKey.enabled: text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: loginButton.clicked()
            }

            Label {
                id: errorLabel
                width: parent.width - Theme.paddingLarge * 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Button {
                id: loginButton
                anchors.horizontalCenter: parent.horizontalCenter
                text: vikunjaApi.busy ? qsTr("Connecting...") : qsTr("Connect")
                enabled: !vikunjaApi.busy && serverUrlField.text.length > 0 && tokenField.text.length > 0
                
                onClicked: {
                    errorLabel.text = "";
                    vikunjaApi.testConnection(serverUrlField.text, tokenField.text);
                }
            }

            BusyIndicator {
                running: vikunjaApi.busy
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
