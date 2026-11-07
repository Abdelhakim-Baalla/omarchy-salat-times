---
name: Salat Times · Wide split view
description: A native prayer overview that follows Omarchy and reads naturally in Arabic and English
colors:
  background: 'Color.popups.background'
  foreground: 'bar ? bar.foreground : Color.foreground'
  accent: 'Color.accent'
  muted: 'Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.76)'
  divider: 'Qt.alpha(root.contentForeground, 0.35)'
typography:
  display:
    fontFamily: 'root.arabic ? "Noto Sans Arabic" : root.systemFontFamily'
    fontSize: 'Style.space(32)'
    fontWeight: 700
  headline:
    fontFamily: 'root.arabic ? "Noto Kufi Arabic" : root.systemFontFamily'
    fontSize: 'Style.space(26)'
    fontWeight: 700
  title:
    fontFamily: 'root.arabic ? "Noto Kufi Arabic" : root.systemFontFamily'
    fontSize: 'Style.space(21)'
    fontWeight: 700
  next-detail:
    fontFamily: 'root.arabic ? "Noto Sans Arabic" : root.systemFontFamily'
    fontSize: 'Style.space(16)'
  location:
    fontFamily: 'root.arabic ? "Noto Sans Arabic" : root.systemFontFamily'
    fontSize: 'Style.space(15)'
  date:
    fontFamily: 'root.arabic ? "Noto Sans Arabic" : root.systemFontFamily'
    fontSize: 'Style.space(14)'
  prayer-name:
    fontFamily: 'root.arabic ? "Noto Sans Arabic" : root.systemFontFamily'
    fontSize: 'Style.space(19)'
  prayer-time:
    fontFamily: 'root.systemFontFamily'
    fontSize: 'Style.space(19)'
  body:
    fontFamily: 'root.arabic ? "Noto Sans Arabic" : root.systemFontFamily'
    fontSize: 'Style.font.body'
  body-small:
    fontFamily: 'root.arabic ? "Noto Sans Arabic" : root.systemFontFamily'
    fontSize: 'Style.font.bodySmall'
  caption:
    fontFamily: 'root.arabic ? "Noto Sans Arabic" : root.systemFontFamily'
    fontSize: 'Style.font.caption'
spacing:
  tight: 'Style.space(2)'
  stepper: 'Style.space(4)'
  control: 'Style.space(6)'
  group: 'Style.space(8)'
  summary: 'Style.space(9)'
  row: 'Style.space(10)'
  section: 'Style.space(12)'
  stack: 'Style.space(14)'
  split: 'Style.space(24)'
components:
  overview-summary:
    width: 'Style.space(310)'
    textColor: '{colors.foreground}'
  next-countdown:
    textColor: '{colors.accent}'
    typography: '{typography.display}'
  prayer-row:
    textColor: '{colors.foreground}'
    height: 'Style.space(43)'
  prayer-row-next:
    textColor: '{colors.accent}'
    height: 'Style.space(43)'
  divider:
    backgroundColor: '{colors.divider}'
    width: '1'
  action-rail:
    width: 'Style.space(132)'
  action-button:
    textColor: '{colors.foreground}'
  language-button:
    textColor: '{colors.muted}'
---

# Design System: Salat Times

## Overview

**Creative North Star: "Wide split view"**

The user-selected concept B gives the next prayer a concise summary beside a clear daily timetable. The native surface is calm and direct: a natural-language countdown leads the summary, exact times align in equal rows, and a single divider gives the two reading tasks their own space. Arabic mirrors the composition and is the initial language; an explicit English preference remains available.

The visual system follows live Omarchy colors and English typography, with deliberate Noto Arabic families. This document is extracted from the current QML and JavaScript and checked against the Arabic and English wide-panel captures. The frontmatter preserves native QML bindings as the source of truth; it is not a CSS token export. `root.systemFontFamily` resolves to `bar.fontFamily`, falling back to `Style.font.family`.

**Key Characteristics:**

- Separate next-prayer summary with a natural-language countdown
- Six equal timetable rows with accent emphasis on the next prayer
- Live desktop colors and English/numeric typography
- Noto Arabic families and a mirrored composition
- Flat native actions and focused secondary views

## Colors

### Primary

**Live Omarchy accent** emphasizes the spoken countdown and the next prayer’s name and exact start. The next row uses accent text and bold weight without a filled card. Native controls use the same accent for their host-defined interaction states.

### Neutral

**Live popup background** and **live bar foreground** keep the panel part of the desktop. **Muted reading foreground** supports dates, helper text and the overview language action. **Quiet divider** separates the summary and timetable using translucent foreground. All other timetable rows retain normal foreground; passed rows are not dimmed in this composition.

**The Desktop Theme Rule.** Keep live color bindings. The navy, cream and peach in the captures belong to the active Omarchy theme; they are not fixed interface colors. There is no user-facing appearance switch.

## Typography

English text and timetable numerals use the current bar font, with the host style family as fallback. Arabic headings use Noto Kufi Arabic; Arabic body text and the natural-language countdown use Noto Sans Arabic. Native text fields retain their host typography.

The display role is the countdown phrase, with horizontal fitting down to `Style.space(22)` when needed. Headline names the app; title names a focused view. Next-detail combines the next prayer, optional tomorrow label and exact start. Location and date roles keep geographic and calendar context subordinate. Prayer-name and prayer-time share the same size; only the next entry is bold. Body, body-small and caption serve focused-view content and form explanations.

**The Numeric Rule.** Timetable clocks keep the live system font and disable layout mirroring. Arabic mirrors the row composition and label alignment while preserving the ordinary reading order of time digits.

Compact bar countdowns use Arabic `س` and `د` units, with `أقل من دقيقة` below one minute. `Model.formatCountdownShort` isolates Arabic durations with Unicode RLI/PDI, and `Model.barLabel` isolates the complete Arabic label in all four bar styles. This keeps numbers and Arabic units together without affecting adjacent widgets. English compact formatting remains unchanged; the overview retains its separate natural-language countdown.

## Layout

`KeyboardPanel` centers on the bar and fits a preferred overview content width of `Style.space(900)` to the screen. English reads summary, divider, timetable, then action rail; Arabic reverses that composition. The summary and rail use their frontmatter widths, with the timetable taking the remaining width. Flow gaps use the split spacing token. Shared body height is the greatest of summary text plus `Style.space(54)`, timetable height, or `Style.space(280)`.

The summary contains the title, next-prayer/start line, countdown phrase, localized location, Gregorian date and Hijri date. Location and Reminders are equal-width buttons anchored below it. Settings sits at the top of the action rail; language and Today sit at its bottom. The six timetable entries use equal-height rows with tight vertical gaps. Names take the remaining row width and elide before clocks; clock width follows its text. The summary marks tomorrow’s next prayer explicitly after today’s last prayer, while the timetable retains today’s six entries.

Below `Style.space(700)` of fitted content width, the Flow stacks the summary, divider, timetable and action rail at full width. The divider becomes horizontal. These are native logical-scale rules, not mobile or browser breakpoints. Height fits the available screen; vertical scrolling appears on overflow and horizontal scrolling is disabled.

Location, Reminders, Prayer settings and Today replace the overview at a preferred width of `Style.space(400)`. They share a title, language action and full-width Back to timetable action. Opening a destination closes menus, cancels location search, resets scroll and focuses Back to timetable. Returning restores panel keyboard focus. Location’s extra options start collapsed.

## Elevation & Depth

The overview uses a flat background, a single divider and type hierarchy without local shadows, glow or filled timetable rows. Native `qs.Ui` owns panel framing, control geometry and hover, focus and pressed states. A background rectangle extends across the panel padding. Focused views switch immediately; the current panel defines no custom reveal or settings-opacity animation.

## Shapes

The composition uses straight alignment and a thin divider. Location, Reminders, Settings and Today use native bordered icon buttons; language uses a quiet native text button. Keep corner geometry and control outlines owned by the host rather than assigning an independent radius system. The working panel contains no promotional imagery.

## Components

- **Next-prayer summary:** the localized next-prayer line carries its exact start and tomorrow context; the separate accent countdown uses `Model.formatNextCountdown`. That function rounds remaining time up to minutes and formats a short duration in the selected language. Recognized preset city/country labels translate only when their stored name and coordinates match; custom labels remain intact.
- **Timetable:** six name/time rows from the shared service. Next-prayer text is accent and bold; other rows use normal foreground and weight. No timeline gutter, status column or countdown is embedded in a row. An empty schedule shows Preparing prayer times.
- **Overview actions:** paired Location/Reminders actions belong below the summary. Settings, language and Today occupy the rail. Native buttons are focusable; the language label names the destination language and uses its appropriate font.
- **Today:** dates, Qibla and the active Habous, AlAdhan or offline-calculation source appear in a focused view. A fasting hint appears when applicable, refresh errors wrap, and Refresh times shows its busy label and is disabled while fetching or online tables are disabled.
- **Location:** current location, country filter, offline presets and Search any city form the primary path. Search provides busy, no-match and connection-error feedback; Up/Down changes selection, Enter or clicking a result commits it, and Cancel search exits. More location options reveals weather adoption, contextual Habous controls and validated coordinates. Habous controls apply to an empty or MA country filter.
- **Prayer settings:** online-table and regional-method toggles, time-correction stepper, method dropdown, Asr button group and Hijri adjustment. Manual method selection disables the automatic suggestion. Shared `Toggle`, `Dropdown`, `ButtonGroup` and `PanelSectionHeader` stay native.
- **Reminders:** Notify/Overlay/Silent selection, at-adhan and advance toggles, plus a lead-minute stepper visible when advance reminders are enabled. `StepperRow` uses native minus/plus actions around a centered bold value.
- **Bar widget:** shared `WidgetButton` follows the live system font or Noto Sans Arabic and uses its native active state when a prayer is imminent. Arabic compact durations use localized units and isolated direction; the shared service also supplies the localized short duration to tooltips and advance reminders. Left click opens the panel, right click cycles bar styles and middle click switches language. The tooltip includes next-prayer context, remaining time, Hijri date and location.

The optional full-screen adhan overlay remains a separate `Service.qml` surface, using `Style.font.family` for English and Noto Sans Arabic for Arabic. The current wide-panel captures do not validate that overlay’s layout.

## Do's and Don'ts

### Do:

- Do preserve concept B’s summary, divider, six-row timetable and action rail, mirrored for Arabic and stacked when fitted width is limited.
- Do bind interface colors and English/numeric fonts to the live desktop while retaining the Noto Arabic heading/body split.
- Do keep Arabic as the default and retain an explicitly saved English choice.
- Do keep distinct focused destinations, visible keyboard focus and initially hidden advanced location controls.
- Do distinguish the selected generated concept in `artwork/concepts/ui-b-wide.png` from current native captures in `.impeccable/review/wide-ar.png` and `.impeccable/review/wide-en.png`.
- Do retain the selected blue-hour cover and its generation provenance. The authored `icon.svg` and raster `icon.png` belong to README branding and proposed marketplace support; their palette does not replace live interface colors.

### Don't:

- Don’t add a fixed emerald palette, an appearance selector, oversized countdown numerals or a ring.
- Don’t duplicate settings across views or expose all advanced location controls on entry.
- Don’t present concept data or the blue-hour cover as a real app screenshot.
- Don’t claim the marketplace displays the new icon: it currently renders initials.
- Don’t describe this native Linux implementation as a browser or mobile interface, or claim a measured concept-diff result.
