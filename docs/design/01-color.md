# Kaizen — Color System v1

> Single source of truth for all color decisions across the 5 themes.
> Tokens here feed `docs/design-tokens.json` (and from there `app/lib/core/theme/app_theme.dart`).
> Philosophy: **one accent among disciplined neutrals** — Linear + Nothing OS + Arc feel.
> Bold means refined, layered, premium neutrals with ruthless accent discipline, not more hues.

---

## Token Roles (all themes)

| Token | Role |
|---|---|
| `bg` | Page/scaffold background |
| `surface` | Cards, sheets, input fills — first elevation step |
| `surfaceElevated` | **NEW** Modals, dropdowns, popovers — second elevation step |
| `text` | Body copy, primary labels |
| `textMuted` | Secondary labels, captions, metadata |
| `textFaint` | **NEW** Tertiary: placeholders, disabled states, timestamps |
| `accent` | Primary interactive color — CTAs, active nav, progress arcs |
| `accentMuted` | **NEW** Low-emphasis accent: selection highlights, chip fill, hover bg |
| `ember` | Urgent, overdue, destructive indicators |
| `success` | Completion, streaks, positive states |
| `border` | Hairline dividers, card outlines |
| `borderStrong` | Focused inputs, active card outlines, separators that must read |

---

## WCAG Thresholds Applied

- **Body text** (`text`, `textMuted`) on `bg` and `surface`: must be >= **4.5 : 1**
- **Tertiary / large UI** (`textFaint`, semantic icons, `ember`, `success` as icon): must be >= **3.0 : 1**
- **Accent as text/icon** on `bg`: checked and noted
- **text-on-accent** (accent used as button fill): must be >= **4.5 : 1**

---

## Theme 1 — Focus (warm dark, default)

Identity: warm near-black ground, single electric-lime accent. Nothing else competes.

### Palette

| Token | Hex | Notes |
|---|---|---|
| `bg` | `#141009` | Deep warm brown-black |
| `surface` | `#241D11` | Lifted warm surface |
| `surfaceElevated` | `#2E2618` | Second lift for modals/sheets |
| `text` | `#F6EFE1` | Warm off-white — never pure white |
| `textMuted` | `#9E9070` | Warm mid-gray, secondary labels |
| `textFaint` | `#736850` | Tertiary, placeholders, timestamps |
| `accent` | `#D9F24B` | Electric lime — the one accent |
| `accentMuted` | `#26290F` | Very dark lime wash — selection bg, chip fill |
| `ember` | `#FF6A3D` | Warm orange-red, urgent only |
| `success` | `#4BAF6F` | Mid green, completion/streaks |
| `border` | `#3A3020` | Hairline — barely perceptible |
| `borderStrong` | `#524630` | Active input outlines, focused cards |

### Contrast Table

| Pair | Ratio | Threshold | Pass |
|---|---|---|---|
| `text` on `bg` | 16.57 : 1 | 4.5 | PASS |
| `text` on `surface` | 14.58 : 1 | 4.5 | PASS |
| `textMuted` on `surface` | 5.30 : 1 | 4.5 | PASS |
| `textFaint` on `surface` | 3.04 : 1 | 3.0 | PASS |
| `accent` on `bg` (icon/text use) | 15.12 : 1 | 3.0 | PASS |
| `bg` on `accent` (button label) | 15.12 : 1 | 4.5 | PASS |

No current token failures. All new tokens pass their respective thresholds.

---

## Theme 2 — Calm (low-saturation blue-green dark)

Identity: deep cool-dark water. Accent is a desaturated teal — soft authority, never shouty.

### Palette

| Token | Hex | Notes |
|---|---|---|
| `bg` | `#11171A` | Dark blue-black |
| `surface` | `#18232A` | Cooler dark surface |
| `surfaceElevated` | `#1F2E38` | Second lift, modal depth |
| `text` | `#E8F0F0` | Cool near-white |
| `textMuted` | `#8AA0A0` | Desaturated teal-gray |
| `textFaint` | `#617E7E` | Tertiary, muted teal |
| `accent` | `#6FB6A3` | Desaturated teal |
| `accentMuted` | `#172628` | Very dark teal wash — selection bg |
| `ember` | `#E08A6B` | Warm salmon-orange, urgent |
| `success` | `#5AB594` | Brighter teal-green |
| `border` | `#243640` | Hairline, dark blue-slate |
| `borderStrong` | `#365060` | Active outlines |

### Contrast Table

| Pair | Ratio | Threshold | Pass |
|---|---|---|---|
| `text` on `bg` | 15.63 : 1 | 4.5 | PASS |
| `text` on `surface` | 13.83 : 1 | 4.5 | PASS |
| `textMuted` on `surface` | 5.80 : 1 | 4.5 | PASS |
| `textFaint` on `surface` | 3.65 : 1 | 3.0 | PASS |
| `accent` on `bg` (icon/text use) | 7.66 : 1 | 3.0 | PASS |
| `bg` on `accent` (button label) | 7.66 : 1 | 4.5 | PASS |

Note: `text` (#E8F0F0) on `accent` (#6FB6A3) is 2.04 : 1 — **use `bg` (#11171A) as button label on accent, never `text`**. This was implicit in the original `onAccent` assignment and is confirmed correct.

---

## Theme 3 — Black (OLED true-black)

Identity: maximum contrast on true black. The accent shifts slightly from lime toward chartreuse to maintain character from Focus without being identical.

### Palette

| Token | Hex | Notes |
|---|---|---|
| `bg` | `#000000` | OLED true black |
| `surface` | `#0E0E0E` | Barely-there lift |
| `surfaceElevated` | `#161616` | Second lift for modals |
| `text` | `#FFFFFF` | Pure white |
| `textMuted` | `#8A8A8A` | Mid neutral gray |
| `textFaint` | `#636363` | Tertiary, just clears 3:1 on surface |
| `accent` | `#C8FF4D` | Chartreuse-lime, slightly shifted from Focus |
| `accentMuted` | `#1A1F0A` | Near-black lime wash — selection bg |
| `ember` | `#FF6A3D` | Same warm orange-red as Focus |
| `success` | `#4BAF6F` | Mid green |
| `border` | `#1C1C1C` | Near-invisible hairline |
| `borderStrong` | `#2E2E2E` | Visible outline for focused states |

### Contrast Table

| Pair | Ratio | Threshold | Pass |
|---|---|---|---|
| `text` on `bg` | 21.00 : 1 | 4.5 | PASS |
| `text` on `surface` | 19.30 : 1 | 4.5 | PASS |
| `textMuted` on `surface` | 5.59 : 1 | 4.5 | PASS |
| `textFaint` on `surface` | 3.21 : 1 | 3.0 | PASS |
| `accent` on `bg` (icon/text use) | 17.87 : 1 | 3.0 | PASS |
| `bg` on `accent` (button label) | 17.87 : 1 | 4.5 | PASS |

Note: white (#FFFFFF) on accent (#C8FF4D) is only 1.18 : 1 — confirmed that `bg` (#000000) is the correct button label color on accent, not `text`. Preserved from original `onAccent` = black.

---

## Theme 4 — White (clean light)

Identity: warm off-white ground, near-black accent. Restrained and editorial — the accent is ink, not color.

### Palette

| Token | Hex | Notes |
|---|---|---|
| `bg` | `#FFFFFF` | Pure white |
| `surface` | `#F5F4F1` | Warm off-white card |
| `surfaceElevated` | `#ECEAE5` | Deeper warm step for modals |
| `text` | `#16130E` | Near-black warm ink |
| `textMuted` | `#6B675F` | Warm mid-gray |
| `textFaint` | `#858178` | Tertiary, warm light gray |
| `accent` | `#2B2A26` | Near-black ink — the one accent in this theme |
| `accentMuted` | `#EDECEA` | Very light warm wash — selection bg, chip fill |
| `ember` | `#E5533A` | Warm red-orange, urgent |
| `success` | `#1A7A3E` | Deep forest green |
| `border` | `#E3E0DA` | Warm light hairline |
| `borderStrong` | `#C8C4BC` | Visible warm outline |

> `accentAlt` (`#5B7CFA` in design-tokens.json) is ONLY used as a semantic badge/chip fill, never as body text. See failure note below.

### Contrast Table

| Pair | Ratio | Threshold | Pass |
|---|---|---|---|
| `text` on `bg` | 18.52 : 1 | 4.5 | PASS |
| `text` on `surface` | 16.84 : 1 | 4.5 | PASS |
| `textMuted` on `surface` | 5.12 : 1 | 4.5 | PASS |
| `textFaint` on `surface` | 3.53 : 1 | 3.0 | PASS |
| `accent` on `bg` (icon/text use) | 14.36 : 1 | 3.0 | PASS |
| `bg` on `accent` (button label) | 14.36 : 1 | 4.5 | PASS |

### Contrast Failure Fixed

| Role | Was | Old Ratio | Now | New Ratio | Note |
|---|---|---|---|---|---|
| `accentAlt` as text | `#5B7CFA` | 3.68 : 1 | `#3558E8` | 5.66 : 1 | Was failing 4.5 body text threshold. Use `#3558E8` wherever `accentAlt` appears as a text/icon color. Retain `#5B7CFA` only as a large badge background where the text on top of it is `bg`/`text`. |

---

## Theme 5 — Contrast (accessibility, large type)

Identity: maximum legibility. Pure black ground, yellow accent for maximum separation from white text, no compromises. `_placeholder` status in design-tokens.json is hereby resolved.

### Palette

| Token | Hex | Notes |
|---|---|---|
| `bg` | `#000000` | OLED true black |
| `surface` | `#0A0A0A` | Micro-lift |
| `surfaceElevated` | `#141414` | Second lift for modals |
| `text` | `#FFFFFF` | Pure white |
| `textMuted` | `#D0D0D0` | Light gray, still strong |
| `textFaint` | `#A0A0A0` | Tertiary — still far above 3:1 (7.57 on surface) |
| `accent` | `#FFE600` | Yellow — highest contrast non-white on black |
| `accentMuted` | `#2A2600` | Very dark yellow wash — selection bg |
| `ember` | `#FF5230` | High-vis red-orange, urgent |
| `success` | `#00E5A0` | Bright cyan-green, maximum pop |
| `border` | `#FFFFFF` | Full-white hairline — intentional for max visibility |
| `borderStrong` | `#FFFFFF` | Same as border; all borders are full-white in this theme |

### Contrast Table

| Pair | Ratio | Threshold | Pass |
|---|---|---|---|
| `text` on `bg` | 21.00 : 1 | 4.5 | PASS |
| `text` on `surface` | 19.80 : 1 | 4.5 | PASS |
| `textMuted` on `surface` | 12.84 : 1 | 4.5 | PASS |
| `textFaint` on `surface` | 7.57 : 1 | 3.0 | PASS |
| `accent` on `bg` (icon/text use) | 16.57 : 1 | 3.0 | PASS |
| `bg` on `accent` (button label) | 16.57 : 1 | 4.5 | PASS |

No failures. `_placeholder: true` status in design-tokens.json is resolved by this table.

---

## Cross-Theme Failure Audit

### Failures Found and Fixed

| Theme | Token | Was | Old Ratio | Fix | New Ratio | Location |
|---|---|---|---|---|---|---|
| White | `accentAlt` (as text) | `#5B7CFA` | 3.68 : 1 on bg | `#3558E8` | 5.66 : 1 on bg | `design-tokens.json` `accent_alt` — must update and restrict usage |

### Failures Found, Constraint Added (not a new hex)

| Theme | Context | Ratio | Ruling |
|---|---|---|---|
| Black | `text` (#FFFFFF) on `accent` (#C8FF4D) as button label | 1.18 : 1 | CONFIRMED FAIL — do not use white as label on accent button. Use `bg` (#000000). Already correct in `app_theme.dart` (`onAccent: Color(0xFF000000)`). |
| Calm | `text` (#E8F0F0) on `accent` (#6FB6A3) as button label | 2.04 : 1 | CONFIRMED FAIL — do not use `text` as label on accent button. Use `bg` (#11171A). Already correct in `app_theme.dart` (`onAccent: Color(0xFF11171A)`). |

### Tokens Carried Forward Unchanged (no failures)

Focus, Calm, Black, White `text` / `textMuted` / `ember` / `border` — all pass their thresholds on both `bg` and `surface`. Contrast theme all tokens clean.

---

## New Tokens — Implementation Notes

### `surfaceElevated`
Second elevation step. Use for: bottom sheets, dialogs, context menus, popover cards. Never use for the base card layer (that is `surface`). In `app_theme.dart`, add to `_Palette` and expose via `FocusThemeExtension` (or rename extension to `KaiThemeExtension`).

### `textFaint`
Tertiary text. Use for: input placeholders, disabled labels, relative timestamps, empty-state subtext. Never use for anything that carries meaning the user must read to complete an action.

### `accentMuted`
Low-emphasis accent fill. Use for: selected chip background, text selection highlight, row hover state (web), active filter pill background. Text placed on `accentMuted` must use `accent` or `text` (verify per theme — `accent` on `accentMuted` will have sufficient contrast since both are derived from the same hue family at extreme luminance distance).

### `borderStrong`
Replaces hairline `border` for: focused input rings, active card outlines, any border that must be perceived at a glance. Use `border` for structural separation that should recede.

### `success`
Completion, streak count, positive health indicators. Not a new semantic concept — just makes explicit what was previously implicit in `done` under `semantic`.

---

## Summary

The palette refines each theme's identity by adding three new role tokens (`surfaceElevated`, `textFaint`, `accentMuted`) that complete the layering system without introducing new hues, and by formalising `success` and `borderStrong` as distinct from their overloaded predecessors. One confirmed body-text failure was found and fixed: White theme's `accentAlt` (`#5B7CFA`, ratio 3.68 : 1) must be updated to `#3558E8` (ratio 5.66 : 1) wherever it is used as rendered text or an icon; the two `onAccent` color-on-accent violations in Black and Calm themes were pre-existing constraints already handled correctly in `app_theme.dart` and are documented here as confirmed non-bugs.

---

*File: `/docs/design/01-color.md`*
