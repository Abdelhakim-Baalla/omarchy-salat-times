# Salat Times
<!-- impeccable:product-schema 1 -->

## Platform
Native Linux desktop: Qt Quick / Quickshell inside Omarchy. Keep the existing QML and JavaScript stack and native shell controls.

## Users and purpose
Omarchy users checking the next prayer and today’s prayer schedule at a glance, in Arabic or English. The daily task is to read the next prayer’s start and remaining time, then scan the rest of the schedule. Arabic is the initial and fallback language; an explicitly saved English preference remains valid.

## Capabilities and constraints
Preserve Arabic/English and RTL, Hijri and Gregorian dates, Qibla, fasting hints, official Habous tables, AlAdhan and calculated fallback, worldwide location search and offline city presets, calculation methods, Asr madhab, time correction, Hijri adjustment, reminders, bar styles and keyboard controls. Times use the desktop timezone. Settings persist locally; one shared service drives the bar, schedule and reminders.

Location, Reminders, Settings and Today open directly from the overview as separate views. Location starts with country filtering, offline city presets and city search; weather location, contextual Morocco/Habous controls and manual coordinates are under More location options. Settings contains online tables, regional method suggestions, calculation and Hijri adjustment. Reminders contains delivery mode, at-adhan and advance alerts. Today contains dates, Qibla, the active timetable source, conditional fasting guidance, update errors and refresh.

Recognized built-in city and country names follow the selected language when the stored coordinates match the preset. User-defined location labels remain intact.

Arabic bar countdowns use localized hour/minute units and an Arabic sub-minute phrase. Direction isolation keeps Arabic labels, numerals and neighboring bar widgets in their intended reading order; English formatting remains unchanged.

## Brand commitments
Follow the user’s live Omarchy colors and English font. Preserve deliberate Arabic typography: Noto Kufi Arabic headings and Noto Sans Arabic body text. Keep the prayer information legible and immediately available. Use the selected moderate natural-language countdown emphasis. The user rejected a fixed emerald identity, oversized countdown numerals, replacement English font, rings and duplicated or confusing settings.

## Operating context
A native bar popover used frequently throughout the day. The selected direction is concept B, Wide split view: a next-prayer summary with a natural-language countdown, localized location and dates sits beside a six-row timetable. A single divider separates them, and a separate action rail holds Settings, language and Today. Location and Reminders sit below the summary. Arabic mirrors the composition. The summary explicitly identifies tomorrow’s next prayer after the final prayer of the day; the timetable continues to show today’s six entries.

The overview prefers 900 Omarchy logical units fitted to the available screen and stacks below 700 fitted units. Focused views prefer 400 units. This is native desktop adaptation, not a mobile interface.

Prepare a public repository and marketplace submission. The selected cover remains thumbnail 3, Blue-hour horizon, with a generated mosque skyline; it is promotional artwork, not an app screenshot. The selected UI reference is artwork/concepts/ui-b-wide.png. Concept generation prompts are recorded in artwork/concepts/*.prompt.json. Current Arabic/English review captures are .impeccable/review/wide-ar.png and .impeccable/review/wide-en.png; shipping screenshot assets live in artwork/screenshots/ and carry embedded capture provenance.

The authored vector icon.svg and its raster icon.png provide a mosque-arch identity for the README and proposed marketplace icon support. The current marketplace renders initials and cannot yet display the icon; do not describe icon support as shipped.
