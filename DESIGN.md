---
name: Salat Times · Noor
description: A native prayer window in emerald, ivory and gold
colors:
  background: 'root.noor ? "#102D27" : Color.popups.background'
  foreground: 'root.noor ? "#F5EFDF" : (bar ? bar.foreground : Color.foreground)'
  accent: 'root.noor ? "#E3C68C" : Color.accent'
  muted: 'Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.76)'
  hairline: 'Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)'
  next-surface: 'Qt.rgba(root.accent.r, root.accent.g, root.accent.b, root.salat && root.salat.imminent ? 0.22 : 0.12)'
typography:
  display:
    fontFamily: '"Noto Sans"'
    fontSize: 'Style.space(62)'
    fontWeight: 'Font.Light'
  prayer-name:
    fontFamily: 'root.arabic ? "Noto Kufi Arabic" : "Noto Sans"'
    fontSize: 'Style.space(30)'
    fontWeight: 'Font.DemiBold'
  prayer-start:
    fontFamily: '"Noto Sans"'
    fontSize: 'Style.space(22)'
  heading:
    fontFamily: 'root.arabic ? "Noto Kufi Arabic" : "Noto Sans"'
    fontSize: 'Style.space(23)'
    fontWeight: 'Font.Bold'
  body:
    fontFamily: 'root.arabic ? "Noto Sans Arabic" : "Noto Sans"'
    fontSize: 'root.arabic ? Math.max(Style.font.body, Style.space(15)) : Style.font.body'
  body-small:
    fontFamily: 'root.arabic ? "Noto Sans Arabic" : "Noto Sans"'
    fontSize: 'root.arabic ? Math.max(Style.font.bodySmall, Style.space(12)) : Style.font.bodySmall'
  countdown-caption:
    fontFamily: 'root.arabic ? "Noto Sans Arabic" : "Noto Sans"'
    fontSize: 'Style.space(13)'
rounded:
  row: 'Style.cornerRadius'
spacing:
  tight: 'Style.space(2)'
  inline: 'Style.space(4)'
  control: 'Style.space(6)'
  group: 'Style.space(8)'
  row: 'Style.space(10)'
  section: 'Style.space(12)'
  stack: 'Style.space(14)'
components:
  prayer-row:
    textColor: '{colors.foreground}'
    rounded: '{rounded.row}'
    height: 'Style.space(40)'
    padding: '0 Style.space(12)'
  prayer-row-next:
    backgroundColor: '{colors.next-surface}'
    textColor: '{colors.accent}'
    rounded: '{rounded.row}'
    height: 'Style.space(50)'
    padding: '0 Style.space(12)'
---

# Design System: Salat Times

## Overview

**Creative North Star: "A moment of light"**

Noor expresses the prayer window through generous numerals, intentional Arabic typography and a clear timetable. Deep emerald grounds warm ivory text; brass gold identifies the next prayer and its start. The centered light countdown is the primary answer, with a short caption explaining its meaning.

The implementation is native Qt Quick / Quickshell on Omarchy. Noor is the persisted default appearance; System colors are an explicit alternative. Campaign direction uses a sculptural mihrab and sunlight, separate from the working interface. The user rejected the former ring and generic screenshot-on-mosque cover.

**Key Characteristics:**

- Typographic hierarchy with distinct Arabic heading and body families
- Emerald, ivory and gold by default; optional live System colors
- Clear aligned timetable with a taller next-prayer row
- Flat native surfaces and restrained motion

## Colors

### Primary

**Brass gold** marks the next prayer, exact start, divider and next timetable row. The selected row uses a translucent wash that intensifies when prayer is imminent.

### Neutral

**Deep emerald** is the default panel ground; **warm ivory** is the reading foreground. Muted foreground carries secondary dates, source, helper copy and passed prayers. Country and quick-city popups explicitly bind their background to the panel and their border to the accent.

**The Appearance Rule.** Preserve the Noor/System conditional bindings. Noor is an authored palette; System mode evaluates the current Omarchy colors instead of a screenshot palette.

## Typography

Arabic headings use Noto Kufi Arabic and body labels use Noto Sans Arabic. English uses Noto Sans; countdown, exact start and timetable numerals always use Noto Sans. The bar uses Noto Sans Arabic in Arabic and the host bar family in English.

The display countdown is light and centered, with horizontal fit down to `Style.space(34)`. The next-prayer name is demibold; the panel title is bold. The caption reads “Until the next prayer” with a tomorrow qualifier when applicable. Current and next timetable names and times are bold; other rows retain native default weights. Arabic body and small-text minimum sizes are recorded in frontmatter. Native caption and smaller helper styles continue to use `Style.font.caption` and `Style.font.bodySmall` where implemented.

**The Numeric Rule.** Keep schedule numerals right-aligned and unmirrored; apply reading alignment to language-bearing labels. Do not substitute a decorative clock face for the countdown.

## Layout

`KeyboardPanel` prefers `Style.space(400)` content width and fits height to the available screen. Vertical scrolling appears on overflow; horizontal scrolling is disabled. `Style.space` arguments are logical base units, not fixed physical pixels or web breakpoints.

The first view stacks title/language, Hijri and Gregorian dates, Qibla and location, then the typographic prayer window. A one-unit gold hairline precedes a name/start row. The centered countdown and explanatory caption follow, then today’s six timetable entries, source, refresh and settings actions. The hero has no card fill, dial or ring. Schedule names elide before the fixed `Style.space(64)` state and `Style.space(56)` time columns.

Settings replace the overview while retaining title and settings action. Worldwide setup leads with country and offline quick-city selectors, followed by method suggestions and manual search. Morocco controls appear only when the country filter is empty or MA. Lower sections retain Hijri adjustment, coordinates, calculation and reminders.

## Elevation & Depth

Local content is flat. The hairline and translucent next-row fill organize information without local shadows or glow. Native panel framing, focus, hover and control states belong to `qs.Ui`. The background rectangle extends across the panel padding. Country and city dropdown popups carry matching surface and accent border bindings.

## Shapes

Timetable highlights follow `Style.cornerRadius`; ordinary rows are compact and the next row is taller. The prayer window is an open typographic composition separated by a straight hairline. There is no circular visual component.

## Components

- **Prayer window:** gold next name and exact start above the large light countdown; centered explanatory caption beneath. Data is visible immediately when the panel opens.
- **Prayer rows:** six aligned entries with localized model status. Next uses accent, bold text, taller height and tonal fill; current uses bold text; passed rows use muted text. A preparation label replaces an empty timetable.
- **Refresh:** full-width native button reports fetching, disables while fetching or offline, and sits after any refresh error.
- **Worldwide location:** searchable 249-country dataset and 23 offline quick-city presets localized in English and Arabic. Country selection filters presets and subsequent online search. Selecting a preset commits coordinates and localized city/country text. Regional-method suggestions are enabled by default; choosing a method manually disables automatic selection. Online search reports searching, no matches and connection failure, with keyboard selection and Save/Cancel actions.
- **Contextual Habous:** section, official-source toggle and searchable Habous cities are scoped to empty/MA country filters; city selection also depends on Habous being enabled.
- **Hijri and coordinates:** ±2-day stepper with civil-calendar explanation; persistent latitude and longitude labels over equal-width unmirrored fields, validated offline Apply coordinates action, and desktop-timezone note.
- **Native settings:** reuse `Button`, `Toggle`, `SearchableDropdown`, `Dropdown`, `ButtonGroup`, `TextField`, `PanelSectionHeader` and `StepperRow`. Shared interaction styling remains native. Opening settings focuses the online toggle; closing restores panel keyboard focus.
- **Bar widget:** shared `WidgetButton` with horizontal margin and vertical padding of 8.75; imminent prayer uses its native active state. Left click opens, right cycles bar style, middle switches language. Tooltip carries next prayer, remaining time, Hijri date and location.

Settings opacity uses `NumberAnimation` with `Style.duration(160)` and `Easing.OutCubic`. Visibility and height switch immediately; do not describe this as an animated drawer expansion.

## Do's and Don'ts

### Do:

- Do preserve Noor as default and System colors as an explicit alternative.
- Do use the implemented Arabic heading/body families and Noto Sans numerals.
- Do keep country selection and offline city setup visible before contextual Morocco controls.
- Do keep native Qt Quick controls and Omarchy scale bindings.

### Don't:

- Don’t restore the rejected ring or a decorative clock face.
- Don’t put screenshot-on-mosque artwork inside the working interface.
- Don’t describe this native Linux panel as a web or mobile application.
- Don’t add glow or a reveal that delays prayer information.
