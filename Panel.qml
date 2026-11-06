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

  readonly property bool noor: !salat || salat.appearance !== "system"
  readonly property color panelBackground: noor ? "#102D27" : Color.popups.background
  readonly property color contentForeground: noor ? "#F5EFDF" : (bar ? bar.foreground : Color.foreground)
  readonly property string contentFontFamily: arabic ? "Noto Sans Arabic" : "Noto Sans"
  readonly property string headingFontFamily: arabic ? "Noto Kufi Arabic" : "Noto Sans"
  readonly property string numericFontFamily: "Noto Sans"
  readonly property color accent: noor ? "#E3C68C" : Color.accent
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
        ? ((arabic ? "غداً · " : "Tomorrow · ") + salat.nextTime)
        : salat.nextTime)
    : ""

  property string countryFilter: salat ? salat.countryCode : ""
  property bool editingLocation: false
  property bool settingsOpen: false
  onSettingsOpenChanged: {
    if (settingsOpen) Qt.callLater(function() { onlineToggle.forceActiveFocus() })
    else keyCatcher.forceActiveFocus()
  }
  property string locationDraft: ""
  property var locationSuggestions: []
  property int suggestionIndex: 0
  property string locationFeedback: ""
  property bool geocodeBusy: false

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
    locationDraft = ""
    locationSuggestions = []
    suggestionIndex = 0
  }

  function cancelEditLocation() {
    geocodeTimer.stop()
    geocodeProc.running = false
    geocodeBusy = false
    locationFeedback = ""
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
      salat.setLocation(choice.name + (choice.countryName ? ", " + choice.countryName : ""), choice.latitude, choice.longitude, choice.countryCode)
    } else if (name !== "") {
      requestGeocode(name)
      return
    }
    cancelEditLocation()
  }

  function requestGeocode(q) {
    var query = String(q || "").replace(/^\s+|\s+$/g, "")
    if (query.length < 2) {
      locationSuggestions = []
      return
    }
    geocodeTimer.stop()
    geocodeProc.running = false
    locationSuggestions = []
    locationFeedback = ""
    geocodeProc.query = query.slice(0, 160)
    geocodeTimer.restart()
  }

  Timer {
    id: geocodeTimer
    interval: 320
    repeat: false
    onTriggered: { root.geocodeBusy = true; geocodeProc.running = true }
  }

  Process {
    id: geocodeProc
    onExited: function(code) {
      root.geocodeBusy = false
      if (code !== 0 && root.editingLocation)
        root.locationFeedback = root.arabic ? "تعذر الاتصال. أعد المحاولة." : "Could not connect. Please try again."
    }
    property string query: ""
    command: [
      "curl", "-fsS", "--max-time", "6", "--max-filesize", "262144",
      Model.geocodingUrl(query, root.countryFilter, root.arabic ? "ar" : "en")
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        root.geocodeBusy = false
        if (!root.editingLocation) return
        root.locationSuggestions = Model.parseGeocodingResults(text)
        root.locationFeedback = root.locationSuggestions.length ? ""
          : (root.arabic ? "لا توجد نتائج. جرّب المدينة، البلد." : "No matches. Try city, country.")
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
      Rectangle {
        x: -panel.padding
        y: -panel.padding
        width: parent.width + panel.padding * 2
        height: parent.height + panel.padding * 2
        color: root.panelBackground
        z: -1
      }
      LayoutMirroring.enabled: root.arabic
      LayoutMirroring.childrenInherit: true
      blocked: root.settingsOpen || root.editingLocation || methodDropdown.popupOpen || habousCityDropdown.popupOpen || countryDropdown.popupOpen || cityPresetDropdown.popupOpen
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
              font.family: root.headingFontFamily
              font.pixelSize: Style.space(23)
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
              font.pixelSize: root.arabic ? Math.max(Style.font.body, Style.space(15)) : Style.font.body
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
                root.startEditLocation()
              }
            }
          }

          // Noor: a typographic prayer window. No clock face or ring.
          Column {
            width: parent.width
            spacing: Style.space(8)
            Rectangle {
              width: parent.width
              height: 1
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
            }
            Row {
              width: parent.width
              spacing: Style.space(12)
              PlainLabel {
                width: parent.width - prayerStart.width - parent.spacing
                text: root.heroName
                horizontalAlignment: root.readingAlignment
                color: root.accent
                font.family: root.headingFontFamily
                font.pixelSize: Style.space(30)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
              }
              PlainLabel {
                id: prayerStart
                anchors.verticalCenter: parent.verticalCenter
                text: root.salat ? root.salat.nextTime : "--:--"
                color: root.accent
                font.family: root.numericFontFamily
                font.pixelSize: Style.space(22)
              }
            }
            PlainLabel {
              width: parent.width
              text: root.heroTime
              horizontalAlignment: Text.AlignHCenter
              color: root.contentForeground
              font.family: root.numericFontFamily
              font.pixelSize: Style.space(62)
              font.weight: Font.Light
              fontSizeMode: Text.HorizontalFit
              minimumPixelSize: Style.space(34)
            }
            PlainLabel {
              width: parent.width
              text: (root.arabic ? "متبقي على الصلاة" : "Until the next prayer")
                + (root.salat && root.salat.nextIsTomorrow ? (root.arabic ? " · غداً" : " · tomorrow") : "")
              horizontalAlignment: Text.AlignHCenter
              color: root.muted
              font.family: root.contentFontFamily
              font.pixelSize: Style.space(13)
            }
            Item { width: 1; height: Style.space(8) }
          }

          PlainLabel {
            width: parent.width
            visible: root.salat && root.salat.fastingHint !== ""
            text: root.salat ? root.salat.fastingHint : ""
            horizontalAlignment: root.readingAlignment
            color: root.accent
            font.family: root.contentFontFamily
            font.pixelSize: root.arabic ? Math.max(Style.font.body, Style.space(15)) : Style.font.body
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
              font.pixelSize: root.arabic ? Math.max(Style.font.body, Style.space(15)) : Style.font.body
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
                height: Style.space(isNext ? 50 : 40)
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
                    font.pixelSize: root.arabic ? Math.max(Style.font.body, Style.space(15)) : Style.font.body
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
                    font.family: root.numericFontFamily
                    font.pixelSize: root.arabic ? Math.max(Style.font.body, Style.space(15)) : Style.font.body
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
              font.pixelSize: root.arabic ? Math.max(Style.font.body, Style.space(15)) : Style.font.body
              wrapMode: Text.WordWrap
            }
          }

          PlainLabel {
            width: parent.width
            visible: root.salat && root.salat.refreshError !== ""
            text: root.salat ? root.salat.refreshError : ""
            color: root.muted
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }
          Ui.Button {
            width: parent.width
            text: root.salat && root.salat.fetching ? (root.arabic ? "جارٍ التحديث…" : "Refreshing…")
              : (root.arabic ? "تحديث المواقيت" : "Refresh prayer times")
            enabled: root.salat && root.salat.onlineEnabled && !root.salat.fetching
            focusable: true
            foreground: root.muted
            accent: root.accent
            fontFamily: root.contentFontFamily
            onClicked: if (root.salat) root.salat.fetchOnline()
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

            PanelSectionHeader {
              text: root.arabic ? "المظهر" : "Appearance"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }
            ButtonGroup {
              width: parent.width
              options: [
                {value: "noor", label: root.arabic ? "نور · زمردي" : "Noor · Emerald"},
                {value: "system", label: root.arabic ? "ألوان النظام" : "System colors"}
              ]
              value: root.salat ? root.salat.appearance : "noor"
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onChanged: function(v) { if (root.salat) root.salat.appearance = v }
            }

            // ---- Worldwide setup
            PanelSectionHeader {
              text: root.arabic ? "اختر موقعك حول العالم" : "Your location · worldwide"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }
            SearchableDropdown {
              id: countryDropdown
              width: parent.width
              label: root.arabic ? "البلد" : "Country"
              placeholderText: root.arabic ? "السعودية، مصر، أمريكا…" : "Saudi Arabia, Egypt, USA…"
              options: Model.countryOptions(root.salat ? root.salat.countries : [], root.arabic ? "ar" : "en")
              value: root.countryFilter
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onChanged: function(v) {
                root.countryFilter = v
                root.cancelEditLocation()
              }
            }
            SearchableDropdown {
              id: cityPresetDropdown
              width: parent.width
              label: root.arabic ? "مدن جاهزة · تعمل دون إنترنت" : "Quick cities · available offline"
              placeholderText: root.arabic ? "اختر مدينة أو ابحث أدناه" : "Choose a city or search below"
              options: Model.cityPresetOptions(root.salat ? root.salat.cityPresets : [], root.countryFilter)
              value: ""
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onChanged: function(v) { if (root.salat) root.salat.selectCityPreset(v) }
            }
            Toggle {
              width: parent.width
              label: root.arabic ? "اقتراح طريقة الحساب حسب البلد" : "Suggest method for this country"
              description: root.arabic ? "يمكنك اختيار طريقة مسجدك يدوياً" : "You can override it to follow your mosque"
              checked: root.salat ? root.salat.autoMethod : true
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onClicked: {
                if (!root.salat) return
                root.salat.autoMethod = !root.salat.autoMethod
                if (root.salat.autoMethod) root.salat.method = Model.methodForCountry(root.salat.countryCode)
              }
            }

            Loader {
              width: parent.width
              active: !root.editingLocation
              sourceComponent: Component {
                Row {
                  width: column.width
                  spacing: Style.space(8)

                  Button {
                    focusable: true
                    width: parent.width - Style.space(8) - weatherBtn.width
                    text: root.arabic ? "البحث عن أي مدينة…" : "Search any city…"
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
                    placeholderText: root.arabic ? "المدينة، البلد…" : "City, country…"
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

                  PlainLabel {
                    width: parent.width
                    visible: root.geocodeBusy || root.locationFeedback !== ""
                    text: root.geocodeBusy ? (root.arabic ? "جارٍ البحث…" : "Searching…") : root.locationFeedback
                    color: root.muted
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
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

            // ---- Location / Habous city
            PanelSectionHeader {
              text: root.arabic ? "المصدر المغربي · اختياري" : "Morocco source · optional"
              visible: !root.countryFilter || root.countryFilter === "MA"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            Toggle {
              width: parent.width
              label: root.arabic ? "مصدر حبوس الرسمي" : "Official Habous source"
              visible: !root.countryFilter || root.countryFilter === "MA"
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
              visible: (!root.countryFilter || root.countryFilter === "MA") && (root.salat ? root.salat.useHabous : true)
              label: root.arabic ? "مدينة حبوس" : "Habous city"
              placeholderText: root.arabic ? "ابحث عن مدينة…" : "Search city…"
              value: root.salat ? String(root.salat.habousCityId) : "117"
              options: root.salat ? root.salat.habousCityOptions : []
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onChanged: function(v) { if (root.salat) root.salat.setHabousCity(v) }
            }

            PanelSectionHeader {
              text: root.arabic ? "التاريخ الهجري" : "Hijri calendar"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }
            PlainLabel {
              width: parent.width
              text: (root.salat ? root.salat.hijriLabel + "\n" : "") + (root.arabic
                ? "تقويم حسابي؛ اضبط ± يومين لموافقة الرؤية المحلية."
                : "Civil calendar; adjust ±2 days to match local moon sighting.")
              color: root.muted
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            StepperRow {
              value: root.salat ? root.salat.hijriAdjustment : 0
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onStep: function(delta) {
                if (root.salat) root.salat.hijriAdjustment = Model.clampInt(root.salat.hijriAdjustment + delta, 0, -2, 2)
              }
            }

            PanelSectionHeader {
              text: root.arabic ? "إحداثيات يدوية · دون إنترنت" : "Coordinates · works offline"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }
            Row {
              width: parent.width
              spacing: Style.space(8)
              LayoutMirroring.enabled: false
              PlainLabel {
                width: (parent.width - parent.spacing) / 2
                text: root.arabic ? "خط العرض" : "Latitude"
                color: root.muted
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
              PlainLabel {
                width: (parent.width - parent.spacing) / 2
                text: root.arabic ? "خط الطول" : "Longitude"
                color: root.muted
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }
            Row {
              width: parent.width
              spacing: Style.space(8)
              LayoutMirroring.enabled: false
              TextField {
                id: latitudeInput
                width: (parent.width - parent.spacing) / 2
                text: root.salat ? String(root.salat.latitude) : ""
                placeholderText: root.arabic ? "خط العرض" : "Latitude"
                foreground: root.contentForeground
                accent: root.accent
              }
              TextField {
                id: longitudeInput
                width: (parent.width - parent.spacing) / 2
                text: root.salat ? String(root.salat.longitude) : ""
                placeholderText: root.arabic ? "خط الطول" : "Longitude"
                foreground: root.contentForeground
                accent: root.accent
              }
            }
            Ui.Button {
              width: parent.width
              text: root.arabic ? "تطبيق الإحداثيات" : "Apply coordinates"
              enabled: latitudeInput.text.trim() !== "" && longitudeInput.text.trim() !== ""
                && isFinite(Number(latitudeInput.text)) && Math.abs(Number(latitudeInput.text)) <= 90
                && isFinite(Number(longitudeInput.text)) && Math.abs(Number(longitudeInput.text)) <= 180
              focusable: true
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onClicked: if (root.salat) root.salat.setLocation("", Number(latitudeInput.text), Number(longitudeInput.text), "")
            }
            PlainLabel {
              width: parent.width
              text: root.arabic ? "كل الأوقات بتوقيت جهازك. تحقّق من طريقة الحساب بعد تغيير البلد."
                : "Times use your desktop timezone. Check the calculation method when changing country."
              color: root.muted
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
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
                font.pixelSize: root.arabic ? Math.max(Style.font.body, Style.space(15)) : Style.font.body
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
