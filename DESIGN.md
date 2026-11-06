---
name: Salat Times
description: Theme-following native prayer timetable for Omarchy
colors:
  foreground: "bar ? bar.foreground : Color.foreground"
  accent: "Color.accent"
  muted: "Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.76)"
  next-surface: "Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)"
typography:
  display:
    fontFamily: "bar ? bar.fontFamily : Style.font.family"
    fontSize: "Style.space(42)"
    fontWeight: "Font.DemiBold"
  heading:
    fontFamily: "bar ? bar.fontFamily : Style.font.family"
    fontSize: "Style.font.heading"
    fontWeight: "Font.Bold"
  body:
    fontFamily: "bar ? bar.fontFamily : Style.font.family"
    fontSize: "arabic ? Math.max(Style.font.body, Style.space(14)) : Style.font.body"
  body-small:
    fontFamily: "bar ? bar.fontFamily : Style.font.family"
    fontSize: "arabic ? Math.max(Style.font.bodySmall, Style.space(12)) : Style.font.bodySmall"
  caption:
    fontFamily: "bar ? bar.fontFamily : Style.font.family"
    fontSize: "Style.font.caption"
rounded:
  row: "Style.cornerRadius"
spacing:
  tight: "Style.space(2)"
  inline: "Style.space(4)"
  control: "Style.space(6)"
  group: "Style.space(8)"
  row: "Style.space(10)"
  section: "Style.space(12)"
  stack: "Style.space(14)"
  hero-gap: "Style.space(20)"
components:
  prayer-row:
    textColor: "{colors.foreground}"
    rounded: "{rounded.row}"
    height: "Style.space(40)"
    padding: "0 Style.space(12)"
  prayer-row-next:
    backgroundColor: "{colors.next-surface}"
    textColor: "{colors.accent}"
    rounded: "{rounded.row}"
    height: "Style.space(40)"
    padding: "0 Style.space(12)"
  day-dial:
    size: "Style.space(232)"
  stepper-value:
    width: "Style.space(36)"
    height: "Style.space(22)"
---

# Design System: Salat Times

## Overview

**Creative North Star: "The countdown inside the day"**

A compact native prayer timetable that belongs to the current Omarchy desktop. The remaining time is inscribed in the day ring, and that ring’s arc is only the current prayer window. The theme supplies the font, foreground, surface, and accent.

**Key Characteristics:**

- Theme-bound native typography and color
- Aligned times with explicit next-prayer emphasis
- Flat tonal surfaces and restrained motion

These tokens are native QML expressions, evaluated by Omarchy/Quickshell. They are intentionally not CSS literals. `Style.space` and `Style.duration` retain desktop scale and motion preferences; their arguments are base logical units, not resolved device pixels. `PRODUCT.md` records the approved direction; `.impeccable/salat-surface.md` records the surface composition.

## Colors

### Primary

The live accent marks the next prayer name, next row, elapsed day arc, and next dial point. The next-row fill is a translucent accent wash.

### Neutral

Foreground follows the hosting bar with the Commons fallback. Muted foreground identifies dates, source, secondary labels, and helper copy. The panel surface and shared-control states belong to `qs.Ui`; retain their theme bindings rather than extracting a snapshot palette.

**The Theme Rule.** Preserve dynamic theme expressions; a screenshot’s colors are evidence of one theme, not a new palette.

## Typography

Use the hosting bar’s font family with `Style.font.family` as fallback. The countdown uses the display role, horizontally fits, and may shrink to `Style.space(28)`. Heading is bold; the next timetable row and dial time are bold. Standard body weights remain native defaults. Arabic body and small text have the documented minimum sizes; captions retain `Style.font.caption`.

`PlainLabel` explicitly uses `Text.PlainText` and disables mirroring. Apply reading alignment to language-bearing labels; preserve unmirrored countdown, dial time, and right-aligned timetable numerals. No custom line height, tracking, or tabular-number feature is defined.

## Layout

`KeyboardPanel` fits a preferred content width of `Style.space(400)` and fits height to the available screen. The column uses stack spacing; overview uses the same rhythm. Header and settings sections use section spacing. Vertical scrolling appears only when content overflows; horizontal scrolling is disabled.

The hero is a centered day ring of `Style.space(232)`. The prayer name, countdown, and exact start sit in the hole. Schedule rows use tight spacing, horizontal section padding, row gaps, a `Style.space(64)` state column, and a fixed `Style.space(56)` time column. Names elide before times. Qibla sits with the date. A Ramadan suhoor or iftar line appears only in that month. Settings replace the overview and retain the header and settings action; they are not a second dashboard.

## Elevation & Depth

Local content is flat and tone-separated. No local shadow or glow is defined. Panel framing, elevation, native focus, hover, and selected-control treatment are inherited from `qs.Ui`, not recreated here.

## Shapes

Timetable highlights follow `Style.cornerRadius`. The day dial is a true circle: radius is half its smaller dimension minus `Style.space(10)`; stroke is `Style.space(3)`. Its neutral track uses foreground alpha 0.14. Normal points use alpha 0.8, sunrise 0.5; next and ordinary point radii are `Style.space(4.5)` and `Style.space(2.5)`, with a `Style.space(3)` current-position point.

## Components

- **Prayer rows:** six aligned timetable entries; next is identified by accent, bold name/time, tonal fill, and a localized “Next” label. The source label remains visible beside the schedule heading.
- **DayDial:** actual 24-hour positions, clockwise from midnight at the top. Center shows the next start time; elapsed arc follows the current prayer window. Repaint only on data, size, or theme changes; no animation timer.
- **Native controls:** language and settings use `Ui.Button`; settings reuse `Toggle`, `SearchableDropdown`, `Dropdown`, `ButtonGroup`, `TextField`, and `PanelSectionHeader` from `qs.Ui`. Preserve shared interaction styling and focus behavior. Opening settings focuses its first toggle; closing restores panel keyboard focus.
- **StepperRow:** two focusable `PanelActionButton` controls surround a centered bold body-size value; inline spacing. Positive correction displays an explicit plus sign.
- **BarWidget:** shared `WidgetButton`, horizontal margin and vertical padding both 8.75. Imminent prayer sets its native active state. Left click opens the panel, right cycles style, middle switches language.

Settings opacity has a `NumberAnimation` using `Style.duration(160)` and `Easing.OutCubic`; visibility and height switch with state, so do not assume a fully animated collapse. Data is immediately visible when the panel opens. Shared panel/control motion remains owned by Omarchy.

## Do's and Don'ts

### Do:

- Do preserve live Omarchy theme bindings.
- Do keep Arabic labels readable and numeric times unmirrored.
- Do show the next prayer and its exact time before settings.

### Don't:

- Don’t introduce a fixed palette or bundled display font.
- Don’t add glow, ornamental clock motion, or a reveal that delays prayer data.
- Don’t replace native shared controls with web approximations.
