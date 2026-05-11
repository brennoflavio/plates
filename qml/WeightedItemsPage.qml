import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtQuick 2.7
import "ut_components"

Page {
    id: weightedItemsPage

    property var navigationRoot: null
    property string pageTitle: ""
    property string singularLabel: ""
    property string itemsKey: ""
    property string currentSection: ""
    property string emptyMessage: ""
    property bool showNameField: true
    property bool hasLoaded: false

    function displayItemLabel(itemName, itemWeight) {
        if (showNameField)
            return itemName;

        return i18n.tr("%1 kg").arg(itemWeight);
    }

    function loadItems() {
        if (!navigationRoot || !navigationRoot.loadItems)
            return;

        navigationRoot.loadItems(itemsKey, function(result) {
            var items = result && result.items ? result.items : [];

            itemModel.clear();
            for (var index = 0; index < items.length; index++) {
                itemModel.append({
                    "itemName": items[index].itemName,
                    "itemWeight": items[index].itemWeight
                });
            }

            hasLoaded = true;
        });
    }

    function persistItems() {
        if (!navigationRoot || !navigationRoot.saveItems)
            return;

        var storedItems = [];

        for (var index = 0; index < itemModel.count; index++) {
            var item = itemModel.get(index);
            storedItems.push({
                "itemName": item.itemName,
                "itemWeight": item.itemWeight
            });
        }

        navigationRoot.saveItems(itemsKey, storedItems);
    }

    function deleteItem(index) {
        if (index < 0 || index >= itemModel.count)
            return;

        itemModel.remove(index, 1);
        persistItems();
    }

    function updateItem(index, itemName, itemWeight) {
        if (index < 0 || index >= itemModel.count)
            return;

        itemModel.setProperty(index, "itemName", itemName);
        itemModel.setProperty(index, "itemWeight", itemWeight);
        persistItems();
    }

    function addItem(itemName, itemWeight) {
        itemModel.append({
            "itemName": itemName,
            "itemWeight": itemWeight
        });
        persistItems();
    }

    Component.onCompleted: {
        if (navigationRoot && navigationRoot.backendReady)
            loadItems();
    }

    Connections {
        target: navigationRoot

        function onBackendReadyChanged() {
            if (navigationRoot.backendReady && !hasLoaded)
                weightedItemsPage.loadItems();
        }
    }

    header: AppHeader {
        id: header

        pageTitle: weightedItemsPage.pageTitle
        isRootPage: true
        appIconName: "calculator-app-symbolic"
    }

    ListModel {
        id: itemModel
    }

    ListView {
        id: itemsList

        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: addItemButton.top
            bottomMargin: units.gu(2)
        }
        model: itemModel
        clip: true

        delegate: ListItem {
            width: itemsList.width
            height: itemLayout.height + (separator.visible ? separator.height : 0)
            divider.visible: false

            ListItemLayout {
                id: itemLayout

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                title.text: displayItemLabel(itemName, itemWeight)
                subtitle.text: showNameField ? i18n.tr("%1 kg").arg(itemWeight) : ""
            }

            Rectangle {
                id: separator

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: units.dp(1)
                color: theme.palette.normal.base
                visible: index < itemModel.count - 1
            }

            leadingActions: ListItemActions {
                actions: [
                    Action {
                        iconName: "delete"
                        text: i18n.tr("Delete")
                        onTriggered: {
                            PopupUtils.open(deleteItemDialog, null, {
                                "itemIndex": index,
                                "itemLabel": weightedItemsPage.displayItemLabel(itemName, itemWeight)
                            });
                        }
                    }
                ]
            }

            trailingActions: ListItemActions {
                actions: [
                    Action {
                        iconName: "edit"
                        text: i18n.tr("Edit")
                        onTriggered: {
                            PopupUtils.open(itemDialog, null, {
                                "itemIndex": index,
                                "itemName": itemName,
                                "itemWeight": itemWeight
                            });
                        }
                    }
                ]
            }
        }
    }

    Label {
        visible: hasLoaded && itemModel.count === 0
        anchors.centerIn: parent
        text: emptyMessage
    }

    ActionButton {
        id: addItemButton

        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: bottomBar.top
            bottomMargin: units.gu(2)
        }
        text: i18n.tr("Add %1").arg(singularLabel)
        iconName: "add"
        onClicked: {
            PopupUtils.open(itemDialog, null, {
                "itemIndex": -1,
                "itemName": "",
                "itemWeight": ""
            });
        }
    }

    AppBottomBar {
        id: bottomBar

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        navigationRoot: weightedItemsPage.navigationRoot
        currentSection: weightedItemsPage.currentSection
    }

    Component {
        id: deleteItemDialog

        Dialog {
            id: deleteDialogue

            property int itemIndex: -1
            property string itemLabel: ""

            title: i18n.tr("Delete %1").arg(singularLabel)
            text: i18n.tr("Are you sure you want to delete %1?").arg(itemLabel)

            Button {
                width: parent.width
                text: i18n.tr("Delete")
                color: theme.palette.normal.negative
                onClicked: {
                    weightedItemsPage.deleteItem(deleteDialogue.itemIndex);
                    PopupUtils.close(deleteDialogue);
                }
            }

            Button {
                width: parent.width
                text: i18n.tr("Cancel")
                onClicked: {
                    PopupUtils.close(deleteDialogue);
                }
            }
        }
    }

    Component {
        id: itemDialog

        Dialog {
            id: itemDialogue

            property int itemIndex: -1
            property string itemName: ""
            property string itemWeight: ""
            property bool isEditing: itemIndex >= 0

            title: isEditing ? i18n.tr("Edit %1").arg(singularLabel) : i18n.tr("Add %1").arg(singularLabel)

            Label {
                visible: showNameField
                width: parent.width
                height: visible ? implicitHeight : 0
                text: i18n.tr("Name")
            }

            TextField {
                id: itemNameField

                visible: showNameField
                width: parent.width
                height: visible ? implicitHeight : 0
                placeholderText: i18n.tr("Name")
                text: itemDialogue.itemName
            }

            Label {
                width: parent.width
                text: i18n.tr("Weight")
            }

            TextField {
                id: itemWeightField

                width: parent.width
                placeholderText: i18n.tr("Weight")
                text: itemDialogue.itemWeight
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator {
                    bottom: 0
                    notation: DoubleValidator.StandardNotation
                }
            }

            Button {
                width: parent.width
                text: i18n.tr("Save")
                color: theme.palette.normal.positive
                enabled: (!showNameField || itemNameField.text.trim() !== "") && itemWeightField.acceptableInput && itemWeightField.text.trim() !== ""
                onClicked: {
                    var itemName = showNameField ? itemNameField.text.trim() : "";
                    if (itemDialogue.isEditing)
                        weightedItemsPage.updateItem(itemDialogue.itemIndex, itemName, itemWeightField.text.trim());
                    else
                        weightedItemsPage.addItem(itemName, itemWeightField.text.trim());
                    PopupUtils.close(itemDialogue);
                }
            }

            Button {
                width: parent.width
                text: i18n.tr("Cancel")
                onClicked: {
                    PopupUtils.close(itemDialogue);
                }
            }
        }
    }
}
