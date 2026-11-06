# Salat Times
<!-- impeccable:product-schema 1 -->

## Platform
Native Linux desktop: Qt Quick / Quickshell inside Omarchy. Keep the existing QML and JavaScript stack and native shell controls.

## Users and purpose
Omarchy users checking the next prayer and today’s prayer schedule at a glance, in Arabic or English. The daily task is to read the next prayer’s start and remaining time, then scan the rest of the schedule.

## Capabilities and constraints
Preserve Arabic/English and RTL, Hijri and Gregorian dates, Qibla, fasting hints, official Habous tables, AlAdhan and calculated fallback, worldwide location search and offline city presets, calculation methods, Asr madhab, time correction, Hijri adjustment, reminders, bar styles and keyboard controls. Times use the desktop timezone. Settings persist locally; one shared service drives the bar, schedule and reminders.

Location, Reminders and Settings open directly from the timetable as separate views. Location starts with country filtering, offline city presets and city search; weather location, contextual Morocco/Habous controls and manual coordinates are under More location options. Settings contains online tables, regional method suggestions, calculation and Hijri adjustment. Reminders contains delivery mode, at-adhan and advance alerts.

## Brand commitments
Follow the user’s live Omarchy colors and English font. Preserve deliberate Arabic typography: Noto Kufi Arabic headings and Noto Sans Arabic body text. Keep the prayer information compact, legible and immediately available. The user rejected a fixed emerald identity, oversized hero countdown, replacement English font, rings and duplicated or confusing settings.

## Operating context
A compact bar popover used frequently throughout the day. The selected direction is concept C, Prayer timeline: the countdown belongs inside the next prayer’s row. After Isha, tomorrow’s Fajr is appended with an explicit tomorrow label. Supporting actions should not overwhelm the timetable.

Prepare a public repository and marketplace submission. The selected cover is thumbnail 3, Blue-hour horizon, with a generated mosque skyline; it is promotional artwork, not an app screenshot. The concept selection and exact generation prompts are recorded in artwork/concepts/*.prompt.json. Real Arabic/English captures live in artwork/screenshots/ and carry embedded capture provenance.
