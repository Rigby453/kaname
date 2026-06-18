# 02 — Typography, Spacing & Elevation
> Kaizen design system — implementation-ready specification.
> Single source of truth for type scale, font pairings, spacing, radius, and elevation rules.
> Companion to `/docs/design-tokens.json`. When values conflict, this file wins for typography/spacing; design-tokens.json wins for colours/animation.

---

## 1. Universal Type Scale

One scale, shared across all five themes. Theme personality comes from the font pairing (section 2), not from different sizes. All sizes are in logical pixels (sp/dp).

| Role | Flutter TextTheme slot | fontSize | fontWeight | lineHeight (height×) | letterSpacing | Usage |
|---|---|---|---|---|---|---|
| **display** | `displayLarge` | 48 | 700 | 1.05 | -0.5 | Hero numbers, splash figures, wrapped stats |
| **headlineLarge** | `headlineLarge` | 34 | 700 | 1.10 | -0.3 | Screen-level titles (Today greeting, Plan month header) |
| **headlineMedium** | `headlineMedium` | 28 | 700 | 1.12 | -0.2 | Section headers, modal titles |
| **headlineSmall** | `headlineSmall` | 22 | 600 | 1.15 | -0.1 | Card headings, sheet titles |
| **titleLarge** | `titleLarge` | 18 | 600 | 1.20 | 0.0 | AppBar title, list section labels |
| **titleMedium** | `titleMedium` | 16 | 600 | 1.25 | 0.0 | Task titles (priority=main), dialog headings |
| **titleSmall** | `titleSmall` | 14 | 600 | 1.25 | 0.1 | Task titles (regular), chip labels, tab labels |
| **bodyLarge** | `bodyLarge` | 16 | 400 | 1.50 | 0.0 | Primary body copy, diary entry text |
| **bodyMedium** | `bodyMedium` | 14 | 400 | 1.50 | 0.0 | Secondary body copy, date strings, descriptions |
| **bodySmall** | `bodySmall` | 12 | 400 | 1.45 | 0.1 | Supporting text, metadata, subtitles |
| **labelLarge** | `labelLarge` | 14 | 500 | 1.20 | 0.5 | Buttons (filled, outlined), primary CTAs |
| **labelMedium** | `labelMedium` | 12 | 500 | 1.20 | 0.4 | Secondary buttons, pill chips |
| **labelSmall** | `labelSmall` | 10 | 500 | 1.20 | 0.6 | Badges, micro-labels, timestamps |
| **caption** | `labelSmall` (override) | 11 | 400 | 1.35 | 0.3 | Muted inline notes, form helper text |

### Scale design rationale

The jumps are intentional and significant:
- 10 → 11 → 12 → 14 → 16 → 18 → 22 → 28 → 34 → 48
- From `titleMedium` (16) to `headlineSmall` (22) is a 37.5% jump — enough to clearly separate screen structure from content without going gigantic.
- From `headlineMedium` (28) to `headlineLarge` (34) to `display` (48) creates a confident poster-weight top tier that makes the greeting and stats feel premium.
- `display` uses height 1.05 (tight) because these are always short strings (1–3 words). All body roles use 1.45–1.50 (generous) for readability.
- `labelLarge` uses letterSpacing 0.5 to give buttons an airy, confident feel at 14px rather than cramped.

---

## 2. Font Pairings Per Theme

All fonts listed here are available via the `google_fonts` package as of mid-2025. Where the token's listed font is unavailable or has a specific issue, the replacement and reason are noted.

| Theme | Display font | Body font | Change from current? | Reason |
|---|---|---|---|---|
| **focus** | Fraunces | Hanken Grotesk | No change | Fraunces Italic at w700 gives the warm serif mood; Hanken Grotesk is clean and pairs perfectly. Keep. |
| **calm** | Newsreader | DM Sans | **body: Mulish → DM Sans** | Mulish is lightweight and samey at body sizes. DM Sans has a calmer, more refined geometric feel with better optical spacing at 14–16px. Same weights available. |
| **black** | Schibsted Grotesk | Schibsted Grotesk | No change | Mono-font is intentional — pure system feel for OLED. Differentiation comes from weight contrast (display w700 vs body w400) and generous tracking, not font personality. |
| **white** | Instrument Serif | Plus Jakarta Sans | **body: Geist (→ Inter stub) → Plus Jakarta Sans** | Geist is still absent from google_fonts. Plus Jakarta Sans is a stronger, more characterful choice than Inter as a permanent body font for the white theme — slightly humanist with good optical sizing at small scales. Remove the TODO stub. |
| **contrast** | Atkinson Hyperlegible | Atkinson Hyperlegible | No change | Purpose-built for low-vision users; using anything else would undermine accessibility. Keep identical, rely on the 1.15× scale modifier. |

### Google Fonts availability notes

- `Fraunces`: available — `GoogleFonts.fraunces()`
- `Hanken Grotesk`: available — `GoogleFonts.hankenGrotesk()`
- `Newsreader`: available — `GoogleFonts.newsreader()`
- `DM Sans`: available — `GoogleFonts.dmSans()`
- `Schibsted Grotesk`: available — `GoogleFonts.schibstedGrotesk()`
- `Instrument Serif`: available — `GoogleFonts.instrumentSerif()`
- `Plus Jakarta Sans`: available — `GoogleFonts.plusJakartaSans()`
- `Atkinson Hyperlegible`: available — `GoogleFonts.atkinsonHyperlegible()`
- `Geist`: NOT available in google_fonts package — replaced permanently by Plus Jakarta Sans in white theme.

---

## 3. Contrast Theme: 1.15× Scale Application

The contrast theme uses `font_scale.contrast = 1.15` from design-tokens.json. This is applied as `MediaQuery.textScaler` at the app root (currently in `main.dart`), not inside TextTheme — that approach is correct and must be preserved.

### What 1.15× produces from the base scale

| Role | Base fontSize | ×1.15 result | Rounded implementation |
|---|---|---|---|
| display | 48 | 55.2 | **55** |
| headlineLarge | 34 | 39.1 | **39** |
| headlineMedium | 28 | 32.2 | **32** |
| headlineSmall | 22 | 25.3 | **25** |
| titleLarge | 18 | 20.7 | **21** |
| titleMedium | 16 | 18.4 | **18** |
| titleSmall | 14 | 16.1 | **16** |
| bodyLarge | 16 | 18.4 | **18** |
| bodyMedium | 14 | 16.1 | **16** |
| bodySmall | 12 | 13.8 | **14** |
| labelLarge | 14 | 16.1 | **16** |
| labelMedium | 12 | 13.8 | **14** |
| labelSmall | 10 | 11.5 | **12** |

### Contrast theme additional rules

- `fontWeight` is bumped one step up for display and headline roles ONLY: w700 → **w800**. Body and label roles keep their base weights — increasing body weight impairs reading for dyslexia.
- `letterSpacing` for all body roles in contrast theme: increase by +0.2 over base values. This adds horizontal rhythm that benefits visual tracking.
- `lineHeight` for all body roles: increase to **1.60** (from 1.50). Taller lines reduce crowding for users with low vision.
- These contrast-specific overrides are NOT applied via `TextScaler` — they must be set explicitly inside `contrastTheme`'s `TextTheme.copyWith()` block in `app_theme.dart`.

---

## 4. Spacing, Radius & Elevation

### 4.1 Spacing Tokens — Confirmed with New Defaults

The existing token set (4/8/16/24/32/48) is confirmed and kept. The "more air" goal is achieved by changing how these tokens are applied — specifically, by promoting the default screen margin from `md` (16) to `lg` (24) and the default card inner padding from `sm+md` ad-hoc values to `md` (16) consistently.

| Token | Value | Primary usage |
|---|---|---|
| `xs` | 4dp | Icon-to-label gap, badge insets, micro-padding |
| `sm` | 8dp | Internal widget gap (e.g. icon + text in a row), dense list item padding |
| `md` | 16dp | Card inner padding, sheet inner padding, form field padding |
| `lg` | 24dp | **Screen edge margin** (new default — was 16dp), section gap, dialog padding |
| `xl` | 32dp | Between major screen sections (e.g. ring → streak → task list), large modal top padding |
| `xxl` | 48dp | Onboarding screen breathing room, illustration clearance, bottom of scrollable lists |

#### Revised screen/card padding defaults

| Context | Old padding | New padding | Token |
|---|---|---|---|
| Screen horizontal margin | 16dp | **24dp** | `lg` |
| Screen top (below AppBar) | 8dp | **16dp** | `md` |
| Screen bottom (above FAB) | 96dp | **96dp** | keep — FAB clearance unchanged |
| Card inner padding | varies (12–16) | **16dp** all sides | `md` |
| Bottom sheet inner padding | 16dp | **24dp** H, **20dp** V | `lg` / custom |
| Dialog inner padding | 16dp | **24dp** | `lg` |
| List item padding | 12dp V, 0 H | **14dp V, 0 H** | custom (between sm and md) |

The `today_screen.dart` `ListView` padding `EdgeInsets.fromLTRB(16, 8, 16, 96)` should update to `EdgeInsets.fromLTRB(24, 16, 24, 96)`. The tablet path `padding: EdgeInsets.all(24)` is already correct.

### 4.2 Radius Tokens — Revised

The existing tokens are kept; we add explicit per-component assignments to remove inconsistency.

| Token | Value | Assigned to |
|---|---|---|
| `sm` | 8dp | Input fields, text areas, small inline chips |
| `md` | 16dp | Cards, content tiles, image containers |
| `lg` | 24dp | Bottom sheets, dialogs, modals, expanded cards |
| `pill` | 999dp | Navigation chips, filter chips, FAB label |

#### Per-component radius table

| Component | Radius | Token | Notes |
|---|---|---|---|
| **Card** (content card, task tile) | 16dp | `md` | All cards uniform — no mixing sm/md |
| **Button** (FilledButton, OutlinedButton) | 12dp | between sm/md | More confident than pill, less boxy than 8 — Flutter's default 20dp is too bubbly for this aesthetic |
| **FAB** | `pill` (FloatingActionButton default) | `pill` | Keep Flutter default |
| **Bottom sheet** | 24dp top corners only | `lg` | Standard Material 3 pattern |
| **Dialog** | 24dp | `lg` | |
| **Input field** | 8dp | `sm` | |
| **Chip (filter/selection)** | `pill` | `pill` | Keep current — correct |
| **Chip (status/tag inline)** | 8dp | `sm` | Small inline tags should feel less bubbly |
| **Avatar** | `pill` | `pill` | Circular |
| **Progress bar** | `pill` | `pill` | |
| **Bottom nav bar** | 0dp | — | Full-width, no rounding |
| **SnackBar / Toast** | 12dp | between sm/md | |

Note on buttons: The current `FilledButton` default in Material 3 uses `StadiumBorder` (pill). Override to `RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))` in `ThemeData.filledButtonTheme` and `outlinedButtonTheme`. This gives a confident, intentional button shape that matches the Things 3 / Linear reference feel.

### 4.3 Elevation — Surface Steps + Hairline Borders

No shadow-based elevation. All depth is expressed through:

1. **Surface color steps** — backgrounds and surfaces are defined in design-tokens.json as `bg` and `surface`. These are the only two steps. There is no `surface2`, `surface3` in the current palette.
2. **Hairline borders** — `border` and `borderStrong` (defined below).
3. **Opacity** — when a third level is needed (e.g. a popover over a sheet), use surface color at 95–98% opacity with `BackdropFilter` blur of 8–12dp (not shadows).

#### Border roles

| Role | Usage | Dark themes value | White theme value |
|---|---|---|---|
| **border** (weak) | Card outlines, dividers, input idle state | theme `border` color (e.g. Focus: `#3A3020`, opacity 100%) | `#E3E0DA` |
| **borderStrong** | Input focused, selected state, active card | theme `accent` color at 60% opacity | `#2B2A26` at 40% opacity |
| **borderCritical** | Destructive action, error state | theme `ember` color | `#E5533A` |

#### When to use what

| Situation | Rule |
|---|---|
| Content card at rest on `bg` | Use `surface` fill + `border` outline (1dp hairline) |
| Content card selected / active | Use `surface` fill + `borderStrong` outline (1.5dp) |
| Card within a card (nested) | Use `bg` fill (recessed) + `border` outline — no fill-on-fill using the same color |
| Bottom sheet / dialog over screen | Use `surface` fill + no border (the contrast with `bg` is sufficient) + 24dp top radius |
| Input at rest | `surface` fill + `border` outline (1dp) |
| Input focused | `surface` fill + `borderStrong` outline (1.5dp, `accent` color) |
| Elevated popover / tooltip | `surface` + BackdropFilter blur 10dp + border outline. Never use `boxShadow` |
| Section separator | `Divider` using `border` color, thickness 0.5dp (hairline) |
| No shadow needed | `elevation: 0` everywhere — enforced in `CardThemeData`, `AppBarTheme`, `BottomNavigationBarThemeData` (already set in app_theme.dart, confirmed correct) |

---

## 5. Implementation Checklist (for app_theme.dart update)

The following concrete changes flow from this spec and should be applied to `/app/lib/core/theme/app_theme.dart`:

1. Replace `GoogleFonts.mulishTextTheme` with `GoogleFonts.dmSansTextTheme` for calm theme.
2. Replace `GoogleFonts.interTextTheme` with `GoogleFonts.plusJakartaSansTextTheme` for white theme (and remove the Geist TODO comment).
3. Add explicit `TextTheme.copyWith()` overrides in `_buildTheme` to apply the type scale values from section 1 (fontSize, fontWeight, height, letterSpacing) — currently the theme inherits Material defaults which are close but not exact.
4. Override button shape in `ThemeData`: add `filledButtonTheme` and `outlinedButtonTheme` with `borderRadius: BorderRadius.circular(12)`.
5. Update `inputDecorationTheme` border radius from 8 to match `radius.sm` = 8 (already correct).
6. Add `textButtonTheme` for consistent `TextButton` shape.
7. For contrast theme `_buildTheme` call: add explicit `copyWith` to bump display/headline weights to w800, increase letterSpacing +0.2 on body, set lineHeight 1.60 on body.

---

## Summary

The key typography moves are: replacing the inherited Material 3 default sizes with a deliberately stepped scale that makes a confident 34→28→22 headline cascade, so screen structure reads at a glance without the user needing to hunt for hierarchy; and pairing that with a screen margin promotion from 16dp to 24dp throughout — the same air that makes Linear, Nothing OS, and Things 3 feel premium is just one spacing-token step, applied consistently.

---

*File: `/docs/design/02-type-space.md` — created 2026-06-19*
