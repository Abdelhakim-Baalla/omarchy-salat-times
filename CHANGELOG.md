# Changelog

## 1.6.3

- Bound Habous cell searches to the current row, removing a quadratic scan when many closed rows contain unclosed cells.
- Add a regression case for unclosed cells spread across many rows.

## 1.6.2

- Trim Habous cell text with linear native trimming instead of the quadratic leading/trailing whitespace regex, completing the malformed-response hardening from 1.6.1.
- Bound individual Habous cell text before weekday and day matching.
- Add a regression case for long interior whitespace runs in a Habous cell.

## 1.6.1

- Parse the Habous timetable with a linear tag scan and bounded input, so a malformed or hostile response cannot block the desktop shell before the popup opens.
- Add regression checks for valid Habous tables and for oversized or unclosed HTML.

## 1.6.0

- Apply the selected wide split layout: next-prayer summary, timetable and action rail, mirrored in Arabic.
- Use Arabic for first-run and invalid/missing language settings, while respecting an explicit saved English preference.
- Fix Arabic bar labels with د/س units and isolated right-to-left ordering.
- Add localized countdown phrases and recognized city/country labels without renaming custom locations.
- Keep focused settings and add Today for Qibla, fasting information, source and refresh.
- Add a matching vector/raster brand icon, fresh wide screenshots and updated setup documentation.

## 1.5.0

- Follow Omarchy's current colors and English font; keep Noto Sans Arabic and Noto Kufi Arabic.
- Replace the large countdown block with a compact prayer timeline and an explicit tomorrow row after Isha.
- Split Location, Reminders and prayer calculation settings into focused views; disclose advanced location options on demand.
- Remove duplicate language controls, repeated past-prayer labels and the redundant city-save action.
- Fix city-search focus, stale responses after clearing/canceling, hidden-loader gaps and empty searches changing the location.
- Add native search interaction regression checks and preserve the 249-country, offline-city and calculation coverage.
- Publish the selected blue-hour mosque cover, fresh bilingual screenshots and clearer setup documentation.

## 1.4.0

- Replace the ring with a typographic next-prayer layout and remove the unused dial component.
- Add Noor emerald, ivory and gold appearance, plus an optional System colors mode.
- Use Noto Sans Arabic for Arabic body text, Noto Kufi Arabic headings and Noto Sans numerals; localize the Gregorian date.
- Add a searchable English/Arabic list of 249 countries and territories, filtered city search and 23 offline city presets.
- Suggest regional methods for Saudi Arabia, Egypt, USA/Canada and other supported conventions, with manual override.
- Expand offline/API methods for Gulf, Kuwait, Qatar, Singapore, France, Turkey, Russia, Dubai, Malaysia and Indonesia.
- Keep Morocco-only controls contextual; add direct country-to-city selection IPC.
- Replace the marketplace cover with the Noor architectural campaign artwork.

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
