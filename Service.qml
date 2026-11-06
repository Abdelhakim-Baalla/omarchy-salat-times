import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Singleton salat engine. One instance computes today's schedule, drives the
// bar countdown, and fires reminders — shared across every bar surface.
Item {
  id: root

  property var shell: null
  property string omarchyPath: ""
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string statePath: home + "/.local/state/omarchy/salat.json"
  readonly property string weatherPath: home + "/.local/state/omarchy/settings/weather.json"

  // --------------------------------------------------------- settings
  property string method: "Morocco"
  property string appearance: "noor"
  property string countryCode: ""
  property bool autoMethod: true
  property var countries: []
  property var cityPresets: []
  property string madhab: "Standard"
  property string lang: "ar"
  property string reminderMode: "notification"
  property string barStyle: "full"
  property int notifyLeadMinutes: 10
  property int offsetMinutes: 0
  property int hijriAdjustment: 0
  property bool refreshFailed: false
  readonly property string refreshError: !refreshFailed ? "" : (lang === "ar"
    ? "تعذر التحديث؛ تُعرض المواقيت المتاحة"
    : "Update unavailable; showing available times")
  property string desktopTimezone: ""
  property bool notifyAtAdhan: true
  property bool notifyLead: true
  property bool useWeatherLocation: true
  property bool useHabous: true
  property bool onlineEnabled: true
  property int habousCityId: 117
  property string habousCityName: "Agadir"
  property string locationName: ""
  property real latitude: 30.42018
  property real longitude: -9.59815
  property string source: "offline"   // "habous" | "aladhan" | "offline"
  property bool fetching: false
  property int requestGeneration: 0
  property var habousCities: []
  readonly property var habousCityOptions: {
    var out = []
    for (var i = 0; i < habousCities.length; i++) {
      out.push({ value: String(habousCities[i].id), label: habousCities[i].name })
    }
    return out
  }

  // --------------------------------------------------------- runtime
  property double _now: Date.now()
  readonly property date nowDate: new Date(_now)

  property var todaySchedule: []
  property var tomorrowSchedule: []
  property var rows: []
  property var nextInfo: null

  readonly property var nextPrayer: nextInfo ? nextInfo.prayer : null
  readonly property bool nextIsTomorrow: nextInfo ? nextInfo.isTomorrow === true : false
  readonly property double remainingMs: nextPrayer
    ? Math.max(0, nextPrayer.date.getTime() - _now) : 0
  readonly property string remainingLabel: Model.formatCountdown(remainingMs)
  readonly property string remainingShort: Model.formatCountdownShort(remainingMs)
  readonly property string nextName: nextPrayer ? Model.prayerName(nextPrayer.id, lang, nextPrayer.date) : ""
  readonly property string nextNameEn: nextPrayer ? Model.prayerName(nextPrayer.id, "en", nextPrayer.date) : ""
  readonly property string nextNameAr: nextPrayer ? Model.prayerName(nextPrayer.id, "ar", nextPrayer.date) : ""
  readonly property string nextGlyph: nextPrayer ? Model.prayerGlyph(nextPrayer.id) : Model.prayerGlyph("salat")
  readonly property string nextTime: nextPrayer ? Model.formatClock(nextPrayer.date, true) : "--:--"

  readonly property string hijriLabel: Model.formatHijri(nowDate, lang, hijriAdjustment)
  readonly property string gregorianLabel: nowDate.toLocaleDateString(Qt.locale(lang === "ar" ? "ar_MA" : "en_GB"), "dddd d MMMM yyyy")
  readonly property string locationLabel: locationName !== "" ? locationName : (latitude.toFixed(2) + ", " + longitude.toFixed(2))
  readonly property string qiblaLabel: Model.qiblaLabel(latitude, longitude, lang)
  readonly property string fastingHint: Model.fastingHint(nowDate, todaySchedule, lang, hijriAdjustment)
  readonly property string methodLabel: Model.methodLabel(method)
  readonly property string barText: Model.barLabel(barStyle, nextInfo, nowDate, lang)
  readonly property string dayKey: Model.dateKey(nowDate)

  // Imminent: within 15 minutes of next prayer — bar can emphasize.
  readonly property bool imminent: remainingMs > 0 && remainingMs <= 15 * 60 * 1000
  readonly property bool isAdhanWindow: remainingMs > 0 && remainingMs <= 60 * 1000

  property var notifiedKeys: ({})

  // --------------------------------------------------------- location sources

  property var weatherLocation: ({ name: "", latitude: null, longitude: null })

  FileView {
    id: weatherFile
    path: root.weatherPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.weatherLocation = Model.parseLocationFile(text())
    onLoadFailed: root.weatherLocation = Model.parseLocationFile("")
  }

  function resolveLocation() {
    if (useWeatherLocation
        && weatherLocation
        && weatherLocation.latitude !== null
        && weatherLocation.longitude !== null) {
      latitude = Number(weatherLocation.latitude)
      longitude = Number(weatherLocation.longitude)
      if (weatherLocation.name) locationName = weatherLocation.name
      if (habousCities.length && !Model.findHabousCity(habousCities, weatherLocation.name)) useHabous = false
    }
    resolveHabousCity()
  }

  function resolveHabousCity() {
    if (!habousCities.length) return
    var hit = Model.findHabousCity(habousCities, locationName || habousCityName)
    if (hit) {
      habousCityId = hit.id
      habousCityName = hit.name
    }
  }

  function setHabousCity(id) {
    var nid = parseInt(id, 10)
    if (!isFinite(nid)) return
    for (var i = 0; i < habousCities.length; i++) {
      if (habousCities[i].id === nid) {
        countryCode = "MA"
        if (autoMethod) method = "Morocco"
        habousCityId = nid
        habousCityName = habousCities[i].name
        locationName = habousCities[i].name
        useWeatherLocation = false
        useHabous = true
        if (onlineEnabled) {
          cityCoordinateFetch.running = false
          cityCoordinateFetch.cityName = habousCityName
          cityCoordinateFetch.running = true
        }
        recompute()
        scheduleSave()
        return
      }
    }
  }

  onWeatherLocationChanged: {
    resolveLocation()
    recompute()
  }
  onUseWeatherLocationChanged: {
    resolveLocation()
    recompute()
    scheduleSave()
  }

  // --------------------------------------------------------- recompute

  function applySchedules(todaySched, tomorrowSched, src) {
    todaySchedule = todaySched || []
    tomorrowSchedule = tomorrowSched || []
    source = src || "offline"
    if (source !== "offline") refreshFailed = false
    var today = new Date(_now)
    nextInfo = Model.nextAfterSchedule(todaySchedule, tomorrowSchedule, today)
    rows = Model.enrichSchedule(todaySchedule, today, lang)
    maybeNotify()
  }

  function recomputeOffline() {
    var today = new Date(_now)
    var tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1)
    applySchedules(
      Model.daySchedule(today, latitude, longitude, method, madhab, offsetMinutes),
      Model.daySchedule(tomorrow, latitude, longitude, method, madhab, offsetMinutes),
      "offline"
    )
  }

  function recompute() {
    if (!loaded) return
    // Ignore collector/exit callbacks from canceled requests.
    requestGeneration += 1
    // Cancel obsolete requests before changing location/method/date.
    habousFetch.running = false
    todayFetch.running = false
    tomorrowFetch.running = false
    fetching = false
    _pendingToday = []
    refreshFailed = false
    recomputeOffline()
    refreshTimer.restart()
  }

  Timer {
    id: refreshTimer
    interval: 180
    onTriggered: root.fetchOnline()
  }

  function fetchOnline() {
    if (!onlineEnabled || fetching) return
    fetching = true
    if (useHabous) {
      habousFetch.generation = requestGeneration
      habousFetch.fellBack = false
      habousFetch.command = [
        "curl", "-fsS", "--max-time", "12", "--max-filesize", "1048576", "-A", "Mozilla/5.0",
        Model.habousUrl(habousCityId)
      ]
      habousFetch.running = true
    } else {
      fetchAladhan()
    }
  }

  function fetchAladhan() {
    if (!onlineEnabled) { fetching = false; recomputeOffline(); return }
    var now = new Date(_now)
    todayFetch.generation = requestGeneration
    todayFetch.command = [
      "curl", "-fsS", "--max-time", "8", "--max-filesize", "262144",
      Model.aladhanUrl(latitude, longitude, method, madhab, offsetMinutes, now, desktopTimezone)
    ]
    todayFetch.running = true
  }

  Process {
    id: habousFetch
    property int generation: -1
    property bool fellBack: false
    function fallBack() {
      if (fellBack || !root.onlineEnabled || generation !== root.requestGeneration) return
      fellBack = true
      root.fetchAladhan()
    }
    command: ["true"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (!root.onlineEnabled || habousFetch.generation !== root.requestGeneration) return
        var today = new Date(root._now)
        var parsed = Model.schedulesFromHabous(text, today, root.offsetMinutes)
        if (parsed && parsed.today && parsed.today.length) {
          var tom = parsed.tomorrow
          if (!tom || !tom.length) {
            var tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1)
            tom = Model.daySchedule(tomorrow, root.latitude, root.longitude, root.method, root.madhab, root.offsetMinutes)
          }
          root.fetching = false
          root.applySchedules(parsed.today, tom, "habous")
          if (root.habousCityName) root.locationName = root.habousCityName
        } else {
          habousFetch.fallBack()
        }
      }
    }
    onExited: function(code) {
      if (habousFetch.generation !== root.requestGeneration) return
      if (code !== 0) habousFetch.fallBack()
    }
  }

  Process {
    id: todayFetch
    property int generation: -1
    command: ["true"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (!root.onlineEnabled || todayFetch.generation !== root.requestGeneration) return
        var today = new Date(root._now)
        var sched = Model.scheduleFromAladhan(text, today)
        if (sched) {
          root._pendingToday = sched
          var tom = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1)
          tomorrowFetch.generation = root.requestGeneration
          tomorrowFetch.command = [
            "curl", "-fsS", "--max-time", "8", "--max-filesize", "262144",
            Model.aladhanUrl(root.latitude, root.longitude, root.method, root.madhab, root.offsetMinutes, tom, root.desktopTimezone)
          ]
          tomorrowFetch.running = true
        } else {
          root.fetching = false
          root.refreshFailed = true
          if (!root.todaySchedule.length) root.recomputeOffline()
        }
      }
    }
    onExited: function(code) {
      if (todayFetch.generation !== root.requestGeneration) return
      if (!root.onlineEnabled || todayFetch.generation !== root.requestGeneration) return
      if (code !== 0) {
        root.fetching = false
        if (!root.todaySchedule.length) root.recomputeOffline()
      }
    }
  }

  property var _pendingToday: []

  Process {
    id: tomorrowFetch
    property int generation: -1
    command: ["true"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (!root.onlineEnabled || tomorrowFetch.generation !== root.requestGeneration) return
        var today = new Date(root._now)
        var tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1)
        var tom = Model.scheduleFromAladhan(text, tomorrow)
        root.fetching = false
        if (root._pendingToday && root._pendingToday.length && tom) {
          root.applySchedules(root._pendingToday, tom, "aladhan")
        } else if (root._pendingToday && root._pendingToday.length) {
          root.applySchedules(
            root._pendingToday,
            Model.daySchedule(tomorrow, root.latitude, root.longitude, root.method, root.madhab, root.offsetMinutes),
            "aladhan"
          )
        } else if (!root.todaySchedule.length) {
          root.recomputeOffline()
        }
      }
    }
    onExited: function(code) {
      if (tomorrowFetch.generation !== root.requestGeneration) return
      if (!root.onlineEnabled || tomorrowFetch.generation !== root.requestGeneration) return
      if (code !== 0) {
        root.fetching = false
        if (root._pendingToday && root._pendingToday.length) {
          var today = new Date(root._now)
          var tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1)
          root.applySchedules(
            root._pendingToday,
            Model.daySchedule(tomorrow, root.latitude, root.longitude, root.method, root.madhab, root.offsetMinutes),
            "aladhan"
          )
        } else if (!root.todaySchedule.length) {
          root.recomputeOffline()
        }
      }
    }
  }

  Timer {
    interval: 60 * 60 * 1000
    repeat: true
    running: true
    onTriggered: root.fetchOnline()
  }

  FileView {
    id: citiesFile
    path: Qt.resolvedUrl("habous-cities.json")
    watchChanges: false
    printErrors: false
    onLoaded: {
      try { root.habousCities = JSON.parse(text() || "[]") } catch (e) { root.habousCities = [] }
      root.resolveHabousCity()
    }
    onLoadFailed: root.habousCities = []
  }

  // Explicit city selection also updates the offline fallback and Qibla.
  Process {
    id: cityCoordinateFetch
    property string cityName: ""
    command: ["curl", "-fsS", "--max-time", "6", "--max-filesize", "262144",
      "https://geocoding-api.open-meteo.com/v1/search?count=5&language=en&countryCode=MA&name=" + encodeURIComponent(cityName)]
    stdout: StdioCollector {
      onStreamFinished: {
        if (!root.useHabous || root.habousCityName !== cityCoordinateFetch.cityName) return
        var results = Model.parseGeocodingResults(text)
        for (var i = 0; i < results.length; i++) {
          if (Model.normalizeCityKey(results[i].name) !== Model.normalizeCityKey(cityCoordinateFetch.cityName)) continue
          root.latitude = results[i].latitude
          root.longitude = results[i].longitude
          root.recompute()
          root.scheduleSave()
          return
        }
      }
    }
  }

  FileView {
    path: Qt.resolvedUrl("countries.json")
    printErrors: false
    onLoaded: { try { root.countries = JSON.parse(text()) } catch(e) { root.countries = [] } }
  }
  FileView {
    path: Qt.resolvedUrl("city-presets.json")
    printErrors: false
    onLoaded: { try { root.cityPresets = JSON.parse(text()) } catch(e) { root.cityPresets = [] } }
  }

  function selectCityPreset(index) {
    var city = cityPresets[Number(index)]
    if (!city) return
    var countryName = ""
    for (var i = 0; i < countries.length; i++)
      if (countries[i].code === city.countryCode) countryName = lang === "ar" ? countries[i].nameAr : countries[i].name
    setLocation((lang === "ar" && city.nameAr ? city.nameAr : city.name) + (countryName ? ", " + countryName : ""), city.latitude, city.longitude, city.countryCode)
  }

  function setMethod(id) {
    autoMethod = false
    method = Model.validMethod(id)
  }

  function setMadhab(id) {
    madhab = Model.validMadhab(id)
  }

  function setLang(id) {
    lang = Model.validLang(id)
  }

  function setReminderMode(id) {
    reminderMode = Model.validReminderMode(id)
  }

  function setBarStyle(id) {
    barStyle = Model.validBarStyle(id)
  }

  function cycleBarStyle() {
    var order = ["full", "countdown", "name", "compact"]
    var i = order.indexOf(barStyle)
    barStyle = order[(i + 1) % order.length]
  }

  function cycleMethod() {
    var ids = Model.methodIds()
    var i = ids.indexOf(method)
    setMethod(ids[(i + 1) % ids.length])
  }

  function setLocation(name, lat, lng, country) {
    if (!isFinite(Number(lat)) || !isFinite(Number(lng)) || Math.abs(Number(lat)) > 90 || Math.abs(Number(lng)) > 180) return
    countryCode = /^[A-Z]{2}$/.test(String(country || "")) ? country : ""
    if (autoMethod && countryCode) method = Model.methodForCountry(countryCode)
    useHabous = countryCode === "MA" && Model.findHabousCity(habousCities, name) !== null
    useWeatherLocation = false
    locationName = String(name || "")
    latitude = Model.clampNumber(lat, latitude, -90, 90)
    longitude = Model.clampNumber(lng, longitude, -180, 180)
    resolveHabousCity()
    recompute()
    scheduleSave()
  }

  function adoptWeatherLocation() {
    useWeatherLocation = true
    resolveLocation()
    recompute()
    scheduleSave()
  }

  // --------------------------------------------------------- reminders

  property bool overlayVisible: false
  property string overlayTitle: ""
  property string overlayBody: ""
  property string overlayGlyph: "󰥔"

  function remind(title, body, glyph) {
    if (reminderMode === "silent") return
    if (reminderMode === "overlay") {
      overlayTitle = title
      overlayBody = body
      overlayGlyph = glyph || nextGlyph
      overlayVisible = true
    } else {
      Quickshell.execDetached([
        omarchyPath + "/bin/omarchy-notification-send",
        "--app-name", "Salat",
        "-g", glyph || "󰥔",
        "-u", "normal",
        title,
        body
      ])
    }
  }

  function maybeNotify() {
    if (!nextPrayer || !loaded) return
    var id = nextPrayer.id
    var keyDay = dayKey
    if (nextIsTomorrow) {
      var tmr = new Date(nowDate.getFullYear(), nowDate.getMonth(), nowDate.getDate() + 1)
      keyDay = Model.dateKey(tmr)
    }

    if (notifyLead && remainingMs <= notifyLeadMinutes * 60 * 1000 && remainingMs > 60 * 1000) {
      var leadKey = Model.notifyKey(id, "lead", keyDay)
      if (!notifiedKeys[leadKey]) {
        var copy = {}
        for (var k in notifiedKeys) copy[k] = notifiedKeys[k]
        copy[leadKey] = true
        notifiedKeys = copy
        remind(
          lang === "ar" ? ("اقترب وقت " + nextNameAr) : (nextNameEn + " soon"),
          lang === "ar"
            ? ("بعد " + remainingShort + " · " + nextTime)
            : ("In " + remainingShort + " · " + nextTime),
          nextGlyph
        )
        scheduleSave()
      }
    }

    if (notifyAtAdhan) {
      var due = Model.duePrayers(todaySchedule, nowDate, 20000)
      var changed = false
      var copy2 = {}
      for (var k2 in notifiedKeys) copy2[k2] = notifiedKeys[k2]
      for (var d = 0; d < due.length; d++) {
        var prayer = due[d]
        var adhanKey = Model.notifyKey(prayer.id, "adhan", dayKey)
        if (copy2[adhanKey]) continue
        copy2[adhanKey] = true
        changed = true
        var spoken = Model.prayerName(prayer.id, lang, prayer.date)
        remind(
          lang === "ar" ? ("حان وقت " + spoken) : ("Time for " + spoken),
          locationLabel + " · " + Model.formatClock(prayer.date, true),
          Model.prayerGlyph(prayer.id)
        )
      }
      if (changed) {
        notifiedKeys = copy2
        scheduleSave()
      }
    }
  }

  // --------------------------------------------------------- persistence

  property bool loaded: false

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.hydrate(text())
    onLoadFailed: root.hydrate("")
  }

  Timer {
    id: saveTimer
    interval: 250
    repeat: false
    onTriggered: root.flush()
  }

  function scheduleSave() {
    if (!loaded) return
    saveTimer.restart()
  }

  function hydrate(raw) {
    if (loaded) return
    var data = {}
    try { data = JSON.parse(raw || "{}") } catch (e) { data = {} }
    appearance = data.appearance === "system" ? "system" : "noor"
    countryCode = /^[A-Z]{2}$/.test(String(data.countryCode || "")) ? data.countryCode : ""
    autoMethod = data.autoMethod === undefined ? true : data.autoMethod === true
    hijriAdjustment = Model.clampInt(data.hijriAdjustment, 0, -2, 2)
    method = Model.validMethod(data.method || "Morocco")
    madhab = Model.validMadhab(data.madhab || "Standard")
    lang = data.lang === "en" ? "en" : "ar"
    reminderMode = Model.validReminderMode(data.reminderMode || "notification")
    barStyle = Model.validBarStyle(data.barStyle || "full")
    notifyLeadMinutes = Model.clampInt(data.notifyLeadMinutes, 10, 1, 60)
    offsetMinutes = Model.clampOffsetMinutes(
      data.offsetMinutes === undefined ? 0 : data.offsetMinutes,
      0
    )
    notifyAtAdhan = data.notifyAtAdhan === undefined ? true : data.notifyAtAdhan === true
    notifyLead = data.notifyLead === undefined ? true : data.notifyLead === true
    useWeatherLocation = data.useWeatherLocation === undefined ? true : data.useWeatherLocation === true
    onlineEnabled = data.onlineEnabled === undefined ? true : data.onlineEnabled === true
    useHabous = data.useHabous === undefined ? true : data.useHabous === true
    if (data.habousCityId !== undefined) habousCityId = Model.clampInt(data.habousCityId, 117, 1, 400)
    if (typeof data.habousCityName === "string" && data.habousCityName) habousCityName = data.habousCityName
    if (typeof data.locationName === "string") locationName = data.locationName
    if (data.latitude !== undefined) latitude = Model.clampNumber(data.latitude, latitude, -90, 90)
    if (data.longitude !== undefined) longitude = Model.clampNumber(data.longitude, longitude, -180, 180)
    notifiedKeys = (data.notifiedKeys && typeof data.notifiedKeys === "object") ? data.notifiedKeys : {}
    loaded = true
    resolveLocation()
    citiesFile.reload()
    recompute()
  }

  function flush() {
    stateFile.setText(JSON.stringify({
      version: 3,
      appearance: appearance,
      countryCode: countryCode,
      autoMethod: autoMethod,
      hijriAdjustment: hijriAdjustment,
      method: method,
      madhab: madhab,
      lang: lang,
      reminderMode: reminderMode,
      barStyle: barStyle,
      notifyLeadMinutes: notifyLeadMinutes,
      offsetMinutes: offsetMinutes,
      notifyAtAdhan: notifyAtAdhan,
      notifyLead: notifyLead,
      useWeatherLocation: useWeatherLocation,
      useHabous: useHabous,
      onlineEnabled: onlineEnabled,
      habousCityId: habousCityId,
      habousCityName: habousCityName,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      notifiedKeys: notifiedKeys
    }, null, 2) + "\n")
  }

  onOnlineEnabledChanged: {
    if (!loaded) return
    requestGeneration += 1
    habousFetch.running = false
    todayFetch.running = false
    tomorrowFetch.running = false
    cityCoordinateFetch.running = false
    fetching = false
    if (onlineEnabled) recompute()
    else recomputeOffline()
    scheduleSave()
  }
  onAppearanceChanged: scheduleSave()
  onAutoMethodChanged: scheduleSave()
  onCountryCodeChanged: scheduleSave()
  onHijriAdjustmentChanged: scheduleSave()
  onMethodChanged: { if (loaded) { recompute(); scheduleSave() } }
  onMadhabChanged: { if (loaded) { recompute(); scheduleSave() } }
  onLangChanged: {
    if (!loaded) return
    if (todaySchedule && todaySchedule.length)
      applySchedules(todaySchedule, tomorrowSchedule, source)
    scheduleSave()
  }
  onReminderModeChanged: scheduleSave()
  onBarStyleChanged: scheduleSave()
  onNotifyLeadMinutesChanged: scheduleSave()
  onOffsetMinutesChanged: { if (loaded) { recompute(); scheduleSave() } }
  onNotifyAtAdhanChanged: scheduleSave()
  onNotifyLeadChanged: scheduleSave()
  onLatitudeChanged: { if (loaded) { recompute(); scheduleSave() } }
  onLongitudeChanged: { if (loaded) { recompute(); scheduleSave() } }
  onLocationNameChanged: scheduleSave()

  Process {
    id: timezoneProc
    command: ["timedatectl", "show", "--property=Timezone", "--value"]
    stdout: StdioCollector {
      onStreamFinished: {
        var zone = text.trim()
        if (/^[A-Za-z_+\/-]+$/.test(zone)) { root.desktopTimezone = zone; root.recompute() }
      }
    }
  }

  Process {
    id: ensureDirProc
    command: ["mkdir", "-p", root.home + "/.local/state/omarchy"]
  }

  Component.onCompleted: {
    timezoneProc.running = true
    ensureDirProc.running = true
    Qt.callLater(function() {
      weatherFile.reload()
      stateFile.reload()
    })
  }

  // Tick every second for countdown + adhan detection. Do NOT refetch the
  // network here — schedules are refreshed hourly / on settings change.
  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
      root._now = Date.now()
      if (root.todaySchedule && root.todaySchedule.length) {
        root.applySchedules(root.todaySchedule, root.tomorrowSchedule, root.source)
      } else {
        root.recomputeOffline()
      }
      // Midnight rollover: refetch once the day key flips
      if (root._lastDayKey && root._lastDayKey !== root.dayKey) {
        var kept = {}
        for (var key in root.notifiedKeys)
          if (key.indexOf(root.dayKey + ":") === 0) kept[key] = root.notifiedKeys[key]
        root.notifiedKeys = kept
        root.recompute()
        root.scheduleSave()
      }
      root._lastDayKey = root.dayKey
    }
  }

  property string _lastDayKey: ""

  // --------------------------------------------------------- IPC

  IpcHandler {
    target: "salat"

    function status(): string {
      return JSON.stringify({
        next: root.nextPrayer ? root.nextPrayer.id : "",
        nextName: root.nextName,
        remainingMs: Math.round(root.remainingMs),
        time: root.nextTime,
        location: root.locationLabel,
        country: root.countryCode,
        countries: root.countries.length,
        cityPresets: root.cityPresets.length,
        appearance: root.appearance,
        autoMethod: root.autoMethod,
        method: root.method,
        madhab: root.madhab,
        lang: root.lang,
        hijri: root.hijriLabel,
        source: root.source,
        offsetMinutes: root.offsetMinutes,
        habousCityId: root.habousCityId,
        habousCityName: root.habousCityName,
        qibla: root.qiblaLabel
      })
    }

    function cycleMethod(): string { root.cycleMethod(); return root.method }
    function cycleLang(): string { root.lang = root.lang === "ar" ? "en" : "ar"; return root.lang }
    function cycleBarStyle(): string { root.cycleBarStyle(); return root.barStyle }
  }

  // --------------------------------------------------------- adhan overlay

  PanelWindow {
    id: overlay
    visible: root.overlayVisible
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-salat-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.overlayVisible = false
    }

    BorderSurface {
      anchors.centerIn: parent
      width: Style.space(400)
      height: content.implicitHeight + Style.spacing.panelPadding * 2
      radius: Style.cornerRadius
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))

      Column {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        y: Style.spacing.panelPadding
        spacing: Style.space(10)
        width: parent.width - Style.spacing.panelPadding * 2

        // Soft radial glow behind glyph
        Item {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 96
          height: 96

          Rectangle {
            anchors.centerIn: parent
            width: 88
            height: 88
            radius: 44
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
          }

          PlainLabel {
            anchors.centerIn: parent
            text: root.overlayGlyph
            font.family: root.lang === "ar" ? "Noto Sans Arabic" : "Noto Sans"
            font.pixelSize: 48
            color: Color.menu.text
          }
        }

        PlainLabel {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.overlayTitle
          font.family: root.lang === "ar" ? "Noto Sans Arabic" : "Noto Sans"
          font.pixelSize: Style.font.heading
          font.bold: true
          color: Color.menu.text
          wrapMode: Text.WordWrap
        }

        PlainLabel {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.overlayBody
          font.family: root.lang === "ar" ? "Noto Sans Arabic" : "Noto Sans"
          font.pixelSize: Style.font.body
          color: Qt.darker(Color.menu.text, 1.4)
          wrapMode: Text.WordWrap
        }

        Button {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.lang === "ar" ? "حسناً" : "Dismiss"
          foreground: Color.menu.text
          accent: Color.accent
          onClicked: root.overlayVisible = false
        }
      }
    }
  }
}
