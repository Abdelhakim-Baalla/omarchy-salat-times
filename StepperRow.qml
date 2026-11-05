import QtQuick
import qs.Commons
import qs.Ui

// Compact − value + stepper for lead-minute settings.
Row {
  id: root

  property int value: 0
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal step(int delta)

  spacing: Style.space(4)

  PanelActionButton {
    focusable: true
    iconText: "−"
    foreground: root.foreground
    fontFamily: root.fontFamily
    onClicked: root.step(-1)
  }

  PlainLabel {
    width: Style.space(36)
    height: Style.space(22)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    text: root.value > 0 ? ("+" + root.value) : String(root.value)
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    font.bold: true
  }

  PanelActionButton {
    focusable: true
    iconText: "+"
    foreground: root.foreground
    fontFamily: root.fontFamily
    onClicked: root.step(1)
  }
}
