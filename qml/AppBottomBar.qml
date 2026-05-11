import Lomiri.Components 1.3
import QtQuick 2.7
import "ut_components"

BottomBar {
    id: appBottomBar

    property var navigationRoot: null
    property string currentSection: "calculator"

    IconButton {
        iconName: "calculator-app-symbolic"
        text: i18n.tr("Calculator")
        onClicked: {
            if (navigationRoot && currentSection !== "calculator")
                navigationRoot.showHome();
        }
    }

    IconButton {
        iconSource: Qt.resolvedUrl("../assets/plate.svg")
        text: i18n.tr("Plates")
        onClicked: {
            if (navigationRoot && currentSection !== "plates")
                navigationRoot.showPlates();
        }
    }

    IconButton {
        iconSource: Qt.resolvedUrl("../assets/bar.svg")
        text: i18n.tr("Bars")
        onClicked: {
            if (navigationRoot && currentSection !== "bars")
                navigationRoot.showBars();
        }
    }
}
