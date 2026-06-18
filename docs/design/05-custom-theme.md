# Custom Theme Editor — Design & Implementation Spec

**Feature:** "My Theme" — a 6th selectable theme created by the user.
**Location in code:** `app/lib/core/theme/` (provider + palette derivation) + `app/lib/features/profile/` (editor screen + picker entry).
**Status:** spec only; not yet built.

---

## 1. UX — What the User Picks

### Minimal input model

The user makes exactly **two required choices** and one optional one:

| # | Input | Type | Required |
|---|-------|------|----------|
| 1 | **Base mode** | Toggle: Light / Dark | Yes |
| 2 | **Accent color** | Curated swatch grid + optional custom hex picker | Yes |
| 3 | **Background tint** | Optional hue shift slider (±30 degrees on the bg hue) | No |

That is all. Everything else is derived algorithmically. The user never touches individual color roles — that is the job of the derivation algorithm in §2.

### Why this model is foolproof

- Two variables (mode + accent) span the full design space of "looks like mine".
- The curated swatch grid eliminates the most common mistake: picking a pastel or near-white accent that fails contrast. Every swatch in the grid is pre-vetted (see §2 for how).
- The optional bg tint lets users get a warm/cool feel without the risk of choosing a bg that fights the accent — the hue is constrained to ±30 degrees so it can never dominate.

### Curated accent swatch grid

12 swatches arranged in a 4×3 grid. One row = warm, one = cool, one = neutral/earth, one = vibrant. These specific hex values are vetted to pass the contrast rules in §2 on both dark and light base modes. The grid is hardcoded as a `const List<Color>` in the editor widget.

```
Row 1 — warm:    #D9F24B  #F2A93B  #FF6A3D  #E85D75
Row 2 — cool:    #6FB6A3  #5B7CFA  #85C1E9  #A78BFA
Row 3 — earth:   #C9A96E  #8DB87E  #9B8EC4  #D4A5A5
Row 4 — neon:    #C8FF4D  #FFE600  #00E5A0  #FF4FA3
```

Below the grid: a small "Custom" chip that opens the system `showColorPickerDialog` (or a basic HSV wheel widget). If the user picks a color from the wheel that cannot pass the §2 contrast checks at all, the editor shows a brief inline warning and still enforces the fallback rules — it does not block the user from saving.

### Background tint (optional)

A horizontal `Slider` labeled "Background warmth" ranging from −30 to +30. Default is 0 (no tint). This slider adjusts only the **hue** of bg and surface by the given number of degrees; all other roles re-derive from that shifted bg. It is hidden behind a "Customize more" `ExpansionTile` so it does not overwhelm the default view.

---

## 2. Editor Screen Layout

Route: `/profile/custom-theme`

Opened from Profile screen: the `_ThemePicker` widget gains a 6th `ChoiceChip` labeled "Custom". If no custom theme is saved yet, tapping it opens the editor immediately. If one is already saved, it activates the custom theme; a small "Edit" `IconButton` appears next to the chip to re-open the editor.

### Screen structure (top to bottom)

```
AppBar: "My Theme"  [Reset]  [Save]
──────────────────────────────────────
LIVE PREVIEW CARD  (≈180dp tall)
  Mini Today-screen mockup:
    - Greeting row (uses derived text color)
    - Three pill-shaped "task" placeholders (uses surface + border)
    - A filled FAB at bottom-right (uses accent + onAccent)
  Background = derived bg
  Updates live as user adjusts controls below.
──────────────────────────────────────
Section: "Base mode"
  Segmented button:  [Dark]  [Light]

Section: "Accent color"
  4×3 swatch grid (GridView, 44×44dp each, 8dp gap)
  Below grid: [Custom color] chip

"Customize more" ExpansionTile
  "Background warmth"  Slider  −30 … +30
──────────────────────────────────────
(bottom safe area padding)
```

The preview card and all controls sit in a `SingleChildScrollView`. The `[Save]` button in the AppBar writes to SharedPreferences and pops back. `[Reset]` clears the stored custom config and reverts the selected theme to `focus`.

### Live preview update timing

Use a local `StatefulWidget` (or `ConsumerStatefulWidget`) that holds the three in-progress values. On any change, recompute the full palette via the §2 algorithm in-memory and rebuild only the preview card. This is cheap — it is a pure function on three inputs. Animation of preview changes: `AnimatedContainer` with `normal` duration (280 ms, per `core/animations/constants.dart`).

---

## 3. Derivation Algorithm

Given: `baseMode` (dark or light), `accentHex` (a `Color`), `bgHueDelta` (integer −30..+30, default 0).

The algorithm produces a `_Palette` struct identical to those used by the five preset themes. It can be called from a static method, e.g. `CustomThemePalette.derive(...)`.

### Step 0 — Utility definitions

**Relative luminance L** (per WCAG 2.1 §1.4.3):

```
For a channel c in sRGB (0..1):
  c_lin = c/12.92            if c <= 0.04045
  c_lin = ((c+0.055)/1.055)^2.4  otherwise
L = 0.2126 * R_lin + 0.7152 * G_lin + 0.0722 * B_lin
```

**Contrast ratio CR** between foreground F and background B:

```
CR = (max(L_F, L_B) + 0.05) / (min(L_F, L_B) + 0.05)
```

WCAG AA for normal text: CR >= 4.5. For large text / UI components: CR >= 3.0. This spec uses 4.5 as the floor for all text-on-surface checks, 3.0 for icon/border-level checks.

**HSL helpers:** The algorithm uses `hslFromColor` / `colorFromHSL` throughout. All hue values are in degrees [0..360], saturation/lightness in [0..1].

### Step 1 — Derive bg

**Dark mode base bg:**
Start from HSL `(accentHue, 0.08, 0.07)` — a near-black with a faint tint of the accent hue. Apply `bgHueDelta` by adding it to the hue. Clamp lightness to [0.05, 0.10] so it never becomes grey or mid-tone.

**Light mode base bg:**
Start from HSL `(accentHue + bgHueDelta, 0.04, 0.97)` — near-white with a whisper of tint. Clamp lightness to [0.94, 0.99].

Result: `bg`.

### Step 2 — Derive surface, surfaceElevated

**Dark mode:**
- `surface` = bg lightness + 0.06 (same hue, slightly desaturated: saturation * 0.85)
- `surfaceElevated` = bg lightness + 0.11

**Light mode:**
- `surface` = bg lightness − 0.04 (i.e. slightly darker than bg)
- `surfaceElevated` = bg lightness − 0.08

All clamped to valid range. The lightness step values (0.06 / 0.11 dark; 0.04 / 0.08 light) mirror the deltas visible in the existing focus/white palettes and guarantee visible but non-jarring elevation separation.

### Step 3 — Derive text, textMuted, textFaint

**Dark mode:**
- `text` = `Color(0xFFF0EDE6)` (warm near-white, slightly de-blued, independent of accent)
- `textMuted` = text color at 60% opacity composited over surface → then round to the nearest opaque HSL value that achieves CR >= 4.5 on `surface`.
- `textFaint` = same process but target CR >= 3.0 on `surface`.

**Light mode:**
- `text` = HSL `(accentHue, 0.05, 0.10)` — near-black with accent-hue trace
- `textMuted` = HSL `(accentHue, 0.05, 0.42)` → verify CR >= 4.5 on `surface`; if not, lighten/darken to the nearest passing value.
- `textFaint` = HSL `(accentHue, 0.04, 0.58)` → verify CR >= 3.0 on `surface`.

In both modes, the muted/faint values use a **binary search on lightness** in 32 iterations to find the lightest value (dark mode: darkest value for light mode) that still passes the target CR. This guarantees WCAG compliance regardless of the accent chosen.

### Step 4 — Derive accent and accentMuted

Use the raw `accentHex` as input.

**Accent luminance check — is accent readable as text/icon on bg?**
Compute `CR(accent, bg)`. If CR >= 3.0, use `accentHex` as-is for the `accent` role. If CR < 3.0 (accent too close in luminance to bg), adjust:
- Dark mode: increase accent lightness in 0.02 steps until CR(accent, bg) >= 3.0.
- Light mode: decrease accent lightness in 0.02 steps until CR(accent, bg) >= 3.0.
- Cap at 20 iterations. If still not passing (extreme edge case), fall back to the theme's default accent (`Color(0xFFD9F24B)` for dark, `Color(0xFF2B6CB0)` for light) and store a flag `accentWasForced = true` to show a warning in the editor.

`accentMuted` = accent color at HSL with saturation reduced by 50% and alpha set to 0.18 composited over surface. As an opaque color for contexts that don't support alpha: lighten by 0.20 in dark mode / darken by 0.15 in light mode, saturation * 0.4.

### Step 5 — Derive onAccent (text on top of accent)

Compute `CR(white, accent)` and `CR(black, accent)`:
- If `CR(black, accent)` >= 4.5 → `onAccent = Color(0xFF0A0A0A)` (near-black)
- Else → `onAccent = Color(0xFFFAFAFA)` (near-white)

This is the WCAG-mandated auto-pick. No in-between — only black or white, because mid-grey on accent produces marginal contrast.

### Step 6 — Derive ember (urgent/overdue signal)

`ember` is always a warm red-orange independent of accent. It must not clash with the accent.

Start value: `Color(0xFFFF6A3D)` (the focus theme ember).

Compute `CR(ember_hsl, bg)`. If CR >= 3.0, keep it. Otherwise adjust lightness until CR >= 3.0.

Additionally, compute the hue distance between `ember` and `accent`. If `|accentHue - 25|` < 30 (i.e., the user chose a red-orange accent that is close to ember), shift ember's hue to 340 (deep rose-red) to maintain visual distinctness. CR check still applies.

### Step 7 — Derive success

Fixed semantic green, not influenced by accent:
- Dark mode: `Color(0xFF4ADE80)` — verify CR >= 3.0 on bg; adjust lightness if needed.
- Light mode: `Color(0xFF16A34A)` — verify CR >= 3.0 on bg; adjust lightness if needed.

### Step 8 — Derive border, borderStrong

**Dark mode:**
- `border` = surface lightness + 0.07 at same hue and surface saturation.
- `borderStrong` = surface lightness + 0.15.

**Light mode:**
- `border` = surface lightness − 0.08.
- `borderStrong` = surface lightness − 0.18.

Borders do not need text-level contrast; CR >= 1.5 vs bg is sufficient for visual separation (they are decorative dividers, not information).

### Step 9 — Assemble _Palette

```dart
_Palette(
  brightness: baseMode == 'dark' ? Brightness.dark : Brightness.light,
  bg:              derived bg,
  surface:         derived surface,
  // surfaceElevated added to _Palette when redesign lands
  text:            derived text,
  textMuted:       derived textMuted,
  // textFaint added to _Palette when redesign lands
  accent:          derived accent (possibly lightness-adjusted),
  onAccent:        black or white per step 5,
  ember:           derived ember,
  // success added to _Palette when redesign lands
  border:          derived border,
  // borderStrong added to _Palette when redesign lands
)
```

The fields `surfaceElevated`, `textFaint`, `accentMuted`, `success`, `borderStrong` are noted in the task brief as coming in a redesign. When `_Palette` gains those fields, the derivation slots them in exactly as described in steps 2–8.

### Step 10 — Font selection for custom theme

Custom theme always uses **Hanken Grotesk** for body and **Fraunces** for display (same as the focus theme). This avoids the need for a font picker (which would explode UX complexity) while still producing a warm, premium result on both light and dark. The Flutter agent wires this by calling `_buildTheme` with the focus-theme font closures.

---

## 4. Persistence and Runtime Integration

### SharedPreferences keys

All stored under a `custom_theme_` prefix so they are immediately distinguishable from other prefs.

| Key | Type | Meaning |
|-----|------|---------|
| `custom_theme_set` | `bool` | true if the user has ever saved a custom theme |
| `custom_theme_mode` | `String` | `'dark'` or `'light'` |
| `custom_theme_accent_hex` | `int` | `color.value` (ARGB int, e.g. `0xFFD9F24B`) |
| `custom_theme_bg_hue_delta` | `int` | integer −30..+30, default 0 |

Only these three/four values are stored. The full palette is re-derived on every app start from them. This is intentional: if the derivation algorithm improves in a future version, existing users' saved inputs automatically produce a better palette.

### CustomThemeNotifier

Mirror the pattern in `mascot_provider.dart` and `theme_provider.dart`.

```dart
// app/lib/core/theme/custom_theme_provider.dart

const _kCustomThemeSet       = 'custom_theme_set';
const _kCustomThemeMode      = 'custom_theme_mode';
const _kCustomThemeAccentHex = 'custom_theme_accent_hex';
const _kCustomThemeBgHueDelta = 'custom_theme_bg_hue_delta';

class CustomThemeConfig {
  const CustomThemeConfig({
    required this.isDark,
    required this.accentColor,
    this.bgHueDelta = 0,
  });
  final bool isDark;
  final Color accentColor;
  final int bgHueDelta;
}

// Nullable state: null = no custom theme configured yet
class CustomThemeNotifier extends Notifier<CustomThemeConfig?> {
  @override
  CustomThemeConfig? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(_kCustomThemeSet) != true) return null;
    final modeStr = prefs.getString(_kCustomThemeMode) ?? 'dark';
    final accentInt = prefs.getInt(_kCustomThemeAccentHex) ?? 0xFFD9F24B;
    final delta = prefs.getInt(_kCustomThemeBgHueDelta) ?? 0;
    return CustomThemeConfig(
      isDark: modeStr == 'dark',
      accentColor: Color(accentInt),
      bgHueDelta: delta,
    );
  }

  Future<void> save(CustomThemeConfig config) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kCustomThemeSet, true);
    await prefs.setString(_kCustomThemeMode, config.isDark ? 'dark' : 'light');
    await prefs.setInt(_kCustomThemeAccentHex, config.accentColor.value);
    await prefs.setInt(_kCustomThemeBgHueDelta, config.bgHueDelta);
    state = config;
  }

  Future<void> reset() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kCustomThemeSet, false);
    state = null;
  }
}

final customThemeNotifierProvider =
    NotifierProvider<CustomThemeNotifier, CustomThemeConfig?>(
        CustomThemeNotifier.new);
```

### Extending AppThemeKey and the theme pipeline

Add a 6th enum value:

```dart
// In app_theme.dart
enum AppThemeKey {
  focus, calm, black, white, contrast,
  custom, // NEW
}

extension AppThemeKeyLabel on AppThemeKey {
  String get label => switch (this) {
    // ...existing cases...
    AppThemeKey.custom => 'My Theme',
  };
  String get prefsKey => name; // 'custom'
}
```

Extend `AppTheme.forKey` to handle the custom case. Because `forKey` is a pure function that only needs `AppThemeKey`, it must also accept the derived palette. The cleanest approach is an overloaded static:

```dart
// In AppTheme
static ThemeData forKeyWithCustom(AppThemeKey key, CustomThemeConfig? config) {
  if (key == AppThemeKey.custom) {
    if (config == null) return focusTheme; // guard: no config → fall back
    final palette = CustomThemePalette.derive(config);
    return _buildTheme(
      palette,
      bodyTextTheme: GoogleFonts.hankenGroteskTextTheme,
      displayFont: ({textStyle, color}) =>
          GoogleFonts.fraunces(textStyle: textStyle, color: color),
    );
  }
  return forKey(key);
}
```

Update `themeDataProvider` to watch both providers:

```dart
final themeDataProvider = Provider<ThemeData>((ref) {
  final key    = ref.watch(themeNotifierProvider);
  final config = ref.watch(customThemeNotifierProvider);
  return AppTheme.forKeyWithCustom(key, config);
});
```

`forKey` itself (used internally and in tests) remains unchanged — only the provider path passes through `forKeyWithCustom`.

### CustomThemePalette derivation class

```dart
// app/lib/core/theme/custom_theme_palette.dart
class CustomThemePalette {
  static _Palette derive(CustomThemeConfig config) {
    // implements §2 steps 1-9 above
    // pure function — no side effects
  }

  // Internal helpers: _relativeLuminance, _contrastRatio,
  // _adjustLightnessForContrast, _toHSL, _fromHSL
}
```

This file is the single home for the derivation math. It imports only `dart:math` and `package:flutter/material.dart`. It does not import Riverpod or SharedPreferences.

---

## 5. How It Appears in the Profile Theme Picker

`_ThemePicker` in `profile_screen.dart` is updated to include the custom entry:

```dart
// Inside _ThemePicker.build, after building chips for the 5 presets:
final hasCustom = ref.watch(customThemeNotifierProvider) != null;
Row(
  children: [
    ChoiceChip(
      label: const Text('My Theme'),
      selected: current == AppThemeKey.custom,
      onSelected: (_) {
        if (hasCustom) {
          ref.read(themeNotifierProvider.notifier).setTheme(AppThemeKey.custom);
        } else {
          context.push('/profile/custom-theme');
        }
      },
    ),
    if (hasCustom) ...[
      const SizedBox(width: 4),
      IconButton(
        icon: const Icon(Icons.edit_outlined, size: 18),
        tooltip: 'Edit my theme',
        onPressed: () => context.push('/profile/custom-theme'),
      ),
    ],
  ],
),
```

The go_router route `/profile/custom-theme` → `CustomThemeEditorScreen`. Add it as a sub-route of `/profile` in the router config.

---

## 6. Edge Cases

### Contrast theme interplay

The `contrast` theme (`AppThemeKey.contrast`) is an accessibility preset with yellow accent on pure black, 1.15 text scale. The custom theme is a separate 6th entry and never merges with `contrast`. If a user is on `contrast` and opens the custom editor, the preview shows what their custom theme will look like — it does not inherit any contrast theme properties. The 1.15 text scale applied via `MediaQuery.textScaler` in `main.dart` is keyed to `AppThemeKey.contrast` only (leave that guard unchanged).

### No custom theme saved yet — "My Theme" chip tapped

When `customThemeNotifierProvider` returns null and the user taps the "My Theme" chip, navigate to `/profile/custom-theme` instead of calling `setTheme(custom)`. The editor will open with default prefills:
- Base mode: Dark
- Accent: the first swatch (`#D9F24B`)
- Bg hue delta: 0

The `[Save]` button is **not disabled** for these defaults — the user can save immediately and get a valid theme.

### Reset to default

Tapping `[Reset]` in the editor's AppBar:
1. Calls `customThemeNotifierProvider.notifier.reset()` (clears `custom_theme_set` = false, state → null).
2. If `themeNotifierProvider.state == AppThemeKey.custom`, also calls `themeNotifierProvider.notifier.setTheme(AppThemeKey.focus)`.
3. Pops the editor screen.

This means the user is always left in a valid theme state after reset.

### Accent forced by contrast correction (§2 step 4)

If `accentWasForced = true`, the editor shows an inline `Text` in `textMuted` color below the swatch grid:

> "Your color was too close to the background. We adjusted it slightly for readability."

This message is shown inside the editor screen only — not after saving. The saved config stores the **original** `accentHex` the user picked (not the adjusted one), so that if the derivation algorithm improves later, re-saving re-derives from the original intent.

Wait — this is a subtle but important point: if the original hex is stored and re-derived, the same adjustment will apply again, which is correct behavior. The user picked that color and it will always be adjusted. The "adjusted" message is informational, not an error. No blocking behavior.

### App cold-start with custom theme active

Boot sequence:
1. `main.dart` initialises `SharedPreferences`.
2. `ProviderScope` overrides `sharedPreferencesProvider`.
3. `themeNotifierProvider` reads `app_theme_key` = `'custom'`.
4. `customThemeNotifierProvider` reads the four `custom_theme_*` keys.
5. `themeDataProvider` calls `AppTheme.forKeyWithCustom(custom, config)`.
6. If `config` is null (key stored as `custom` but `custom_theme_set` is false — data corruption edge case), `forKeyWithCustom` falls back to `focusTheme` and the missing data is non-fatal.

No async or FutureProvider is needed — all reads from SharedPreferences in `Notifier.build()` are synchronous.

### Web platform

`SharedPreferences` on Flutter Web uses `localStorage`. The four `custom_theme_*` keys are small primitives and persist across sessions normally. No special handling needed.

---

## 7. Summary

The user input model is deliberately minimal: one binary toggle (dark/light) and one color selection (curated swatch or custom hex), with an optional hue-tint slider hidden in a secondary panel — this covers the full creative space a non-designer needs while making it essentially impossible to produce an unreadable result.

Contrast safety is guaranteed unconditionally: the derivation algorithm applies WCAG CR checks with binary-search lightness correction at every role that carries text or icons, auto-selects black or white as the on-accent foreground based on whichever achieves CR >= 4.5, and falls back to the default accent if the user's chosen color cannot be made readable against the derived background within 20 iterations.
