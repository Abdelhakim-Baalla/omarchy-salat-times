// Offline salat-time math (PrayTimes-style astronomical formulas), Hijri
// conversion, and display helpers. Qt-free so it can be reasoned about without
// the shell.

var PRAYER_IDS = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]

var METHODS = {
  MWL:     { fajr: 18,   isha: 17,   maghrib: "angle", maghribAngle: 0, ishaInterval: 0,  label: "Muslim World League", aladhan: 3 },
  ISNA:    { fajr: 15,   isha: 15,   maghrib: "angle", maghribAngle: 0, ishaInterval: 0,  label: "ISNA", aladhan: 2 },
  Egypt:   { fajr: 19.5, isha: 17.5, maghrib: "angle", maghribAngle: 0, ishaInterval: 0,  label: "Egyptian General Authority", aladhan: 5 },
  Makkah:  { fajr: 18.5, isha: 0,    maghrib: "angle", maghribAngle: 0, ishaInterval: 90, label: "Umm Al-Qura", aladhan: 4 },
  Karachi: { fajr: 18,   isha: 18,   maghrib: "angle", maghribAngle: 0, ishaInterval: 0,  label: "University of Karachi", aladhan: 1 },
  Tehran:  { fajr: 17.7, isha: 14,   maghrib: "angle", maghribAngle: 4.5, ishaInterval: 0, label: "Institute of Geophysics, Tehran", aladhan: 7 },
  Jafari:  { fajr: 16,   isha: 14,   maghrib: "angle", maghribAngle: 4, ishaInterval: 0,  label: "Shia Ithna Ashari", aladhan: 0 },
  // Maghreb phone apps usually track MWL/Egypt noon, then add ~+5 after zawal.
  Morocco: { fajr: 18,   isha: 17,   maghrib: "angle", maghribAngle: 0, ishaInterval: 0,  label: "Morocco", aladhan: 3 },
  Algeria: { fajr: 18,   isha: 17,   maghrib: "angle", maghribAngle: 0, ishaInterval: 0,  label: "Algeria", aladhan: 3 },
  Tunisia: { fajr: 18,   isha: 18,   maghrib: "angle", maghribAngle: 0, ishaInterval: 0,  label: "Tunisia", aladhan: 5 }
}

var METHOD_ORDER = ["Morocco", "MWL", "Egypt", "ISNA", "Makkah", "Karachi", "Tehran", "Jafari", "Algeria", "Tunisia"]

var NAMES = {
  en: {
    fajr: "Fajr", sunrise: "Sunrise", dhuhr: "Dhuhr",
    asr: "Asr", maghrib: "Maghrib", isha: "Isha",
    next: "Next", now: "Now", passed: "Passed"
  },
  ar: {
    fajr: "الفجر", sunrise: "الشروق", dhuhr: "الظهر",
    asr: "العصر", maghrib: "المغرب", isha: "العشاء",
    next: "التالي", now: "الآن", passed: "فات"
  }
}

var GLYPHS = {
  fajr: "󰖔", sunrise: "󰖙", dhuhr: "󰖨",
  asr: "󰖛", maghrib: "󰖛", isha: "󰖔", salat: "󰥔"
}

function pad2(n) {
  var x = Math.floor(Number(n) || 0)
  return (x < 10 ? "0" : "") + x
}

function clampInt(value, fallback, min, max) {
  var n = parseInt(value, 10)
  if (!isFinite(n)) n = fallback
  if (n < min) n = min
  if (n > max) n = max
  return n
}

function clampNumber(value, fallback, min, max) {
  var n = Number(value)
  if (!isFinite(n)) n = fallback
  if (n < min) n = min
  if (n > max) n = max
  return n
}

function validMethod(id) {
  return METHODS[id] ? id : "Morocco"
}

function validMadhab(id) {
  return id === "Hanafi" ? "Hanafi" : "Standard"
}

function validLang(id) {
  return id === "ar" ? "ar" : "en"
}

function validReminderMode(id) {
  if (id === "overlay" || id === "silent") return id
  return "notification"
}

function validBarStyle(id) {
  if (id === "countdown" || id === "name" || id === "compact") return id
  return "full"
}

function clampOffsetMinutes(value, fallback) {
  return clampInt(value, fallback === undefined ? 0 : fallback, -30, 30)
}

function aladhanMethodId(methodId) {
  var m = METHODS[validMethod(methodId)]
  return m && m.aladhan !== undefined ? m.aladhan : 3
}

function aladhanSchool(madhab) {
  return validMadhab(madhab) === "Hanafi" ? 1 : 0
}

// Build Aladhan timings URL. `tune` applies the same minute correction the
// phone apps often bake in (Morocco: typically +5 after astronomical zawal).
function aladhanUrl(lat, lng, methodId, madhab, offsetMinutes, date) {
  var d = date || new Date()
  var day = pad2(d.getDate()) + "-" + pad2(d.getMonth() + 1) + "-" + d.getFullYear()
  var off = clampOffsetMinutes(offsetMinutes, 5)
  var tune = [off, off, off, off, off, off, off, off, off].join(",")
  return "https://api.aladhan.com/v1/timings/" + day
    + "?latitude=" + encodeURIComponent(String(lat))
    + "&longitude=" + encodeURIComponent(String(lng))
    + "&method=" + aladhanMethodId(methodId)
    + "&school=" + aladhanSchool(madhab)
    + "&tune=" + tune
}

function parseHm(hm) {
  var m = /^(\d{1,2}):(\d{2})/.exec(String(hm || ""))
  if (!m) return null
  return { h: parseInt(m[1], 10), min: parseInt(m[2], 10) }
}

function scheduleFromAladhan(raw, baseDate) {
  try {
    var data = JSON.parse(String(raw || ""))
    var timings = data && data.data && data.data.timings
    if (!timings) return null
    var map = {
      fajr: timings.Fajr,
      sunrise: timings.Sunrise,
      dhuhr: timings.Dhuhr,
      asr: timings.Asr,
      maghrib: timings.Maghrib,
      isha: timings.Isha
    }
    var schedule = []
    for (var i = 0; i < PRAYER_IDS.length; i++) {
      var id = PRAYER_IDS[i]
      var hm = parseHm(map[id])
      if (!hm) return null
      var when = new Date(
        baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate(),
        hm.h, hm.min, 0, 0
      )
      schedule.push({ id: id, date: when, hours: hm.h + hm.min / 60, source: "aladhan" })
    }
    return schedule
  } catch (e) {
    return null
  }
}

// ---------------- Habous (official Morocco ministry) ----------------

function habousUrl(villeId) {
  var id = parseInt(villeId, 10) || 117
  return "https://www.habous.gov.ma/prieres/horaire_hijri_fr.php?ville=" + id
}

function stripTags(s) {
  return String(s || "").replace(/<[^>]+>/g, "").replace(/\u00a0/g, " ").replace(/^\s+|\s+$/g, "")
}

function frenchWeekday(date) {
  return ["Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"][date.getDay()]
}

function normalizeCityKey(name) {
  return String(name || "")
    .toLowerCase()
    .replace(/[éèêë]/g, "e")
    .replace(/[àâä]/g, "a")
    .replace(/[ùûü]/g, "u")
    .replace(/[îï]/g, "i")
    .replace(/[ôö]/g, "o")
    .replace(/ç/g, "c")
    .replace(/[^a-z0-9]+/g, "")
}

function findHabousCity(cities, query) {
  var list = cities || []
  var q = normalizeCityKey(query)
  if (!q) return null
  var i
  for (i = 0; i < list.length; i++) {
    if (normalizeCityKey(list[i].name) === q) return list[i]
  }
  for (i = 0; i < list.length; i++) {
    var n = normalizeCityKey(list[i].name)
    if (n.indexOf(q) === 0 || q.indexOf(n) === 0) return list[i]
  }
  for (i = 0; i < list.length; i++) {
    if (normalizeCityKey(list[i].name).indexOf(q) >= 0) return list[i]
  }
  return null
}

function scheduleFromTimes(baseDate, times, source, offsetMinutes) {
  var keys = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]
  var off = Number(offsetMinutes) || 0
  var schedule = []
  for (var i = 0; i < keys.length; i++) {
    var hm = parseHm(times[i])
    if (!hm) return null
    var when = new Date(
      baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate(),
      hm.h, hm.min, 0, 0
    )
    if (off) when = applyOffsetMinutes(when, off)
    schedule.push({
      id: keys[i],
      date: when,
      hours: hm.h + hm.min / 60,
      source: source || "habous"
    })
  }
  return schedule
}

// Parse the official Habous monthly HTML table for one civil day.
// Columns: weekday | hijri day | gregorian day | fajr | sunrise | dhuhr | asr | maghrib | isha
function parseHabousDay(html, date) {
  var raw = String(html || "")
  var rowRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi
  var cellRe = /<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi
  var wantWeek = frenchWeekday(date)
  var wantDay = String(date.getDate())
  var match
  while ((match = rowRe.exec(raw))) {
    var cells = []
    var cm
    var block = match[1]
    cellRe.lastIndex = 0
    while ((cm = cellRe.exec(block))) cells.push(stripTags(cm[1]))
    if (cells.length < 9) continue
    var times = []
    for (var i = 0; i < cells.length; i++) {
      if (/^\d{1,2}:\d{2}$/.test(cells[i])) times.push(cells[i])
    }
    if (times.length < 6) continue
    var weekday = cells[0]
    var greg = cells[2] || ""
    var dayNums = String(greg).match(/\d+/g) || []
    if (weekday.toLowerCase().indexOf(wantWeek.toLowerCase()) < 0) continue
    if (dayNums.indexOf(wantDay) < 0) continue
    return times.slice(0, 6)
  }
  return null
}

function schedulesFromHabous(html, today, offsetMinutes) {
  var t0 = parseHabousDay(html, today)
  if (!t0) return null
  var tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1)
  var t1 = parseHabousDay(html, tomorrow)
  var todaySched = scheduleFromTimes(today, t0, "habous", offsetMinutes)
  var tomSched = t1
    ? scheduleFromTimes(tomorrow, t1, "habous", offsetMinutes)
    : null
  return { today: todaySched, tomorrow: tomSched }
}

function methodLabel(id) {
  var m = METHODS[validMethod(id)]
  return m ? m.label : id
}

function methodIds() {
  return METHOD_ORDER.slice()
}

function methodOptions() {
  var out = []
  for (var i = 0; i < METHOD_ORDER.length; i++) {
    var id = METHOD_ORDER[i]
    out.push({ value: id, label: METHODS[id].label })
  }
  return out
}

function prayerName(id, lang, when) {
  if (id === "dhuhr" && when && typeof when.getDay === "function" && when.getDay() === 5)
    return validLang(lang) === "ar" ? "الجمعة" : "Jumu'ah"
  var table = NAMES[validLang(lang)] || NAMES.en
  return table[id] || id
}

function statusLabel(status, lang) {
  if (status === "next" || status === "now" || status === "passed")
    return prayerName(status, lang)
  return ""
}

// Kaaba, Masjid al-Haram. Bearing is degrees clockwise from true north.
var KAABA_LAT = 21.422487
var KAABA_LNG = 39.826206

function qiblaBearing(lat, lng) {
  var phi = dtr(Number(lat) || 0)
  var dLon = dtr(KAABA_LNG - (Number(lng) || 0))
  var y = Math.sin(dLon)
  var x = Math.cos(phi) * Math.tan(dtr(KAABA_LAT)) - Math.sin(phi) * Math.cos(dLon)
  if (!isFinite(x) || !isFinite(y)) return 0
  return fixAngle(rtd(Math.atan2(y, x)))
}

function qiblaCardinal(bearing, lang) {
  var en = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
  var ar = ["شمال", "شمال شرق", "شرق", "جنوب شرق", "جنوب", "جنوب غرب", "غرب", "شمال غرب"]
  var idx = Math.round(fixAngle(Number(bearing) || 0) / 45) % 8
  return validLang(lang) === "ar" ? ar[idx] : en[idx]
}

function qiblaLabel(lat, lng, lang) {
  var b = Math.round(qiblaBearing(lat, lng)) % 360
  if (b < 0) b += 360
  if (validLang(lang) === "ar") return "القبلة " + b + "° " + qiblaCardinal(b, lang)
  return "Qibla " + b + "° " + qiblaCardinal(b, lang)
}

function fastingHint(now, schedule, lang) {
  if (!now || isNaN(now.getTime()) || gregorianToHijri(now).month !== 9) return ""
  var fajr = null
  var maghrib = null
  for (var i = 0; schedule && i < schedule.length; i++) {
    if (schedule[i].id === "fajr") fajr = schedule[i]
    if (schedule[i].id === "maghrib") maghrib = schedule[i]
  }
  if (!fajr || !maghrib || !fajr.date || !maghrib.date) return ""
  var t = now.getTime()
  var ar = validLang(lang) === "ar"
  if (t < fajr.date.getTime())
    return ar ? ("السحور حتى " + formatClock(fajr.date, true)) : ("Suhoor until " + formatClock(fajr.date, true))
  if (t < maghrib.date.getTime())
    return ar ? ("الإفطار عند " + formatClock(maghrib.date, true)) : ("Iftar at " + formatClock(maghrib.date, true))
  return ""
}

// Prayers whose start fell inside the recent window. A one-second poll
// misses adhan if the machine wakes after the prayer; twenty seconds catches it
// without repeating an hour later.
function duePrayers(schedule, now, withinMs) {
  var windowMs = Number(withinMs)
  if (!isFinite(windowMs) || windowMs <= 0) windowMs = 20000
  var t = now && now.getTime ? now.getTime() : 0
  var out = []
  if (!schedule) return out
  for (var i = 0; i < schedule.length; i++) {
    var item = schedule[i]
    if (!item || item.id === "sunrise" || !item.date || isNaN(item.date.getTime())) continue
    var age = t - item.date.getTime()
    if (age >= 0 && age <= windowMs) out.push(item)
  }
  return out
}

function prayerGlyph(id) {
  return GLYPHS[id] || GLYPHS.salat
}

// ---------------- astronomy ----------------

function dtr(d) { return (d * Math.PI) / 180 }
function rtd(r) { return (r * 180) / Math.PI }

function sin(d) { return Math.sin(dtr(d)) }
function cos(d) { return Math.cos(dtr(d)) }
function tan(d) { return Math.tan(dtr(d)) }
function arcsin(x) { return rtd(Math.asin(x)) }
function arccos(x) { return rtd(Math.acos(x)) }
function arctan(x) { return rtd(Math.atan(x)) }
function arctan2(y, x) { return rtd(Math.atan2(y, x)) }
function arccot(x) { return rtd(Math.atan(1 / x)) }

function fixAngle(a) {
  a = a - 360 * Math.floor(a / 360)
  return a < 0 ? a + 360 : a
}

function fixHour(a) {
  a = a - 24 * Math.floor(a / 24)
  return a < 0 ? a + 24 : a
}

function julian(year, month, day) {
  if (month <= 2) {
    year -= 1
    month += 12
  }
  var A = Math.floor(year / 100)
  var B = 2 - A + Math.floor(A / 4)
  return Math.floor(365.25 * (year + 4716)) + Math.floor(30.6001 * (month + 1)) + day + B - 1524.5
}

function sunPosition(jd) {
  var D = jd - 2451545.0
  var g = fixAngle(357.529 + 0.98560028 * D)
  var q = fixAngle(280.459 + 0.98564736 * D)
  var L = fixAngle(q + 1.915 * sin(g) + 0.020 * sin(2 * g))
  var e = 23.439 - 0.00000036 * D
  var RA = arctan2(cos(e) * sin(L), cos(L)) / 15
  RA = fixHour(RA)
  var dec = arcsin(sin(e) * sin(L))
  var EqT = q / 15 - RA
  return { declination: dec, equation: EqT }
}

function midDay(time, jDate) {
  var eqt = sunPosition(jDate + time).equation
  return fixHour(12 - eqt)
}

function sunAngleTime(angle, time, jDate, lat, direction) {
  var decl = sunPosition(jDate + time).declination
  var noon = midDay(time, jDate)
  var t = (1 / 15) * arccos((-sin(angle) - sin(decl) * sin(lat)) / (cos(decl) * cos(lat)))
  return noon + (direction === "ccw" ? -t : t)
}

function asrTime(factor, time, jDate, lat) {
  var decl = sunPosition(jDate + time).declination
  var angle = -arccot(factor + tan(Math.abs(lat - decl)))
  return sunAngleTime(angle, time, jDate, lat, "cw")
}

function timeDiff(time1, time2) {
  return fixHour(time2 - time1)
}

function computeTimes(date, lat, lng, timezone, methodId, madhab) {
  var method = METHODS[validMethod(methodId)]
  var asrFactor = validMadhab(madhab) === "Hanafi" ? 2 : 1
  var year = date.getFullYear()
  var month = date.getMonth() + 1
  var day = date.getDate()
  var jDate = julian(year, month, day) - lng / (15 * 24)

  // Iterative refinement (2 passes is enough for minute accuracy)
  var times = { fajr: 5, sunrise: 6, dhuhr: 12, asr: 13, maghrib: 18, isha: 18 }
  for (var i = 0; i < 2; i++) {
    times.fajr = sunAngleTime(method.fajr, times.fajr / 24, jDate, lat, "ccw")
    times.sunrise = sunAngleTime(0.833, times.sunrise / 24, jDate, lat, "ccw")
    times.dhuhr = midDay(times.dhuhr / 24, jDate)
    times.asr = asrTime(asrFactor, times.asr / 24, jDate, lat)
    if (method.maghribAngle && method.maghribAngle > 0)
      times.maghrib = sunAngleTime(method.maghribAngle, times.maghrib / 24, jDate, lat, "cw")
    else
      times.maghrib = sunAngleTime(0.833, times.maghrib / 24, jDate, lat, "cw")
    if (method.ishaInterval && method.ishaInterval > 0)
      times.isha = times.maghrib + method.ishaInterval / 60
    else
      times.isha = sunAngleTime(method.isha, times.isha / 24, jDate, lat, "cw")
  }

  // Apply timezone + longitude. NaN stays NaN until the polar fallback below.
  var offset = timezone - lng / 15
  var out = {}
  for (var k = 0; k < PRAYER_IDS.length; k++) {
    var id = PRAYER_IDS[k]
    out[id] = isFinite(times[id]) ? fixHour(times[id] + offset) : NaN
  }

  if (!isFinite(out.dhuhr)) out.dhuhr = fixHour(12 + (isFinite(offset) ? offset : 0))
  // Polar day or night: the sun never crosses the horizon, so sunrise and
  // maghrib are not real events. Park a short day on solar noon so the
  // timetable stays finite and ordered instead of showing an invalid clock.
  if (!isFinite(out.sunrise)) out.sunrise = fixHour(out.dhuhr - 0.1)
  if (!isFinite(out.maghrib)) out.maghrib = fixHour(out.dhuhr + 0.1)

  var night = timeDiff(out.maghrib, out.sunrise)
  if (!(night > 0)) night = 12
  if (out.fajr > out.sunrise || !isFinite(out.fajr) || night > 18)
    out.fajr = fixHour(out.sunrise - night / 7)
  if (out.isha < out.maghrib || !isFinite(out.isha) || night > 18)
    out.isha = fixHour(out.maghrib + night / 7)
  if (!isFinite(out.asr))
    out.asr = fixHour(out.dhuhr + timeDiff(out.dhuhr, out.maghrib) / 2)

  return out
}

function hoursToDate(baseDate, hours) {
  var h = fixHour(hours)
  var whole = Math.floor(h)
  var minutes = Math.floor((h - whole) * 60 + 1e-9)
  var seconds = Math.floor((((h - whole) * 60) - minutes) * 60 + 1e-9)
  var d = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate(), whole, minutes, seconds, 0)
  return d
}

function applyOffsetMinutes(date, offsetMinutes) {
  if (!date || isNaN(date.getTime())) return date
  var off = Number(offsetMinutes) || 0
  if (off === 0) return date
  return new Date(date.getTime() + off * 60000)
}

function timezoneOffsetHours(date) {
  return -date.getTimezoneOffset() / 60
}

function daySchedule(date, lat, lng, methodId, madhab, offsetMinutes) {
  var tz = timezoneOffsetHours(date)
  var hours = computeTimes(date, lat, lng, tz, methodId, madhab)
  var off = clampOffsetMinutes(offsetMinutes, 0)
  var schedule = []
  for (var i = 0; i < PRAYER_IDS.length; i++) {
    var id = PRAYER_IDS[i]
    var when = applyOffsetMinutes(hoursToDate(date, hours[id]), off)
    schedule.push({
      id: id,
      date: when,
      hours: hours[id],
      offsetMinutes: off
    })
  }
  return schedule
}

function formatClock(date, use24h) {
  if (!date || !(date instanceof Date) || isNaN(date.getTime())) return "--:--"
  var h = date.getHours()
  var m = pad2(date.getMinutes())
  if (use24h !== false) return pad2(h) + ":" + m
  var ampm = h >= 12 ? "PM" : "AM"
  var h12 = h % 12
  if (h12 === 0) h12 = 12
  return h12 + ":" + m + " " + ampm
}

function formatCountdown(ms) {
  var total = Math.max(0, Math.floor(Number(ms) / 1000) || 0)
  var hours = Math.floor(total / 3600)
  var minutes = Math.floor((total % 3600) / 60)
  var seconds = Math.floor(total % 60)
  if (hours > 0) return hours + ":" + pad2(minutes) + ":" + pad2(seconds)
  return minutes + ":" + pad2(seconds)
}

function formatCountdownShort(ms) {
  var total = Math.max(0, Math.floor(Number(ms) / 1000) || 0)
  var hours = Math.floor(total / 3600)
  var minutes = Math.floor((total % 3600) / 60)
  if (hours > 0) return hours + "h " + minutes + "m"
  if (minutes > 0) return minutes + "m"
  return "<1m"
}

function progressBetween(start, end, now) {
  var a = start.getTime()
  var b = end.getTime()
  var n = now.getTime()
  if (!(b > a)) return 0
  return Math.max(0, Math.min(1, (n - a) / (b - a)))
}

// Fraction of the civil day [0,1] for dial drawing.
function dayFraction(date) {
  if (!date || isNaN(date.getTime())) return 0
  return (date.getHours() * 3600 + date.getMinutes() * 60 + date.getSeconds()) / 86400
}

function findNext(schedule, now) {
  if (!schedule || !schedule.length) return null
  for (var i = 0; i < schedule.length; i++) {
    if (schedule[i].id === "sunrise") continue
    if (schedule[i].date.getTime() > now.getTime()) return schedule[i]
  }
  return null
}

function findCurrentWindow(schedule, now) {
  if (!schedule || !schedule.length) return null
  var prayers = []
  for (var i = 0; i < schedule.length; i++) {
    if (schedule[i].id !== "sunrise") prayers.push(schedule[i])
  }
  for (var j = 0; j < prayers.length; j++) {
    var start = prayers[j].date
    var end = j + 1 < prayers.length ? prayers[j + 1].date : null
    if (now.getTime() >= start.getTime() && (!end || now.getTime() < end.getTime())) {
      return { current: prayers[j], next: prayers[j + 1] || null, index: j }
    }
  }
  return null
}

function enrichSchedule(schedule, now, lang) {
  var next = findNext(schedule, now)
  var currentWindow = findCurrentWindow(schedule, now)
  var currentId = currentWindow && currentWindow.current ? currentWindow.current.id : ""
  var rows = []
  for (var i = 0; i < schedule.length; i++) {
    var item = schedule[i]
    var isNext = next && next.id === item.id
    var isNow = !isNext && currentId === item.id
    var passed = item.date.getTime() <= now.getTime()
    var status = isNext ? "next" : (isNow ? "now" : (passed ? "passed" : "upcoming"))
    rows.push({
      id: item.id,
      name: prayerName(item.id, lang, item.date),
      nameEn: prayerName(item.id, "en", item.date),
      nameAr: prayerName(item.id, "ar", item.date),
      glyph: prayerGlyph(item.id),
      date: item.date,
      hours: item.hours,
      time: formatClock(item.date, true),
      status: status,
      statusLabel: statusLabel(status, lang),
      isSunrise: item.id === "sunrise",
      isNext: isNext,
      isNow: isNow,
      passed: passed && !isNext && !isNow
    })
  }
  return rows
}

function nextAfterSchedule(todaySchedule, tomorrowSchedule, now) {
  var next = findNext(todaySchedule, now)
  if (next) return { prayer: next, isTomorrow: false }
  if (tomorrowSchedule && tomorrowSchedule.length) {
    for (var i = 0; i < tomorrowSchedule.length; i++) {
      if (tomorrowSchedule[i].id === "sunrise") continue
      return { prayer: tomorrowSchedule[i], isTomorrow: true }
    }
  }
  return null
}

function barLabel(style, nextInfo, now, lang) {
  if (!nextInfo || !nextInfo.prayer) return prayerGlyph("salat")
  var name = prayerName(nextInfo.prayer.id, lang, nextInfo.prayer.date)
  var remaining = nextInfo.prayer.date.getTime() - now.getTime()
  var glyph = prayerGlyph(nextInfo.prayer.id)
  var s = validBarStyle(style)
  if (s === "name") return glyph + " " + name
  if (s === "countdown") return glyph + " " + formatCountdownShort(remaining)
  if (s === "compact") return name
  return glyph + " " + name + " · " + formatCountdownShort(remaining)
}

// ---------------- Hijri (Kuwaiti algorithm) ----------------

function gregorianToHijri(date) {
  var gy = date.getFullYear()
  var gm = date.getMonth() + 1
  var gd = date.getDate()

  var jd
  if (gy > 1582 || (gy === 1582 && gm > 10) || (gy === 1582 && gm === 10 && gd > 14)) {
    jd = Math.floor((1461 * (gy + 4800 + Math.floor((gm - 14) / 12))) / 4)
      + Math.floor((367 * (gm - 2 - 12 * Math.floor((gm - 14) / 12))) / 12)
      - Math.floor((3 * Math.floor((gy + 4900 + Math.floor((gm - 14) / 12)) / 100)) / 4)
      + gd - 32075
  } else {
    jd = 367 * gy - Math.floor((7 * (gy + 5001 + Math.floor((gm - 9) / 7))) / 4)
      + Math.floor((275 * gm) / 9) + gd + 1729777
  }

  var l = jd - 1948440 + 10632
  var n = Math.floor((l - 1) / 10631)
  l = l - 10631 * n + 354
  var j = Math.floor((10985 - l) / 5316) * Math.floor((50 * l) / 17719)
    + Math.floor(l / 5670) * Math.floor((43 * l) / 15238)
  l = l - Math.floor((30 - j) / 15) * Math.floor((17719 * j) / 50)
    - Math.floor(j / 16) * Math.floor((15238 * j) / 43) + 29
  var hm = Math.floor((24 * l) / 355)
  var hd = l - Math.floor((355 * hm) / 24)
  var hy = 30 * n + j - 30

  return { year: hy, month: hm, day: hd }
}

var HIJRI_MONTHS_EN = [
  "Muharram", "Safar", "Rabiʻ I", "Rabiʻ II", "Jumada I", "Jumada II",
  "Rajab", "Shaʻban", "Ramadan", "Shawwal", "Dhul-Qaʻdah", "Dhul-Hijjah"
]

var HIJRI_MONTHS_AR = [
  "محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
  "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
]

function formatHijri(date, lang) {
  var h = gregorianToHijri(date)
  var months = validLang(lang) === "ar" ? HIJRI_MONTHS_AR : HIJRI_MONTHS_EN
  var monthName = months[Math.max(0, Math.min(11, h.month - 1))]
  if (validLang(lang) === "ar") return h.day + " " + monthName + " " + h.year + " هـ"
  return h.day + " " + monthName + " " + h.year + " AH"
}

function parseLocationFile(raw) {
  var unset = { name: "", latitude: null, longitude: null }
  try {
    var data = JSON.parse(String(raw || ""))
    if (!data || typeof data !== "object") return unset
    var latitude = parseFloat(data.latitude)
    var longitude = parseFloat(data.longitude)
    var hasCoordinates = !isNaN(latitude) && !isNaN(longitude)
    return {
      name: typeof data.name === "string" ? data.name.replace(/^\s+|\s+$/g, "") : "",
      latitude: hasCoordinates ? latitude : null,
      longitude: hasCoordinates ? longitude : null
    }
  } catch (e) {
    return unset
  }
}

function parseGeocodingResults(raw) {
  if (String(raw || "").length > 262144) return []
  try {
    var data = JSON.parse(String(raw || "{}"))
    var results = data.results
    if (!results || !results.length) return []
    var out = []
    for (var i = 0; i < Math.min(results.length, 5); i++) {
      var r = results[i]
      if (!r || !r.name || r.latitude === undefined || r.longitude === undefined) continue
      var lat = Number(r.latitude), lng = Number(r.longitude)
      if (!isFinite(lat) || !isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) continue
      var region = [r.admin1, r.country].filter(function(part) { return !!part }).join(", ")
      out.push({
        name: String(r.name).slice(0, 160),
        description: region.slice(0, 240),
        latitude: lat,
        longitude: lng
      })
    }
    return out
  } catch (e) {
    return []
  }
}

function notifyKey(prayerId, kind, dayKey) {
  return dayKey + ":" + prayerId + ":" + kind
}

function dateKey(date) {
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())
}

function dialPoints(schedule, now) {
  var t = now && now.getTime ? now.getTime() : NaN
  var points = []
  for (var i = 0; i < schedule.length; i++) {
    points.push({
      id: schedule[i].id,
      fraction: dayFraction(schedule[i].date),
      isSunrise: schedule[i].id === "sunrise",
      passed: isFinite(t) && schedule[i].date.getTime() <= t
    })
  }
  return points
}

// Geometry for the "journey" dial: where we are between the previous
// marker and the next salah. Fractions are on the 24h circle [0,1].
function dialJourney(schedule, now) {
  var empty = {
    nowFraction: dayFraction(now),
    fromFraction: 0,
    nextFraction: 0,
    nextId: "",
    prevId: "",
    remainingRatio: 0,
    elapsedRatio: 0,
    hasWindow: false
  }
  if (!schedule || !schedule.length) return empty

  var nowMs = now.getTime()
  var nowFraction = dayFraction(now)

  // Build ordered markers for the day; for "previous" include sunrise.
  var markers = []
  for (var i = 0; i < schedule.length; i++) {
    markers.push({
      id: schedule[i].id,
      date: schedule[i].date,
      fraction: dayFraction(schedule[i].date),
      isSunrise: schedule[i].id === "sunrise"
    })
  }

  var next = null
  var prev = null
  for (var j = 0; j < markers.length; j++) {
    if (markers[j].isSunrise) continue
    if (markers[j].date.getTime() > nowMs) {
      next = markers[j]
      // walk backward for previous non-empty marker (sunrise ok as prev visual)
      for (var k = j - 1; k >= 0; k--) {
        prev = markers[k]
        break
      }
      break
    }
  }

  // After Isha: previous is isha, next is tomorrow's fajr (use end-of-day + fajr)
  if (!next) {
    for (var p = markers.length - 1; p >= 0; p--) {
      if (!markers[p].isSunrise) { prev = markers[p]; break }
    }
    // Aim the remaining arc toward midnight→fajr illusion: nextFraction = fajr + 1
    var fajr = null
    for (var f = 0; f < markers.length; f++) {
      if (markers[f].id === "fajr") { fajr = markers[f]; break }
    }
    if (!prev || !fajr) return empty
    var fromF = prev.fraction
    var nextF = fajr.fraction + 1
    var nowF = nowFraction
    if (nowF < fromF) nowF += 1
    var span = nextF - fromF
    if (span <= 0) return empty
    var elapsed = Math.max(0, Math.min(span, nowF - fromF))
    return {
      nowFraction: nowFraction,
      fromFraction: fromF,
      nextFraction: fajr.fraction,
      nextId: "fajr",
      prevId: prev.id,
      remainingRatio: 1 - elapsed / span,
      elapsedRatio: elapsed / span,
      hasWindow: true,
      wrapsMidnight: true
    }
  }

  var fromFraction = prev ? prev.fraction : 0
  var nextFraction = next.fraction
  var span2 = nextFraction - fromFraction
  if (span2 <= 0) span2 += 1
  var nowF2 = nowFraction
  if (nowF2 < fromFraction) nowF2 += 1
  var elapsed2 = Math.max(0, Math.min(span2, nowF2 - fromFraction))

  return {
    nowFraction: nowFraction,
    fromFraction: fromFraction,
    nextFraction: nextFraction,
    nextId: next.id,
    prevId: prev ? prev.id : "",
    remainingRatio: 1 - elapsed2 / span2,
    elapsedRatio: elapsed2 / span2,
    hasWindow: true,
    wrapsMidnight: false
  }
}
