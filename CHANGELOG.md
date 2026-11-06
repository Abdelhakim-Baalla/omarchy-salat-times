# Changelog

## 1.3.0

- Redesigned next-prayer surface with a prominent countdown, compact day dial, and taller timetable rows.
- Fixed the Hijri conversion; added an independent ±2 day moon-sighting adjustment used by Ramadan hints.
- Added offline coordinate entry, worldwide city-search feedback, and an explicit refresh action.
- International search results leave the Morocco-only Habous source. API timestamps retain their timezone offset and requests use the desktop timezone.
- Rebuild local schedules immediately after settings changes and midnight; cancel outdated requests and bound reminder history.
- Correct Morocco, Algeria, and Tunisia AlAdhan method identifiers; reject invalid time and weather-coordinate data.
- Added settings IPC, new real screenshots, and mosque marketplace artwork.

## 1.2.0

- The countdown sits inside the day ring. The arc is the current prayer window, and passed marks on the ring step back.
- Friday Dhuhr is labeled Jumu'ah. The timetable marks passed, now, and next.
- Qibla bearing from the selected coordinates, and a Ramadan line for suhoor and iftar.
- Adhan still fires if the clock jumps past the prayer, within twenty seconds, and a failed Habous request no longer asks AlAdhan twice.
- Polar night and polar day keep six finite, ordered times instead of an invalid clock.

## 1.1.0

- Theme-aware timetable with a prominent next-prayer countdown and a quieter day orbit.
- Mirrored Arabic layout with improved reading sizes, plus a visible language action.
- Dedicated settings view with keyboard focus and Escape navigation.
- Offline calculation switch; hourly online table refresh can be disabled.
- Verified HTTPS requests, bounded responses, and validated city-search coordinates.
- Fixed invalid top-level QML helper declarations and used literal text rendering.
- Added installation/removal documentation, license, preview captures, and model regression checks.
