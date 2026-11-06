---
name: Salat Times · Prayer timeline
description: A compact native prayer timeline that follows Omarchy
colors:
  background: 'Color.popups.background'
  foreground: 'bar ? bar.foreground : Color.foreground'
  accent: 'Color.accent'
  muted: 'Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.76)'
  hairline: 'Qt.alpha(root.accent, 0.45)'
  timeline: 'Qt.alpha(root.accent, 0.4)'
  next-surface: 'Qt.alpha(root.accent, 0.12)'
typography:
  heading:
    fontFamily: 'root.arabic ? "Noto Kufi Arabic" : root.systemFontFamily'
    fontSize: 'Style.space(21)'
    fontWeight: 700
  body:
    fontFamily: 'root.arabic ? "Noto Sans Arabic" : root.systemFontFamily'
    fontSize: 'root.arabic ? Math.max(Style.font.body, Style.space(15)) : Style.font.body'
  body-small:
    fontFamily: 'root.arabic ? "Noto Sans Arabic" : root.systemFontFamily'
    fontSize: 'Style.font.bodySmall'
  caption:
    fontFamily: 'root.arabic ? "Noto Sans Arabic" : root.systemFontFamily'
    fontSize: 'Style.font.caption'
  prayer-time:
    fontFamily: 'root.systemFontFamily'
    fontSize: 'Style.space(16)'
  next-time:
    fontFamily: 'root.systemFontFamily'
    fontSize: 'Style.space(18)'
    fontWeight: 700
rounded:
  row: 'Style.cornerRadius'
  marker: '1'
spacing:
  tight: 'Style.space(2)'
  caption: 'Style.space(3)'
  inline: 'Style.space(4)'
  control: 'Style.space(6)'
  group: 'Style.space(8)'
  row: 'Style.space(10)'
  section: 'Style.space(12)'
  stack: 'Style.space(14)'
components:
  prayer-row:
    textColor: '{colors.foreground}'
    height: 'Style.space(42)'
  prayer-row-next:
    textColor: '{colors.accent}'
    height: 'Style.space(66)'
  prayer-row-surface:
    rounded: '{rounded.row}'
    padding: 'Style.space(10)'
  prayer-row-next-surface:
    backgroundColor: '{colors.next-surface}'
    rounded: '{rounded.row}'
    padding: 'Style.space(10)'
  timeline-marker:
    backgroundColor: '{colors.foreground}'
    rounded: '{rounded.marker}'
    size: 'Style.space(5)'
  timeline-marker-next:
    backgroundColor: '{colors.accent}'
    rounded: '{rounded.marker}'
    size: 'Style.space(8)'
---

# Design System: Salat Times

## Overview

**Creative North Star: "Prayer timeline"**

The user selected concept C on 6 November 2026. A chronological list is the main composition: the next prayer expands just enough to contain its countdown, while the exact start remains aligned with every other prayer time. The working panel is calm, compact and integrated with Omarchy.

This is a code-led native Qt Quick adaptation, documented from `Panel.qml`, `BarWidget.qml`, `StepperRow.qml` and the shared `Service.qml`, then checked against actual Arabic/English timeline and focused-settings captures. The token frontmatter intentionally preserves symbolic QML bindings instead of freezing a screenshot palette; it is not a CSS token export. `root.systemFontFamily` resolves to `bar.fontFamily`, falling back to `Style.font.family`.

**Key Characteristics:**

- One integrated countdown inside the next prayer row
- Live desktop colors and English/numeric typography
- Noto Arabic families and a mirrored reading layout
- Thin timeline, square markers and flat native controls
- Direct, distinct Location, Reminders and Settings views

## Colors

### Primary

**Live Omarchy accent** marks the next prayer, its time and its larger timeline marker. Translucent accent supplies the next-row wash, timeline and horizontal separators. The row wash stays at its documented opacity; imminent emphasis belongs to the bar’s native active state.

### Neutral

**Live popup background** and **live bar foreground** keep the panel in the current desktop theme. **Muted foreground** is used for passed prayers, Hijri date and helper text. Dropdown surfaces bind to the popup background and their popup borders to the accent.

**The Desktop Theme Rule.** Keep the live bindings. The navy, cream and peach in the review captures are one Omarchy theme, not fixed product colors. There is no user-facing appearance switch.

## Typography

The panel’s English labels and exact prayer-time numerals use the current bar font, with the host style family as fallback. Arabic headings use Noto Kufi Arabic; Arabic body text and the integrated countdown caption use Noto Sans Arabic. The bar follows the same Arabic-body/English-system split. Native text fields retain their host typography.

The location or focused-view title is the heading role. Prayer names use body text; the next and current names are bold. Exact prayer times use the prayer-time role, stepping up only to next-time for the next prayer. Dates, Qibla, source/refresh and the countdown use body-small; form labels and small explanations use caption. No separate display countdown is used.

**The Numeric Rule.** Exact prayer times stay right-aligned in their fixed-width column and disable layout mirroring. Arabic mirrors the row composition and label alignment, while the digits remain in their ordinary reading order. Do not replace the English or numeric family with a product-specific font.

## Layout

`KeyboardPanel` prefers `Style.space(400)` content width and fits its height to the available screen. The main column uses the stack spacing token; sections use section spacing. Vertical scrolling appears on overflow; horizontal scrolling is disabled. `Style.space` values are logical base units, not fixed physical pixels or web breakpoints.

The overview contains location/language, Gregorian and Hijri dates, a separator, the timeline, an optional fasting hint, another separator, Qibla with source/refresh, and three equal-width actions. The six daily entries remain chronological. After Isha, an additional next-Fajr row carries an explicit “tomorrow” label and its countdown. There is no repeated hero, status column or series of “Passed” labels.

Each timeline row reserves `Style.space(22)` for the line/marker gutter. Its content surface is four logical units shorter than its row and vertically centered. The time column is `Style.space(63)` wide; the prayer name elides first. The one-unit line sits eight logical units from the reading edge; only its half toward adjacent entries is drawn at each end.

A focused view replaces the overview and keeps the language control plus Back to timetable. Location, Reminders and Settings are direct destinations, not duplicate forms. Location’s extra options are collapsed initially. Opening a destination closes transient menus, cancels a pending location search, resets scroll position and focuses Back to timetable; returning restores panel keyboard focus.

## Elevation & Depth

The timeline and its local content use tonal layering without local shadows or glow. Native `qs.Ui` owns panel framing, hover, focus, pressed states and control geometry. A background rectangle extends across panel padding so the native surface stays coherent. The three focused views switch immediately; the current panel defines no custom reveal or settings-opacity animation.

## Shapes

Use a straight timeline and small square markers. Marker corners have the marker radius; row highlights follow the live host corner radius. Ordinary timeline content is transparent; only the next row has a filled surface. Retain the native control shapes rather than introducing a second card or button system.

## Components

- **Prayer timeline:** next row uses accent name/time, a larger marker and tonal wash. Its body-small countdown sits under the name in normal foreground. Current prayer name is bold; passed entries use muted text. An empty schedule shows Preparing prayer times.
- **Qibla and refresh:** Qibla occupies the flexible portion of a compact row. The adjacent button combines the actual source with Refresh, reports Updating while fetching, and disables while offline or busy. Refresh errors wrap below it.
- **Destination actions:** three equal-width native buttons open Location, Reminders or prayer Settings. The full-width Back to timetable button is shared by these views.
- **Location:** current-location text, country filter, offline city presets and Search any city form the primary path. Search shows busy, no-match and connection-error feedback; Up/Down changes selection, Enter or a result click commits it, and Cancel search exits. More location options reveals weather adoption, contextual Habous controls and validated coordinates. Habous controls are limited to an empty or MA country filter.
- **Prayer settings:** online-table and regional-method toggles, time-correction stepper, method dropdown, Asr button group and Hijri adjustment. Manual method selection disables the automatic suggestion. Shared `Toggle`, `Dropdown`, `ButtonGroup` and `PanelSectionHeader` remain native.
- **Reminders:** Notify/Overlay/Silent button group, at-adhan and advance toggles, plus a lead-minute stepper visible when advance reminders are enabled. `StepperRow` uses two native action buttons around a centered bold value.
- **Bar widget:** shared `WidgetButton`, with horizontal margin and vertical padding of 8.75. Native active state indicates an imminent prayer. Left click opens the panel, right click cycles bar styles and middle click switches language. Its tooltip includes the next prayer, remaining time, Hijri date and location.

The optional full-screen adhan overlay remains a separate `Service.qml` surface. Its English text uses `Style.font.family`, and Arabic uses Noto Sans Arabic. These review captures cover the bar popover and its focused views, not the overlay layout.

## Do's and Don'ts

### Do:

- Do keep the next start and countdown together in the timeline, including the explicit tomorrow row at the day boundary.
- Do bind popup colors and English/numeric fonts to the live desktop, retaining the Noto Arabic heading/body split.
- Do preserve direct destination actions and initially hidden advanced location controls.
- Do use native Qt Quick controls, keyboard focus and Omarchy scale bindings.
- Do distinguish concept artwork from real screenshots. The selected concept is `artwork/concepts/ui-c-timeline.png`, with its exact prompt and approval in the adjacent `.prompt.json`.
- Do use the selected blue-hour skyline for the marketplace cover. `artwork/concepts/thumbnail-3-blue-hour.prompt.json` and embedded PNG metadata record its OpenAI ImageGen provenance; `marketplace.png` and `preview.png` are the selected cover. Actual captures in `artwork/screenshots/` record their direct desktop-capture provenance.

### Don't:

- Don’t restore a fixed emerald palette, an appearance selector, oversized hero numerals, a separate countdown card or a ring.
- Don’t duplicate settings across views or expose the entire advanced location form on entry.
- Don’t treat illustrative concept times or the blue-hour cover as a product screenshot; keep campaign imagery outside the working interface.
- Don’t describe this native Linux implementation as a web or mobile screen. No HTML detector, mobile review or measured concept-diff result is claimed by this document.
