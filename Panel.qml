import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import qs.Ui as Ui
import "Model.js" as Model

// Salat panel — one composition: header → hero → timeline → settings drawer.
Ui.Panel {
  id: root
  moduleName: "abdelhakim.salat"
  ipcTarget: "abdelhakim.salat.panel"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property var salat: bar ? (bar.shell ? bar.shell.serviceFor("abdelhakim.salat") : null) : null

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color accent: Color.accent
  readonly property color muted: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.76)
  readonly property int readingAlignment: arabic ? Text.AlignRight : Text.AlignLeft
  readonly property bool arabic: salat ? salat.lang === "ar" : true

  readonly property string heroName: salat ? salat.nextName : "—"
  readonly property string heroSub: salat
    ? (arabic ? salat.nextNameEn : salat.nextNameAr)
    : ""
  readonly property string heroTime: salat ? salat.remainingLabel : "--:--"
  readonly property string heroWhen: salat
    ? (salat.nextIsTomorrow
        ? (arabic ? "غداً" : "Tomorrow")
        : salat.nextTime)
    : ""

  property bool editingLocation: false
  property bool settingsOpen: false
  onSettingsOpenChanged: {
    if (settingsOpen) Qt.callLater(function() { onlineToggle.forceActiveFocus() })
    else keyCatcher.forceActiveFocus()
  }
  property string locationDraft: ""
  property var locationSuggestions: []
  property int suggestionIndex: 0

  readonly property var methodOptions: Model.methodOptions()
  readonly property var madhabOptions: arabic
    ? [{ value: "Standard", label: "شافعي" }, { value: "Hanafi", label: "حنفي" }]
    : [{ value: "Standard", label: "Shafi" }, { value: "Hanafi", label: "Hanafi" }]
  readonly property var langOptions: [
    { value: "ar", label: "العربية" },
    { value: "en", label: "English" }
  ]
  readonly property var reminderOptions: arabic
    ? [
        { value: "notification", label: "إشعار" },
        { value: "overlay", label: "شاشة" },
        { value: "silent", label: "صامت" }
      ]
    : [
        { value: "notification", label: "Notify" },
        { value: "overlay", label: "Overlay" },
        { value: "silent", label: "Silent" }
      ]

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function startEditLocation() {
    if (!salat) return
    editingLocation = true
    settingsOpen = true
    locationDraft = salat.locationName
    locationSuggestions = []
    suggestionIndex = 0
  }

  function cancelEditLocation() {
    editingLocation = false
    locationDraft = ""
    locationSuggestions = []
  }

  function commitLocation() {
    if (!salat) return
    var name = String(locationDraft || "").replace(/^\s+|\s+$/g, "")
    if (name === "" && locationSuggestions.length === 0) {
      salat.adoptWeatherLocation()
      cancelEditLocation()
      return
    }
    var choice = locationSuggestions.length
      ? locationSuggestions[Math.max(0, Math.min(suggestionIndex, locationSuggestions.length - 1))]
      : null
    if (choice) {
      salat.setLocation(choice.name, choice.latitude, choice.longitude)
    } else if (name !== "") {
      salat.locationName = name
      geocodeProc.query = name
      geocodeProc.running = true
    }
    cancelEditLocation()
  }

  function requestGeocode(q) {
    var query = String(q || "").replace(/^\s+|\s+$/g, "")
    if (query.length < 2) {
      locationSuggestions = []
      return
    }
    geocodeProc.query = query
    geocodeTimer.restart()
  }

  Timer {
    id: geocodeTimer
    interval: 320
    repeat: false
    onTriggered: geocodeProc.running = true
  }

  Process {
    id: geocodeProc
    property string query: ""
    command: [
      "curl", "-fsS", "--max-time", "6", "--max-filesize", "262144",
      "https://geocoding-api.open-meteo.com/v1/search?count=5&language=en&format=json&name="
        + encodeURIComponent(query)
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        root.locationSuggestions = Model.parseGeocodingResults(text)
        root.suggestionIndex = 0
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      LayoutMirroring.enabled: root.arabic
      LayoutMirroring.childrenInherit: true
      blocked: root.settingsOpen || root.editingLocation || methodDropdown.popupOpen || habousCityDropdown.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (root.editingLocation) return
        if (t === "e" || t === "E") root.startEditLocation()
        else if (t === "s" || t === "S") root.settingsOpen = !root.settingsOpen
        else if (t === "m" || t === "M") { if (root.salat) root.salat.cycleMethod() }
        else if (t === "a" || t === "A") { if (root.salat) root.salat.lang = root.salat.lang === "ar" ? "en" : "ar" }
        else if (t === "b" || t === "B") { if (root.salat) root.salat.cycleBarStyle() }
      }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        Keys.onEscapePressed: {
          if (root.editingLocation) root.cancelEditLocation()
          else if (root.settingsOpen) root.settingsOpen = false
          else root.close()
          keyCatcher.forceActiveFocus()
        }
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: column.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Binding {
          target: scrollArea.contentItem
          property: "interactive"
          value: column.implicitHeight > scrollArea.height
        }

        Column {
          id: column
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          Row {
            width: parent.width
            spacing: Style.space(12)
            PlainLabel {
              width: parent.width - languageButton.width - Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              text: root.arabic ? "مواقيت الصلاة" : "Salat Times"
              horizontalAlignment: root.readingAlignment
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }
            Ui.Button {
              id: languageButton
              text: root.arabic ? "English" : "العربية"
              focusable: true
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.accent
              onClicked: if (root.salat) root.salat.setLang(root.arabic ? "en" : "ar")
            }
          }

          Column {
            id: overview
            width: parent.width
            spacing: Style.space(14)
            visible: !root.settingsOpen

          Column {
            width: parent.width
            spacing: Style.space(4)
            PlainLabel {
              width: parent.width
              text: root.salat ? root.salat.hijriLabel : "—"
              horizontalAlignment: root.readingAlignment
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: root.arabic ? Math.max(Style.font.body, Style.space(14)) : Style.font.body
            }
            PlainLabel {
              width: parent.width
              text: root.salat ? root.salat.gregorianLabel : ""
              horizontalAlignment: root.readingAlignment
              color: root.muted
              font.family: root.contentFontFamily
              font.pixelSize: root.arabic ? Math.max(Style.font.bodySmall, Style.space(12)) : Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            PlainLabel {
              width: parent.width
              text: root.salat ? root.salat.qiblaLabel : ""
              horizontalAlignment: root.readingAlignment
              wrapMode: Text.WordWrap
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: root.arabic ? Math.max(Style.font.bodySmall, Style.space(12)) : Style.font.bodySmall
            }
            Ui.Button {
              width: parent.width
              leftAlign: true
              text: root.salat ? root.salat.locationLabel : (root.arabic ? "الموقع" : "Location")
              tooltipText: root.arabic ? "تغيير الموقع" : "Change location"
              focusable: true
              fontFamily: root.contentFontFamily
              foreground: root.muted
              accent: root.accent
              horizontalPadding: 0
              onClicked: {
                if (root.salat && root.salat.useHabous) root.settingsOpen = true
                else root.startEditLocation()
              }
            }
          }

          // The countdown is inscribed in the day ring. The arc is only the
          // current prayer window, so the ornament and the answer are one object.
          Item {
            width: parent.width
            height: dial.width
            DayDial {
              id: dial
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(232)
              height: width
              foreground: root.contentForeground
              accent: root.accent
              points: root.salat ? root.salat.dialPoints : []
              journey: root.salat ? root.salat.dialJourney : ({})
              Column {
                width: Style.space(148)
                anchors.centerIn: parent
                spacing: Style.space(2)
                PlainLabel {
                  width: parent.width
                  text: root.heroName || (root.arabic ? "جارٍ الحساب" : "Calculating")
                  horizontalAlignment: Text.AlignHCenter
                  color: root.accent
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.heading
                  font.bold: true
                  elide: Text.ElideRight
                }
                PlainLabel {
                  width: parent.width
                  text: root.heroTime
                  horizontalAlignment: Text.AlignHCenter
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.space(36)
                  font.weight: Font.DemiBold
                  fontSizeMode: Text.HorizontalFit
                  minimumPixelSize: Style.space(22)
                  LayoutMirroring.enabled: false
                }
                PlainLabel {
                  width: parent.width
                  text: root.heroWhen
                    ? ((root.salat && root.salat.nextIsTomorrow)
                        ? root.heroWhen
                        : ((root.arabic ? "عند " : "at ") + root.heroWhen))
                    : ""
                  horizontalAlignment: Text.AlignHCenter
                  color: root.muted
                  font.family: root.contentFontFamily
                  font.pixelSize: root.arabic ? Math.max(Style.font.bodySmall, Style.space(12)) : Style.font.bodySmall
                  elide: Text.ElideRight
                  LayoutMirroring.enabled: false
                }
              }
            }
          }

          PlainLabel {
            width: parent.width
            visible: root.salat && root.salat.fastingHint !== ""
            text: root.salat ? root.salat.fastingHint : ""
            horizontalAlignment: root.readingAlignment
            color: root.accent
            font.family: root.contentFontFamily
            font.pixelSize: root.arabic ? Math.max(Style.font.body, Style.space(14)) : Style.font.body
            wrapMode: Text.WordWrap
          }

          Row {
            width: parent.width
            spacing: Style.space(8)
            PlainLabel {
              width: parent.width - sourceLabel.width - Style.space(8)
              text: root.arabic ? "مواقيت اليوم" : "Today’s prayers"
              horizontalAlignment: root.readingAlignment
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: root.arabic ? Math.max(Style.font.body, Style.space(14)) : Style.font.body
              font.bold: true
            }
            PlainLabel {
              id: sourceLabel
              text: !root.salat ? "" : root.salat.fetching
                ? (root.arabic ? "جارٍ التحديث" : "Updating")
                : root.salat.source === "habous" ? (root.arabic ? "حبوس" : "Habous")
                : root.salat.source === "aladhan" ? "AlAdhan"
                : (root.arabic ? "حساب محلي" : "Offline calculation")
              color: root.muted
              font.family: root.contentFontFamily
              font.pixelSize: root.arabic ? Math.max(Style.font.bodySmall, Style.space(12)) : Style.font.bodySmall
            }
          }

          Column {
            id: timeline
            width: parent.width
            spacing: Style.space(2)
            Repeater {
              model: root.salat ? root.salat.rows : []
              delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool isNext: modelData.isNext === true
                readonly property bool isNow: modelData.isNow === true
                readonly property bool isPassed: modelData.passed === true
                readonly property color rowColor: isNext
                  ? root.accent
                  : (isPassed ? root.muted : root.contentForeground)
                width: timeline.width
                height: Style.space(40)
                radius: Style.cornerRadius
                color: isNext
                  ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, root.salat && root.salat.imminent ? 0.22 : 0.12)
                  : "transparent"
                Row {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(12)
                  anchors.rightMargin: Style.space(12)
                  spacing: Style.space(10)
                  PlainLabel {
                    width: parent.width - prayerTime.width - rowState.width - Style.space(20)
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    horizontalAlignment: root.readingAlignment
                    color: rowColor
                    font.family: root.contentFontFamily
                    font.pixelSize: root.arabic ? Math.max(Style.font.body, Style.space(14)) : Style.font.body
                    font.bold: isNext || isNow
                    elide: Text.ElideRight
                  }
                  PlainLabel {
                    id: rowState
                    width: Style.space(64)
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.statusLabel || ""
                    horizontalAlignment: Text.AlignHCenter
                    color: isNext ? root.accent : root.muted
                    font.family: root.contentFontFamily
                    font.pixelSize: root.arabic ? Math.max(Style.font.bodySmall, Style.space(12)) : Style.font.bodySmall
                    elide: Text.ElideRight
                  }
                  PlainLabel {
                    id: prayerTime
                    width: Style.space(56)
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: modelData.time
                    color: rowColor
                    font.family: root.contentFontFamily
                    font.pixelSize: root.arabic ? Math.max(Style.font.body, Style.space(14)) : Style.font.body
                    font.bold: isNext || isNow
                    LayoutMirroring.enabled: false
                  }
                }
              }
            }
            PlainLabel {
              width: parent.width
              visible: !root.salat || root.salat.rows.length === 0
              text: root.arabic ? "جارٍ إعداد مواقيت اليوم…" : "Preparing today’s prayer times…"
              color: root.muted
              font.family: root.contentFontFamily
              font.pixelSize: root.arabic ? Math.max(Style.font.body, Style.space(14)) : Style.font.body
              wrapMode: Text.WordWrap
            }
          }

          } // overview

          // ============================================================ SETTINGS DRAWER
          // Collapsed by default — keeps the first view about the day, not knobs.
          Ui.Button {
            width: parent.width
            text: root.settingsOpen
              ? (root.arabic ? "إغلاق الإعدادات" : "Close settings")
              : (root.arabic ? "الإعدادات" : "Settings")
            selected: root.settingsOpen
            focusable: true
            foreground: root.contentForeground
            accent: root.accent
            fontFamily: root.contentFontFamily
            onClicked: root.settingsOpen = !root.settingsOpen
          }

          Column {
            width: parent.width
            spacing: Style.space(12)
            visible: root.settingsOpen
            height: visible ? implicitHeight : 0
            clip: true
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }

            Toggle {
              id: onlineToggle
              width: parent.width
              label: root.arabic ? "تحديث المواقيت عبر الإنترنت" : "Online prayer tables"
              description: root.arabic ? "تحديث كل ساعة؛ أوقفه لاستخدام الحساب المحلي" : "Refresh hourly; turn off to use offline calculation"
              checked: root.salat ? root.salat.onlineEnabled : true
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onClicked: if (root.salat) root.salat.onlineEnabled = !root.salat.onlineEnabled
            }

            // ---- Location / Habous city
            PanelSectionHeader {
              text: root.arabic ? "الموقع · حبوس" : "Location · Habous"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Toggle {
              width: parent.width
              label: root.arabic ? "مصدر حبوس الرسمي" : "Official Habous source"
              description: root.arabic
                ? "مواقيت وزارة الأوقاف المغربية"
                : "Morocco Ministry of Habous prayer tables"
              checked: root.salat ? root.salat.useHabous : true
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onClicked: {
                if (!root.salat) return
                root.salat.useHabous = !root.salat.useHabous
                root.salat.recompute()
                root.salat.scheduleSave()
              }
            }

            SearchableDropdown {
              id: habousCityDropdown
              width: parent.width
              visible: root.salat ? root.salat.useHabous : true
              label: root.arabic ? "مدينة حبوس" : "Habous city"
              placeholderText: root.arabic ? "ابحث عن مدينة…" : "Search city…"
              value: root.salat ? String(root.salat.habousCityId) : "117"
              options: root.salat ? root.salat.habousCityOptions : []
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onChanged: function(v) { if (root.salat) root.salat.setHabousCity(v) }
            }

            Loader {
              width: parent.width
              active: !root.editingLocation && !(root.salat && root.salat.useHabous)
              sourceComponent: Component {
                Row {
                  width: column.width
                  spacing: Style.space(8)

                  Button {
                    focusable: true
                    width: parent.width - Style.space(8) - weatherBtn.width
                    text: root.salat ? root.salat.locationLabel : ""
                    fontFamily: root.contentFontFamily
                    foreground: root.contentForeground
                    accent: root.accent
                    onClicked: root.startEditLocation()
                  }

                  Button {
                    focusable: true
                    id: weatherBtn
                    width: Style.space(84)
                    text: root.arabic ? "تلقائي" : "Auto"
                    selected: root.salat ? root.salat.useWeatherLocation : true
                    fontFamily: root.contentFontFamily
                    foreground: root.contentForeground
                    accent: root.accent
                    onClicked: if (root.salat) root.salat.adoptWeatherLocation()
                  }
                }
              }
            }

            Loader {
              width: parent.width
              active: root.editingLocation
              sourceComponent: Component {
                Column {
                  width: column.width
                  spacing: Style.space(6)

                  TextField {
                    width: parent.width
                    text: root.locationDraft
                    placeholderText: root.arabic ? "مدينة…" : "City…"
                    foreground: root.contentForeground
                    accent: root.accent
                    Component.onCompleted: forceActiveFocus()
                    onTextChanged: {
                      root.locationDraft = text
                      root.requestGeocode(text)
                    }
                    Keys.onReturnPressed: root.commitLocation()
                    Keys.onEscapePressed: root.cancelEditLocation()
                    Keys.onDownPressed: {
                      if (root.locationSuggestions.length)
                        root.suggestionIndex = Math.min(root.suggestionIndex + 1, root.locationSuggestions.length - 1)
                    }
                    Keys.onUpPressed: {
                      if (root.locationSuggestions.length)
                        root.suggestionIndex = Math.max(root.suggestionIndex - 1, 0)
                    }
                  }

                  Repeater {
                    model: root.locationSuggestions
                    delegate: Button {
                      required property var modelData
                      required property int index
                      width: parent.width
                      text: modelData.name + (modelData.description ? " · " + modelData.description : "")
                      selected: index === root.suggestionIndex
                      fontFamily: root.contentFontFamily
                      foreground: root.contentForeground
                      accent: root.accent
                      onClicked: {
                        root.suggestionIndex = index
                        root.commitLocation()
                      }
                    }
                  }

                  Row {
                    width: parent.width
                    spacing: Style.space(8)

                    Button {
                      focusable: true
                      width: (parent.width - Style.space(8)) / 2
                      text: root.arabic ? "حفظ" : "Save"
                      fontFamily: root.contentFontFamily
                      foreground: root.contentForeground
                      accent: root.accent
                      onClicked: root.commitLocation()
                    }

                    Button {
                      focusable: true
                      width: (parent.width - Style.space(8)) / 2
                      text: root.arabic ? "إلغاء" : "Cancel"
                      fontFamily: root.contentFontFamily
                      foreground: root.contentForeground
                      accent: root.accent
                      onClicked: root.cancelEditLocation()
                    }
                  }
                }
              }
            }

            // ---- Calculation
            PanelSectionHeader {
              text: root.arabic ? "الحساب" : "Calculation"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Column {
                width: parent.width - Style.space(8) - offsetStepper.implicitWidth
                spacing: Style.space(2)
                anchors.verticalCenter: parent.verticalCenter

                PlainLabel {
                  width: parent.width
                  text: root.arabic ? "تصحيح الدقائق" : "Time correction"
                  color: root.muted
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                PlainLabel {
                  width: parent.width
                  text: root.arabic
                    ? "مع حبوس عادة 0 — عدّل فقط إذا احتجت"
                    : "With Habous use 0 — tweak only if needed"
                  color: root.muted
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }
              }

              StepperRow {
                id: offsetStepper
                anchors.verticalCenter: parent.verticalCenter
                value: root.salat ? root.salat.offsetMinutes : 0
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onStep: function(delta) {
                  if (root.salat)
                    root.salat.offsetMinutes = Model.clampOffsetMinutes(root.salat.offsetMinutes + delta, 0)
                }
              }
            }

            Dropdown {
              id: methodDropdown
              width: parent.width
              label: root.arabic ? "الطريقة" : "Method"
              value: root.salat ? root.salat.method : "Morocco"
              options: root.methodOptions
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onChanged: function(v) { if (root.salat) root.salat.setMethod(v) }
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              PlainLabel {
                text: root.arabic ? "المذهب (العصر)" : "Asr madhab"
                color: root.muted
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              ButtonGroup {
                width: parent.width
                options: root.madhabOptions
                value: root.salat ? root.salat.madhab : "Standard"
                foreground: root.contentForeground
                accent: root.accent
                fontFamily: root.contentFontFamily
                onChanged: function(v) { if (root.salat) root.salat.setMadhab(v) }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              PlainLabel {
                text: root.arabic ? "اللغة" : "Language"
                color: root.muted
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              ButtonGroup {
                width: parent.width
                options: root.langOptions
                value: root.salat ? root.salat.lang : "ar"
                foreground: root.contentForeground
                accent: root.accent
                fontFamily: root.contentFontFamily
                onChanged: function(v) { if (root.salat) root.salat.setLang(v) }
              }
            }

            // ---- Reminders
            PanelSectionHeader {
              text: root.arabic ? "التذكير" : "Reminders"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            ButtonGroup {
              width: parent.width
              options: root.reminderOptions
              value: root.salat ? root.salat.reminderMode : "notification"
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onChanged: function(v) { if (root.salat) root.salat.setReminderMode(v) }
            }

            Toggle {
              width: parent.width
              label: root.arabic ? "عند الأذان" : "At adhan"
              description: root.arabic ? "تنبيه لحظة دخول الوقت" : "Alert when the prayer begins"
              checked: root.salat ? root.salat.notifyAtAdhan : true
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onClicked: if (root.salat) root.salat.notifyAtAdhan = !root.salat.notifyAtAdhan
            }

            Toggle {
              width: parent.width
              label: root.arabic ? "تنبيه مسبق" : "Lead reminder"
              description: root.arabic
                ? ("قبل " + (root.salat ? root.salat.notifyLeadMinutes : 10) + " دقائق")
                : ((root.salat ? root.salat.notifyLeadMinutes : 10) + " minutes before")
              checked: root.salat ? root.salat.notifyLead : true
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onClicked: if (root.salat) root.salat.notifyLead = !root.salat.notifyLead
            }

            Row {
              width: parent.width
              spacing: Style.space(8)
              visible: root.salat ? root.salat.notifyLead : true

              PlainLabel {
                width: parent.width * 0.45
                anchors.verticalCenter: parent.verticalCenter
                text: root.arabic ? "الدقائق" : "Minutes"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: root.arabic ? Math.max(Style.font.body, Style.space(14)) : Style.font.body
              }

              StepperRow {
                value: root.salat ? root.salat.notifyLeadMinutes : 10
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onStep: function(delta) {
                  if (root.salat)
                    root.salat.notifyLeadMinutes = Model.clampInt(root.salat.notifyLeadMinutes + delta, 10, 1, 60)
                }
              }
            }

            PlainLabel {
              width: parent.width
              text: root.arabic
                ? "S إعدادات · E موقع · M طريقة · A لغة"
                : "S settings · E location · M method · A language"
              color: root.muted
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }
}
