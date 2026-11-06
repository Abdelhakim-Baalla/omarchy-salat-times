import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar label for salat times. Left click opens the schedule panel; right click
// cycles the compact label style; middle click toggles Arabic/English.
BarWidget {
  id: root
  moduleName: "abdelhakim.salat"

  readonly property var salat: bar ? (bar.shell ? bar.shell.serviceFor("abdelhakim.salat") : null) : null

  readonly property string displayText: salat ? salat.barText : Model.prayerGlyph("salat")
  readonly property bool emphasize: salat ? salat.imminent : false

  function tooltipText() {
    if (!salat || !salat.nextPrayer) return "Salat Times"
    var when = salat.nextIsTomorrow
      ? (salat.lang === "ar" ? "غداً" : "tomorrow")
      : salat.nextTime
    return salat.nextName + " · " + when
      + " · " + salat.remainingShort
      + "\n" + salat.hijriLabel
      + "\n" + salat.locationLabel
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "abdelhakim.salat.widget"

    function open(): void {
      if (panelLoader.item) panelLoader.item.settingsOpen = false
      root.open()
    }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function settings(): void {
      root.open()
      if (panelLoader.item) panelLoader.item.settingsOpen = true
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    fontFamily: root.salat && root.salat.lang === "ar" ? "Noto Sans Arabic" : (root.bar ? root.bar.fontFamily : Style.font.family)
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: root.tooltipText()
    // Soft emphasis as adhan approaches.
    active: root.emphasize

    onPressed: function(b) {
      if (!root.salat) return
      if (b === Qt.RightButton) root.salat.cycleBarStyle()
      else if (b === Qt.MiddleButton) root.salat.lang = root.salat.lang === "ar" ? "en" : "ar"
      else root.togglePanel()
    }
  }
}
