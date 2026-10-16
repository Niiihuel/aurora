import QtQuick
import "../../core"

/** A group's caption inside a menu ("Salida", "Redes conocidas"…). */
Item {
    property alias text: label.text

    width: parent ? parent.width : 0
    height: 22

    Text {
        id: label
        x: Tokens.menu.itemInset
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        color: Tokens.secondaryLabel
        font.family: Tokens.family
        font.pixelSize: Tokens.type.subheadline.size
        font.weight: Font.DemiBold
    }
}
