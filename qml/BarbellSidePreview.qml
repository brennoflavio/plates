import QtQuick 2.7
import Lomiri.Components 1.3

Rectangle {
    id: preview

    property var result: null

    function expandedPlates() {
        if (!result || !result.plates)
            return [];

        var items = [];
        for (var i = 0; i < result.plates.length; i++) {
            var plate = result.plates[i];
            var count = plate.count || 0;
            for (var j = 0; j < count; j++) {
                items.push({
                    "itemWeight": plate.itemWeight
                });
            }
        }
        return items;
    }

    function maxPlateWeight() {
        var plates = expandedPlates();
        var maxWeight = 0;

        for (var i = 0; i < plates.length; i++) {
            var weight = parseFloat(plates[i].itemWeight || "0");
            if (weight > maxWeight)
                maxWeight = weight;
        }

        return maxWeight > 0 ? maxWeight : 1;
    }

    function plateHeight(weightText) {
        var weight = parseFloat(weightText || "0");
        var minHeight = units.gu(5);
        var maxHeight = units.gu(14);
        var ratio = Math.max(0, weight) / maxPlateWeight();

        return minHeight + ((maxHeight - minHeight) * ratio);
    }

    visible: result && result.success
    width: parent.width
    height: units.gu(18)
    radius: units.gu(0.5)
    color: "transparent"
    clip: true

    Flickable {
        id: previewFlickable

        anchors.fill: parent
        anchors.margins: units.gu(2)
        contentWidth: Math.max(width, contentRoot.width)
        contentHeight: contentRoot.height
        clip: true

        Item {
            id: contentRoot

            width: Math.max(previewFlickable.width, drawingRow.width)
            height: drawingRow.height

            Row {
                id: drawingRow

                anchors.centerIn: parent
                height: units.gu(14)
                spacing: units.gu(0.4)

                Item {
                    width: units.gu(12)
                    height: parent.height

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: collar.left
                            verticalCenter: parent.verticalCenter
                        }
                        height: units.gu(3)
                        color: "#8f9399"
                        radius: units.gu(0.2)

                        Label {
                            anchors.centerIn: parent
                            text: preview.result ? preview.result.bar.itemWeight : ""
                            color: "white"
                            fontSize: "large"
                        }
                    }

                    Rectangle {
                        id: collar

                        width: units.gu(1.2)
                        height: units.gu(4)
                        radius: units.gu(0.2)
                        color: "#8f9399"
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Repeater {
                    model: expandedPlates()

                    delegate: Rectangle {
                        width: units.gu(4)
                        height: plateHeight(modelData.itemWeight)
                        radius: units.gu(0.5)
                        color: "#1e88e5"
                        anchors.verticalCenter: drawingRow.verticalCenter

                        Label {
                            anchors.centerIn: parent
                            text: modelData.itemWeight
                            color: "white"
                            fontSize: "medium"
                        }
                    }
                }
            }
        }
    }
}
