import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import qs.Ui as Ui
import "Model.js" as Model

// Wide split prayer view, mirrored in Arabic, with focused secondary views.
Ui.Panel {
  id: root
  moduleName: "abdelhakim.salat"
  ipcTarget: "abdelhakim.salat.panel"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property var salat: bar ? (bar.shell ? bar.shell.serviceFor("abdelhakim.salat") : null) : null

  readonly property color panelBackground: Color.popups.background
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string systemFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string contentFontFamily: arabic ? "Noto Sans Arabic" : systemFontFamily
  readonly property string headingFontFamily: arabic ? "Noto Kufi Arabic" : systemFontFamily
  readonly property string numericFontFamily: systemFontFamily
  readonly property color accent: Color.accent
  readonly property color muted: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.76)
  readonly property int readingAlignment: arabic ? Text.AlignRight : Text.AlignLeft
  readonly property bool arabic: salat ? salat.lang === "ar" : true

  readonly property bool compact: panel.contentWidth < Style.space(700)
  readonly property string nextCountdown: salat ? Model.formatNextCountdown(salat.remainingMs, salat.lang) : "—"
  property string settingsPage: "location"
  property bool advancedLocation: false
  readonly property string pageTitle: settingsPage === "location" ? (arabic ? "الموقع" : "Location")
    : settingsPage === "reminders" ? (arabic ? "التنبيهات" : "Reminders")
    : settingsPage === "day" ? (arabic ? "اليوم" : "Today") : (arabic ? "إعدادات المواقيت" : "Prayer settings")

  function openSettings(page) {
    cancelEditLocation()
    closeMenus()
    settingsPage = page
    settingsOpen = true
    Qt.callLater(function() { scrollArea.contentItem.contentY = 0; backButton.forceActiveFocus() })
  }

  property string countryFilter: salat ? salat.countryCode : ""
  property bool editingLocation: false
  property bool settingsOpen: false
  onSettingsOpenChanged: {
    if (settingsOpen) Qt.callLater(function() {
      if (root.settingsOpen && !root.editingLocation) backButton.forceActiveFocus()
    })
    else { root.cancelEditLocation(); root.closeMenus(); keyCatcher.forceActiveFocus() }
  }
  property string locationDraft: ""
  property var locationSuggestions: []
  property int suggestionIndex: 0
  property string locationFeedback: ""
  property bool geocodeBusy: false
  property int geocodeGeneration: 0
  property var geocodeProcess: null

  readonly property var methodOptions: Model.methodOptions()
  readonly property var madhabOptions: arabic
    ? [{ value: "Standard", label: "شافعي" }, { value: "Hanafi", label: "حنفي" }]
    : [{ value: "Standard", label: "Shafi" }, { value: "Hanafi", label: "Hanafi" }]
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

  function closeMenus() {
    countryDropdown.close()
    cityPresetDropdown.close()
    habousCityDropdown.close()
    methodDropdown.close()
  }
  onOpenedChanged: if (!opened) { cancelEditLocation(); closeMenus() }

  function showCityOptions(code) {
    openSettings("location")
    countryFilter = code
    Qt.callLater(function() { cityPresetDropdown.open() })
  }

  function startEditLocation() {
    if (!salat) return
    settingsPage = "location"
    editingLocation = true
    settingsOpen = true
    locationDraft = ""
    locationSuggestions = []
    suggestionIndex = 0
  }

  function cancelGeocode() {
    geocodeTimer.stop()
    geocodeGeneration++
    if (geocodeProcess) {
      geocodeProcess.running = false
      geocodeProcess = null
    }
    geocodeBusy = false
  }

  function cancelEditLocation() {
    var restoreFocus = editingLocation
    cancelGeocode()
    locationFeedback = ""
    editingLocation = false
    locationDraft = ""
    locationSuggestions = []
    if (restoreFocus) Qt.callLater(function() {
      if (root.opened && root.settingsOpen && !root.editingLocation) backButton.forceActiveFocus()
    })
  }

  function commitLocation() {
    if (!salat) return
    var name = String(locationDraft || "").replace(/^\s+|\s+$/g, "")
    var choice = locationSuggestions.length
      ? locationSuggestions[Math.max(0, Math.min(suggestionIndex, locationSuggestions.length - 1))]
      : null
    if (choice) {
      salat.setLocation(choice.name + (choice.countryName ? ", " + choice.countryName : ""), choice.latitude, choice.longitude, choice.countryCode)
    } else {
      if (name.length >= 2) requestGeocode(name)
      return
    }
    cancelEditLocation()
  }

  function requestGeocode(q) {
    var query = String(q || "").replace(/^\s+|\s+$/g, "")
    cancelGeocode()
    locationSuggestions = []
    locationFeedback = ""
    if (query.length < 2) {
      return
    }
    geocodeTimer.restart()
  }

  Timer {
    id: geocodeTimer
    interval: 320
    repeat: false
    onTriggered: {
      root.geocodeBusy = true
      root.geocodeProcess = geocodeRequest.createObject(root, {
        generation: root.geocodeGeneration,
        url: Model.geocodingUrl(root.locationDraft.trim().slice(0, 160), root.countryFilter, root.arabic ? "ar" : "en")
      })
      root.geocodeProcess.running = true
    }
  }

  // Each response keeps its own generation, including after cancellation.
  Component {
    id: geocodeRequest
    Process {
      id: request
      required property int generation
      required property string url
      property string response: ""
      command: ["curl", "-fsS", "--max-time", "6", "--max-filesize", "262144", url]
      stdout: StdioCollector { onStreamFinished: request.response = text }
      onExited: function(code) {
        if (generation === root.geocodeGeneration && root.editingLocation) {
          root.geocodeBusy = false
          root.geocodeProcess = null
          root.locationSuggestions = code === 0 ? Model.parseGeocodingResults(response) : []
          root.locationFeedback = code !== 0
            ? (root.arabic ? "تعذر الاتصال. أعد المحاولة." : "Could not connect. Please try again.")
            : (root.locationSuggestions.length ? "" : (root.arabic ? "لا توجد نتائج. جرّب مدينة أخرى أو غيّر فلتر البلد." : "No matches. Try another city or change the country filter."))
          root.suggestionIndex = 0
        }
        request.destroy()
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
    contentWidth: panel.fittedContentWidth(Style.space(root.settingsOpen ? 400 : 900))
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
        if (t === "e" || t === "E") root.openSettings("location")
        else if (t === "s" || t === "S") root.openSettings("timing")
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
            visible: root.settingsOpen
            width: parent.width
            spacing: Style.space(12)
            PlainLabel {
              width: parent.width - languageButton.width - Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              text: root.settingsOpen ? root.pageTitle : (root.salat ? root.salat.locationLabel : (root.arabic ? "مواقيت الصلاة" : "Salat Times"))
              elide: Text.ElideRight
              horizontalAlignment: root.readingAlignment
              color: root.contentForeground
              font.family: root.headingFontFamily
              font.pixelSize: Style.space(21)
              font.bold: true
            }
            Ui.Button {
              id: languageButton
              text: root.arabic ? "English" : "العربية"
              focusable: true
              fontFamily: root.arabic ? root.systemFontFamily : "Noto Sans Arabic"
              foreground: root.contentForeground
              accent: root.accent
              onClicked: if (root.salat) root.salat.setLang(root.arabic ? "en" : "ar")
            }
          }

          Flow {
            id: overview
            width: parent.width
            spacing: Style.space(24)
            visible: !root.settingsOpen
            readonly property real bodyHeight: Math.max(summaryText.implicitHeight + Style.space(54), schedule.implicitHeight, Style.space(280))

            Item {
              width: root.compact ? overview.width : Style.space(310)
              height: overview.bodyHeight
              Column {
                id: summaryText
                width: parent.width
                spacing: Style.space(9)
                PlainLabel {
                  width: parent.width
                  text: root.arabic ? "مواقيت الصلاة" : "Salat Times"
                  horizontalAlignment: root.readingAlignment
                  color: root.contentForeground
                  font.family: root.headingFontFamily
                  font.pixelSize: Style.space(26)
                  font.bold: true
                  wrapMode: Text.WordWrap
                }
                PlainLabel {
                  width: parent.width
                  text: root.salat ? (root.arabic ? "التالي: " : "Next: ") + root.salat.nextName
                    + (root.salat.nextIsTomorrow ? (root.arabic ? " · غداً" : " · tomorrow") : "") + " · " + root.salat.nextTime : ""
                  horizontalAlignment: root.readingAlignment
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.space(16)
                  wrapMode: Text.WordWrap
                }
                PlainLabel {
                  width: parent.width
                  text: root.nextCountdown
                  horizontalAlignment: root.readingAlignment
                  color: root.accent
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.space(32)
                  font.bold: true
                  fontSizeMode: Text.HorizontalFit
                  minimumPixelSize: Style.space(22)
                }
                PlainLabel {
                  width: parent.width
                  text: root.salat ? root.salat.locationLabel : ""
                  horizontalAlignment: root.readingAlignment
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.space(15)
                  wrapMode: Text.WordWrap
                }
                PlainLabel {
                  width: parent.width
                  text: root.salat ? root.salat.gregorianLabel : ""
                  horizontalAlignment: root.readingAlignment
                  color: root.muted
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.space(14)
                  wrapMode: Text.WordWrap
                }
                PlainLabel {
                  width: parent.width
                  text: root.salat ? root.salat.hijriLabel : ""
                  horizontalAlignment: root.readingAlignment
                  color: root.muted
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.space(14)
                  wrapMode: Text.WordWrap
                }
              }
              Row {
                width: parent.width
                anchors.bottom: parent.bottom
                spacing: Style.space(12)
                Ui.Button {
                  width: (parent.width - parent.spacing) / 2
                  text: root.arabic ? "الموقع" : "Location"
                  iconText: "\uf041"
                  bordered: true
                  focusable: true
                  foreground: root.contentForeground
                  accent: root.accent
                  fontFamily: root.contentFontFamily
                  onClicked: root.openSettings("location")
                }
                Ui.Button {
                  width: (parent.width - parent.spacing) / 2
                  text: root.arabic ? "التنبيهات" : "Reminders"
                  iconText: "\uf0f3"
                  bordered: true
                  focusable: true
                  foreground: root.contentForeground
                  accent: root.accent
                  fontFamily: root.contentFontFamily
                  onClicked: root.openSettings("reminders")
                }
              }
            }
            Rectangle {
              width: root.compact ? overview.width : 1
              height: root.compact ? 1 : overview.bodyHeight
              color: Qt.alpha(root.contentForeground, 0.35)
            }
            Column {
              id: schedule
              width: root.compact ? overview.width : overview.width - Style.space(310 + 132 + 72) - 1
              spacing: Style.space(2)
              Repeater {
                model: root.salat ? root.salat.rows : []
                delegate: Row {
                  required property var modelData
                  width: schedule.width
                  height: Style.space(43)
                  spacing: Style.space(10)
                  readonly property color rowColor: modelData.isNext ? root.accent : root.contentForeground
                  PlainLabel {
                    width: parent.width - clock.implicitWidth - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    horizontalAlignment: root.readingAlignment
                    color: parent.rowColor
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.space(19)
                    font.bold: modelData.isNext === true
                    elide: Text.ElideRight
                  }
                  PlainLabel {
                    id: clock
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.time
                    color: parent.rowColor
                    font.family: root.numericFontFamily
                    font.pixelSize: Style.space(19)
                    font.bold: modelData.isNext === true
                    LayoutMirroring.enabled: false
                  }
                }
              }
              PlainLabel {
                width: parent.width
                visible: !root.salat || root.salat.rows.length === 0
                text: root.arabic ? "جارٍ إعداد المواقيت…" : "Preparing prayer times…"
                color: root.muted
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }
            }
            Item {
              width: root.compact ? overview.width : Style.space(132)
              height: root.compact ? railSettings.implicitHeight + railLanguage.implicitHeight + railToday.implicitHeight + Style.space(30) : overview.bodyHeight
              Ui.Button {
                id: railSettings
                width: parent.width
                text: root.arabic ? "الإعدادات" : "Settings"
                iconText: "\uf013"
                bordered: true
                focusable: true
                foreground: root.contentForeground
                accent: root.accent
                fontFamily: root.contentFontFamily
                onClicked: root.openSettings("timing")
              }
              Column {
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: Style.space(10)
                Ui.Button {
                  id: railLanguage
                  width: parent.width
                  text: root.arabic ? "English" : "العربية"
                  focusable: true
                  foreground: root.muted
                  accent: root.accent
                  fontFamily: root.arabic ? root.systemFontFamily : "Noto Sans Arabic"
                  onClicked: if (root.salat) root.salat.setLang(root.arabic ? "en" : "ar")
                }
                Ui.Button {
                  id: railToday
                  width: parent.width
                  text: root.arabic ? "اليوم" : "Today"
                  iconText: "\uf073"
                  tooltipText: root.arabic ? "القبلة ومصدر المواقيت والتحديث" : "Qibla, timetable source and refresh"
                  bordered: true
                  focusable: true
                  foreground: root.contentForeground
                  accent: root.accent
                  fontFamily: root.contentFontFamily
                  onClicked: root.openSettings("day")
                }
              }
            }
          }

          Ui.Button {
            id: backButton
            width: parent.width
            visible: root.settingsOpen
            text: root.arabic ? "العودة إلى المواقيت" : "Back to timetable"
            focusable: true
            foreground: root.contentForeground
            accent: root.accent
            fontFamily: root.contentFontFamily
            onClicked: root.settingsOpen = false
          }

          Column {
            width: parent.width
            spacing: Style.space(12)
            visible: root.settingsOpen && root.settingsPage === "day"
            PlainLabel {
              width: parent.width
              text: root.salat ? root.salat.gregorianLabel + "\n" + root.salat.hijriLabel + "\n" + root.salat.qiblaLabel : ""
              color: root.contentForeground
              horizontalAlignment: root.readingAlignment
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }
            PlainLabel {
              width: parent.width
              text: !root.salat ? "" : root.salat.source === "habous" ? (root.arabic ? "المصدر: حبوس" : "Source: Habous")
                : root.salat.source === "aladhan" ? (root.arabic ? "المصدر: AlAdhan" : "Source: AlAdhan")
                : (root.arabic ? "المصدر: حساب محلي" : "Source: offline calculation")
              color: root.muted
              horizontalAlignment: root.readingAlignment
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }
            PlainLabel {
              width: parent.width
              visible: root.salat && root.salat.fastingHint !== ""
              text: root.salat ? root.salat.fastingHint : ""
              color: root.accent
              horizontalAlignment: root.readingAlignment
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
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
              text: root.salat && root.salat.fetching ? (root.arabic ? "جارٍ التحديث…" : "Refreshing…") : (root.arabic ? "تحديث المواقيت" : "Refresh times")
              enabled: root.salat && root.salat.onlineEnabled && !root.salat.fetching
              focusable: true
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onClicked: if (root.salat) root.salat.fetchOnline()
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(12)
            visible: root.settingsOpen && root.settingsPage === "location"
            PlainLabel {
              width: parent.width
              text: (root.arabic ? "الموقع الحالي: " : "Current: ") + (root.salat ? root.salat.locationLabel : "")
              color: root.muted
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            // ---- Worldwide setup
            PanelSectionHeader {
              text: root.arabic ? "اختر موقعك حول العالم" : "Your location · worldwide"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }
            SearchableDropdown {
              id: countryDropdown
              background: root.panelBackground
              popupBorder: root.accent
              width: parent.width
              label: root.arabic ? "فلتر البلد" : "Country filter"
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
              popupMinHeight: Style.space(96)
              background: root.panelBackground
              popupBorder: root.accent
              width: parent.width
              label: root.arabic ? "مدن جاهزة · دون إنترنت" : "Offline city presets"
              placeholderText: root.arabic ? "اختر مدينة أو ابحث أدناه" : "Choose a city or search below"
              options: Model.cityPresetOptions(root.salat ? root.salat.cityPresets : [], root.countryFilter, root.arabic ? "ar" : "en")
              value: ""
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onChanged: function(v) { if (root.salat) root.salat.selectCityPreset(v) }
            }
            Loader {
              width: parent.width
              active: !root.editingLocation
              visible: active
              height: active && item ? item.implicitHeight : 0
              sourceComponent: Component {
                Column {
                  width: column.width
                  spacing: Style.space(8)

                  Button {
                    focusable: true
                    width: parent.width
                    text: root.arabic ? "البحث عن أي مدينة…" : "Search any city…"
                    fontFamily: root.contentFontFamily
                    foreground: root.contentForeground
                    accent: root.accent
                    onClicked: root.startEditLocation()
                  }


                }
              }
            }

            Loader {
              width: parent.width
              active: root.editingLocation
              visible: active
              height: active && item ? item.implicitHeight : 0
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

                  Button {
                    width: parent.width
                    text: root.arabic ? "إلغاء البحث" : "Cancel search"
                    focusable: true
                    foreground: root.contentForeground
                    accent: root.accent
                    fontFamily: root.contentFontFamily
                    onClicked: root.cancelEditLocation()
                  }

                }
              }
            }

            Ui.Button {
              width: parent.width
              text: root.advancedLocation ? (root.arabic ? "إخفاء الخيارات الإضافية" : "Hide more options") : (root.arabic ? "خيارات موقع إضافية…" : "More location options…")
              focusable: true
              foreground: root.contentForeground
              accent: root.accent
              fontFamily: root.contentFontFamily
              onClicked: root.advancedLocation = !root.advancedLocation
            }
            Column {
              width: parent.width
              spacing: Style.space(12)
              visible: root.advancedLocation
                  Button {
                    focusable: true
                    id: weatherBtn
                    width: parent.width
                    text: root.arabic ? "استخدام موقع الطقس" : "Use weather location"
                    selected: root.salat ? root.salat.useWeatherLocation : true
                    fontFamily: root.contentFontFamily
                    foreground: root.contentForeground
                    accent: root.accent
                    onClicked: if (root.salat) root.salat.adoptWeatherLocation()
                  }            // ---- Location / Habous city
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
              background: root.panelBackground
              popupBorder: root.accent
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


            }

          }
          Column {
            width: parent.width
            spacing: Style.space(12)
            visible: root.settingsOpen && root.settingsPage === "timing"
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
              background: root.panelBackground
              popupBorder: root.accent
              width: parent.width
              label: root.arabic ? "طريقة حساب المواقيت" : "Calculation method"
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
                text: root.arabic ? "حساب العصر" : "Asr calculation"
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


          }
          Column {
            width: parent.width
            spacing: Style.space(12)
            visible: root.settingsOpen && root.settingsPage === "reminders"
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
              label: root.arabic ? "تنبيه قبل الصلاة" : "Before prayer"
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


          }
        }
      }
    }
  }
}
