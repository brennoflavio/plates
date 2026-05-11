import Lomiri.Components 1.3
import QtQuick 2.7

WeightedItemsPage {
    pageTitle: i18n.tr("Plates")
    singularLabel: i18n.tr("plate")
    itemsKey: "plates"
    currentSection: "plates"
    emptyMessage: i18n.tr("No plates yet")
    showNameField: false
}
