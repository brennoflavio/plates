/*
 * Copyright (C) 2026  Brenno Almeida
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * plates is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.7
import Lomiri.Components 1.3
//import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import io.thp.pyotherside 1.4
import "ut_components"

MainView {
    id: root
    objectName: 'mainView'
    applicationName: 'plates.brennoflavio'
    automaticOrientation: true

    property bool backendReady: false
    property string lastPythonError: ""

    function knownBarNameKey(itemName, itemNameKey) {
        if (itemNameKey)
            return itemNameKey;

        var normalizedName = (itemName || "").trim().toLowerCase();
        if (normalizedName === "standard")
            return "standard";
        if (normalizedName === "short")
            return "short";
        if (normalizedName === "ez bar")
            return "ez_bar";
        if (normalizedName === "no bar")
            return "no_bar";

        return "";
    }

    function translateFieldName(fieldKey) {
        switch (fieldKey) {
        case "target_weight":
            return i18n.tr("Target weight");
        case "bar_weight":
            return i18n.tr("Bar weight");
        case "plate_weight":
            return i18n.tr("Plate weight");
        default:
            return i18n.tr("Weight");
        }
    }

    function translateItemName(itemName, itemNameKey) {
        switch (knownBarNameKey(itemName, itemNameKey)) {
        case "standard":
            return i18n.tr("Standard bar");
        case "short":
            return i18n.tr("Short bar");
        case "ez_bar":
            return i18n.tr("EZ bar");
        case "no_bar":
            return i18n.tr("No bar");
        default:
            return itemName || "";
        }
    }

    function formatBarLabel(bar) {
        if (!bar)
            return "";

        var barName = translateItemName(bar.itemName, bar.itemNameKey);
        if (barName === "")
            return i18n.tr("%1 kg").arg(bar.itemWeight);

        return i18n.tr("%1 (%2 kg)").arg(barName).arg(bar.itemWeight);
    }

    function backendMessageText(messageKey, messageData) {
        var data = messageData || {};

        switch (messageKey) {
        case "backend_not_ready":
            return i18n.tr("Backend not ready");
        case "empty_response":
            return i18n.tr("Empty calculation response");
        case "unknown_items_key":
            return i18n.tr("Unknown items key");
        case "weight_required":
            return i18n.tr("%1 is required").arg(translateFieldName(data.field || ""));
        case "weight_invalid_number":
            return i18n.tr("%1 must be a valid number").arg(translateFieldName(data.field || ""));
        case "weight_negative":
            return i18n.tr("%1 cannot be negative").arg(translateFieldName(data.field || ""));
        case "weight_too_many_decimals":
            return i18n.tr("%1 can have at most %2 decimal places").arg(translateFieldName(data.field || "")).arg(data.maxDecimals || "");
        case "weight_too_large":
            return i18n.tr("%1 cannot be greater than %2 kg").arg(translateFieldName(data.field || "")).arg(data.maxWeight || "");
        case "no_valid_plates":
            return i18n.tr("No valid plates are available for calculation.");
        case "unexpected_python_error":
            return i18n.tr("Something went wrong while talking to the backend.");
        default:
            return messageKey ? i18n.tr("Unknown error") : "";
        }
    }

    function backendNoteText(noteKey, noteData) {
        var data = noteData || {};

        switch (noteKey) {
        case "target_lower_than_bar":
            return i18n.tr("Target weight is lower than the selected bar weight. Using the bar only.");
        case "inexact_match":
            return i18n.tr("Exact target is not possible with the available plates. Using %1 kg instead of %2 kg.").arg(data.achievedWeight || "").arg(data.targetWeight || "");
        default:
            return "";
        }
    }

    function loadItems(itemsKey, callback) {
        if (!backendReady) {
            if (callback)
                callback({
                    "success": false,
                    "items": [],
                    "messageKey": "backend_not_ready"
                });
            return;
        }

        lastPythonError = "";
        python.call('main.load_weighted_items', [itemsKey], function(result) {
            if (callback)
                callback(result || {
                    "success": false,
                    "items": [],
                    "messageKey": "empty_response"
                });
        });
    }

    function saveItems(itemsKey, items, callback) {
        if (!backendReady) {
            if (callback)
                callback({
                    "success": false,
                    "messageKey": "backend_not_ready"
                });
            return;
        }

        lastPythonError = "";
        python.call('main.save_weighted_items', [itemsKey, items], function(result) {
            if (callback)
                callback(result || {
                    "success": false,
                    "messageKey": "empty_response"
                });
        });
    }

    function calculateBarbellPlates(bar, targetWeight, singleSideEquipment, callback) {
        if (!backendReady) {
            if (callback)
                callback({
                    "success": false,
                    "messageKey": "backend_not_ready"
                });
            return;
        }

        lastPythonError = "";
        python.call('main.calculate_barbell_plates', [bar, targetWeight, singleSideEquipment], function(result) {
            if (callback)
                callback(result || {
                    "success": false,
                    "messageKey": "empty_response"
                });
        });
    }

    function showHome() {
        pageStack.clear();
        pageStack.push(homePageComponent, {
            "navigationRoot": root
        });
    }

    function showPlates() {
        pageStack.clear();
        pageStack.push(Qt.resolvedUrl("PlatesPage.qml"), {
            "navigationRoot": root
        });
    }

    function showBars() {
        pageStack.clear();
        pageStack.push(Qt.resolvedUrl("BarsPage.qml"), {
            "navigationRoot": root
        });
    }

    width: units.gu(45)
    height: units.gu(75)

    PageStack {
        id: pageStack

        anchors.fill: parent
        Component.onCompleted: {
            root.showHome();
        }
    }

    Component {
        id: homePageComponent

        Page {
            id: calculatorPage

            property var navigationRoot: null
            property var barsData: []
            property bool hasLoadedBars: false
            property bool isLoadingBars: false
            property bool isCalculating: false
            property bool singleSideEquipment: false
            property bool calculationSingleSideEquipment: false
            property string barLoadError: ""
            property string calculationErrorText: ""
            property var calculationResult: null

            function loadBars() {
                if (!navigationRoot || !navigationRoot.loadItems)
                    return;

                isLoadingBars = true;
                barLoadError = "";
                navigationRoot.loadItems("bars", function(result) {
                    isLoadingBars = false;
                    hasLoadedBars = true;

                    if (!result || result.success === false) {
                        barsData = [];
                        barLoadError = result && result.messageKey ? navigationRoot.backendMessageText(result.messageKey, result.messageData) : i18n.tr("Failed to load bars");
                        barSelector.selectedIndex = -1;
                        return;
                    }

                    barsData = result.items ? result.items : [];

                    if (barsData.length === 0)
                        barSelector.selectedIndex = -1;
                    else if (barSelector.selectedIndex < 0 || barSelector.selectedIndex >= barsData.length)
                        barSelector.selectedIndex = 0;
                });
            }

            function selectedBar() {
                if (barSelector.selectedIndex < 0 || barSelector.selectedIndex >= barsData.length)
                    return null;

                return barsData[barSelector.selectedIndex];
            }

            function formatBarLabel(bar) {
                if (!navigationRoot)
                    return "";

                return navigationRoot.formatBarLabel(bar);
            }

            function runCalculation() {
                var selected = selectedBar();
                var useSingleSideEquipment = singleSideEquipment;
                if (!selected || targetWeightField.text.trim() === "" || !targetWeightField.isValid)
                    return;

                isCalculating = true;
                calculationResult = null;
                calculationErrorText = "";
                calculationSingleSideEquipment = useSingleSideEquipment;
                navigationRoot.calculateBarbellPlates(selected, targetWeightField.text.trim(), useSingleSideEquipment, function(result) {
                    isCalculating = false;
                    calculationResult = result || null;
                    calculationErrorText = result && result.success === false && result.messageKey ? navigationRoot.backendMessageText(result.messageKey, result.messageData) : "";
                });
            }

            Component.onCompleted: {
                if (navigationRoot && navigationRoot.backendReady)
                    loadBars();
            }

            Connections {
                target: navigationRoot

                function onBackendReadyChanged() {
                    if (navigationRoot.backendReady && !hasLoadedBars)
                        calculatorPage.loadBars();
                }

                function onLastPythonErrorChanged() {
                    if (!navigationRoot.lastPythonError)
                        return;

                    if (calculatorPage.isLoadingBars) {
                        calculatorPage.isLoadingBars = false;
                        calculatorPage.hasLoadedBars = true;
                        calculatorPage.barsData = [];
                        calculatorPage.barLoadError = navigationRoot.backendMessageText(navigationRoot.lastPythonError);
                    }

                    if (calculatorPage.isCalculating) {
                        calculatorPage.isCalculating = false;
                        calculatorPage.calculationResult = null;
                        calculatorPage.calculationErrorText = navigationRoot.backendMessageText(navigationRoot.lastPythonError);
                    }
                }
            }

            anchors.fill: parent

            header: AppHeader {
                id: header
                pageTitle: i18n.tr('Calculator')
                isRootPage: true
                appIconName: "calculator-app-symbolic"
            }

            Flickable {
                anchors {
                    top: header.bottom
                    left: parent.left
                    right: parent.right
                    bottom: bottomBar.top
                }
                contentHeight: contentColumn.height + (2 * units.gu(2))
                clip: true

                Column {
                    id: contentColumn

                    width: parent.width - (2 * units.gu(2))
                    x: units.gu(2)
                    y: units.gu(2)
                    spacing: units.gu(2)

                    Column {
                        id: targetWeightField

                        width: parent.width
                        spacing: units.gu(0.5)
                        property alias text: targetWeightTextField.text
                        property bool isValid: /^\d{1,4}(\.\d{1,2})?$/.test(text.trim())

                        Label {
                            text: i18n.tr("Target weight")
                            fontSize: "small"
                            color: theme.palette.normal.backgroundText
                            width: parent.width
                        }

                        TextField {
                            id: targetWeightTextField

                            width: parent.width
                            placeholderText: ""
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            validator: DoubleValidator {
                                bottom: 0
                                decimals: 2
                                notation: DoubleValidator.StandardNotation
                                top: 2000
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: units.gu(1)

                        Label {
                            text: i18n.tr("Bar")
                            fontSize: "small"
                            color: theme.palette.normal.backgroundText
                        }

                        OptionSelector {
                            id: barSelector

                            width: parent.width
                            expanded: false
                            enabled: barsData.length > 0
                            model: barsData
                            containerHeight: Math.max(itemHeight, Math.min(3, barsData.length) * itemHeight)

                            delegate: OptionSelectorDelegate {
                                text: calculatorPage.formatBarLabel(modelData)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: units.gu(1)

                        CheckBox {
                            id: singleSideEquipmentCheckBox

                            checked: calculatorPage.singleSideEquipment
                            onClicked: {
                                calculatorPage.singleSideEquipment = checked;
                            }
                        }

                        Label {
                            anchors.verticalCenter: singleSideEquipmentCheckBox.verticalCenter
                            text: i18n.tr("single side equipment")
                            color: theme.palette.normal.backgroundText
                        }
                    }

                    Label {
                        visible: barLoadError !== "" || (hasLoadedBars && barsData.length === 0)
                        width: parent.width
                        text: barLoadError !== "" ? barLoadError : i18n.tr("No bars available")
                        color: theme.palette.normal.negative
                        wrapMode: Text.WordWrap
                    }

                    ActionButton {
                        width: parent.width
                        text: i18n.tr("Calculate")
                        iconName: "view-refresh"
                        enabled: !isCalculating && barsData.length > 0 && targetWeightField.isValid && targetWeightField.text.trim() !== ""
                        onClicked: {
                            calculatorPage.runCalculation();
                        }
                    }

                    Text {
                        visible: calculationErrorText !== ""
                        width: parent.width
                        text: calculationErrorText
                        color: "#ff0000"
                        wrapMode: Text.WordWrap
                        font.pixelSize: units.gu(1.8)
                    }

                    Label {
                        visible: calculationErrorText === "" && calculationResult && calculationResult.success && calculationResult.noteKey === ""
                        width: parent.width
                        text: !calculationResult ? "" : (calculationSingleSideEquipment
                            ? i18n.tr("You asked for %1. This setup gives %2 total, with %3 on the loaded side.").arg(calculationResult.targetWeight).arg(calculationResult.achievedTotalWeight).arg(calculationResult.achievedSideWeight)
                            : i18n.tr("You asked for %1. This setup gives %2 total, with %3 on each side.").arg(calculationResult.targetWeight).arg(calculationResult.achievedTotalWeight).arg(calculationResult.achievedSideWeight))
                        wrapMode: Text.WordWrap
                    }

                    Label {
                        visible: calculationErrorText === "" && calculationResult && calculationResult.noteKey !== ""
                        width: parent.width
                        text: calculationResult ? navigationRoot.backendNoteText(calculationResult.noteKey, calculationResult.noteData) : ""
                        color: theme.palette.normal.backgroundSecondaryText
                        wrapMode: Text.WordWrap
                    }

                    BarbellSidePreview {
                        width: parent.width
                        visible: calculationErrorText === "" && calculationResult && calculationResult.success
                        result: calculationResult
                    }
                }
            }

            AppBottomBar {
                id: bottomBar

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                navigationRoot: parent.navigationRoot
                currentSection: "calculator"
            }
        }
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            root.lastPythonError = "";

            importModule('main', function() {
                console.log('module imported');
                python.call('main.seed_data', [], function(result) {
                    if (result && result.success === false)
                        console.log('seed error: ' + (result.messageKey || 'unknown_error'));
                    root.backendReady = true;
                });
            });
        }

        onError: {
            root.lastPythonError = "unexpected_python_error";
            console.log('python error: ' + traceback);
        }
    }
}
