# Kaizen — Component Theming Spec (03-components)

> Single source of truth for Flutter `ThemeData` component values.
> Color roles map to `_Palette` fields in `app/lib/core/theme/app_theme.dart`.
> All 5 themes (focus/calm/black/white/contrast) share this spec — only the
> palette values differ. Flutter dev sets these in `_buildTheme()`.
>
> Color role → ColorScheme mapping reference:
> | Role name       | ColorScheme field                  | FocusThemeExtension field |
> |-----------------|-----------------------------------|---------------------------|
> | accent          | `colorScheme.primary`             | —                         |
> | onAccent        | `colorScheme.onPrimary`           | —                         |
> | surface         | `colorScheme.surface`             | —                         |
> | bg              | `scaffoldBackgroundColor`         | —                         |
> | text            | `colorScheme.onSurface`           | —                         |
> | textMuted       | —                                 | `ext.textMuted`           |
> | ember           | `colorScheme.secondary`           | `ext.ember`               |
> | border          | `colorScheme.outline`             | `ext.border`              |
> | surfaceElevated | `colorScheme.surfaceContainerHighest` (= border value currently) | — |
>
> `ext` = `Theme.of(context).extension<FocusThemeExtension>()!`

---

## 0. Universal constraints

| Rule | Value |
|------|-------|
| Minimum tap target | **48 dp** (all interactive elements) |
| FAB gap above nav bar | **≥ 16 dp** clear space between FAB bottom edge and nav bar top edge |
| FAB gap from screen edge | **16 dp** right / bottom (standard Flutter FAB margin) |
| Disabled opacity | **38 %** (`withOpacity(0.38)`) on foreground; fill stays at 12 % alpha |
| Focus ring | `border` color, 2 dp width, `radius.sm` (8) or component radius, no fill |
| Pressed state | Ripple `accent.withOpacity(0.12)` on dark themes; `text.withOpacity(0.08)` on white |

---

## 1. ACCENT DISCIPLINE

> This is a product-level rule, not just a style guide. Every new screen must be reviewed against it.

### Where accent IS allowed

1. **Primary / filled action button** — the single most-important CTA on any sheet or screen.
2. **FAB** — the global creation action (+ Add).
3. **Active / selected state** — current tab indicator pill, selected segment, checked chip, toggle-on.
4. **Done / success feedback** — task completion checkmark, ring closure, progress reaching 100 %.
5. **Main-priority shield badge** — the single marker that identifies a protected task.
6. **Focused input border** — one-pixel accent ring when the user is actively typing.
7. **Kai mascot eyes** — per MASCOT.md.

### Where accent is FORBIDDEN

- Secondary action bars, repeated section headers, decorative icon fills.
- Macro nutrient bars (B/Zh/U) in Food — use muted tonal fills; only the primary kcal metric
  gets accent. ("Wall of lime" anti-pattern, see UX-LAYOUT.md §6.)
- Background fills on cards, sheets, or the nav bar body.
- Progress bars that are informational only (use `textMuted` at 30 % opacity).
- Streak dots that are empty/unfilled — use `border` color.
- Any quantity > 1 accent element visible simultaneously unless each instance is functionally
  distinct (e.g., two filled buttons at once is a hierarchy error).

### Ember (urgent color)

Ember (`colorScheme.secondary`) is reserved **exclusively** for:
- Overdue / past-deadline task markers.
- Exam countdown cards.
- Harsh-tone icon.
- Error states and destructive action confirmations.

Never mix ember and accent in the same UI element. Never use ember as a highlight on success.

---

## 2. BUTTON HIERARCHY

| Level | Widget | Fill | When to use |
|-------|--------|------|-------------|
| **Primary** | `FilledButton` | accent fill, onAccent text | The single most-important action on a sheet or screen — save, confirm, start session; maximum one per view. |
| **Secondary / Tonal** | `FilledButton.tonal` | surface fill with accent-tinted label | A second important action that exists alongside a primary — e.g., "Accept all" (primary) + "Edit" (tonal); weight sits between filled and outlined. |
| **Outlined** | `OutlinedButton` | transparent, border stroke | Repeatable, low-risk actions that appear in sets — "+250 ml", "+500 ml" log buttons; destructive with outlined-danger variant (ember border). |
| **Text / Ghost** | `TextButton` | no fill, no border | Navigation nudges and inline links — "View report →", "View all", "Forgot password?"; never the sole action on a screen. |

**Visual weight rule:** Filled > Tonal > Outlined > Text. Only one Filled button should draw
the eye at any time. If a second action needs equal prominence, use Tonal, not a second Filled.

---

## 3. Filled Button — `FilledButtonThemeData`

Primary action. Accent fill, onAccent foreground.

| Property | Value |
|----------|-------|
| Min height | 48 dp |
| Min width | 64 dp |
| Padding | `EdgeInsets.symmetric(horizontal: 24, vertical: 0)` (height from constraint) |
| Border radius | `radius.pill` → `BorderRadius.circular(999)` (fully rounded) |
| Fill (default) | `accent` (`colorScheme.primary`) |
| Foreground (default) | `onAccent` (`colorScheme.onPrimary`) |
| Border | none |
| Text style | `labelLarge` (body font, 14 sp, weight 600) |
| Elevation | 0 |
| Pressed fill | `accent` + ripple `onAccent.withOpacity(0.12)` |
| Disabled fill | `text.withOpacity(0.12)` |
| Disabled foreground | `text.withOpacity(0.38)` |

```dart
// ThemeData plug-in point
filledButtonTheme: FilledButtonThemeData(
  style: FilledButton.styleFrom(
    minimumSize: const Size(64, 48),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    shape: const StadiumBorder(),
    textStyle: mergedTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  ),
),
```

---

## 4. Filled Tonal Button — `FilledButton.tonal` (secondary)

Secondary action. Surface fill, accent-tinted text.

| Property | Value |
|----------|-------|
| Min height | 48 dp |
| Padding | `EdgeInsets.symmetric(horizontal: 24)` |
| Border radius | `radius.pill` (`BorderRadius.circular(999)`) |
| Fill (default) | `surface` (`colorScheme.surface`) |
| Foreground (default) | `accent` (`colorScheme.primary`) |
| Border | 1 dp `border` (`colorScheme.outline`) |
| Text style | `labelLarge`, weight 500 |
| Elevation | 0 |
| Pressed fill | `surface` + ripple `accent.withOpacity(0.12)` |
| Disabled fill | `text.withOpacity(0.12)` |
| Disabled foreground | `text.withOpacity(0.38)` |

Note: M3 `FilledButton.tonal` maps `secondaryContainer` as fill. Since Kaizen does not set
`secondaryContainer`, override with explicit `FilledButton.tonal.styleFrom` targeting surface.

---

## 5. Outlined Button — `OutlinedButtonThemeData`

Repeated low-risk actions (log sets, import, destructive-confirm).

| Property | Value |
|----------|-------|
| Min height | 48 dp |
| Padding | `EdgeInsets.symmetric(horizontal: 20)` |
| Border radius | `radius.pill` (`BorderRadius.circular(999)`) |
| Fill (default) | transparent |
| Foreground (default) | `text` (`colorScheme.onSurface`) |
| Border | 1 dp `border` (`colorScheme.outline`) |
| Text style | `labelLarge`, weight 500 |
| Pressed border | 1 dp `accent` |
| Pressed fill | `accent.withOpacity(0.08)` |
| Disabled border | `border.withOpacity(0.38)` |
| Disabled foreground | `text.withOpacity(0.38)` |
| Danger variant | border `ember`, foreground `ember` (applied locally, not in theme) |

```dart
outlinedButtonTheme: OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    minimumSize: const Size(64, 48),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    shape: const StadiumBorder(),
    side: BorderSide(color: p.border),
    foregroundColor: p.text,
    textStyle: mergedTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
  ),
),
```

---

## 6. Text Button — `TextButtonThemeData`

Inline links and navigation nudges. No fill, no border, minimum chrome.

| Property | Value |
|----------|-------|
| Min height | 48 dp (touch target preserved even though visual height is smaller) |
| Padding | `EdgeInsets.symmetric(horizontal: 12, vertical: 0)` |
| Border radius | `radius.sm` (`BorderRadius.circular(8)`) |
| Fill | transparent |
| Foreground (default) | `textMuted` (`ext.textMuted`) |
| Foreground (accent link) | `accent` (`colorScheme.primary`) — used for "View report →" pattern |
| Border | none |
| Text style | `labelLarge`, weight 400 |
| Pressed fill | `text.withOpacity(0.06)` |
| Disabled foreground | `textMuted.withOpacity(0.38)` |

Current state: `_ToneToggle` in today_screen.dart and "View report →" in health_screen.dart both
use `TextButton.icon` — these are correct usage. The foreground should be `textMuted` (neutral),
not `accent`, unless the button is the primary link on an otherwise bare surface.

```dart
textButtonTheme: TextButtonThemeData(
  style: TextButton.styleFrom(
    minimumSize: const Size(48, 48),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    foregroundColor: p.textMuted,
    textStyle: mergedTextTheme.labelLarge,
  ),
),
```

---

## 7. FAB — `FloatingActionButtonThemeData`

Global creation action. Bottom-right, min gap ≥ 16 dp above nav bar.

| Property | Value |
|----------|-------|
| Shape | `StadiumBorder` (pill; M3 extended FAB default) |
| Background | `accent` (`colorScheme.primary`) |
| Foreground / icon+label | `onAccent` (`colorScheme.onPrimary`) |
| Elevation | 0 (flat, consistent with zero-elevation design language) |
| Focus elevation | 0 |
| Hover elevation | 0 |
| Extended FAB text style | `labelLarge`, weight 600 |
| Min tap area | 56 dp height (standard FAB), 48 dp height (mini FAB if used) |
| FAB gap from nav bar | `floatingActionButtonLocation: FloatingActionButtonLocation.endFloat` gives default 16 dp; do NOT override to less. |
| Scroll collapse | CollapsingFab: extended → mini on scroll-down, extended on scroll-up (already implemented in `core/widgets/collapsing_fab.dart`). Tablet uses standard extended FAB without collapse. |

```dart
floatingActionButtonTheme: FloatingActionButtonThemeData(
  backgroundColor: p.accent,
  foregroundColor: p.onAccent,
  elevation: 0,
  focusElevation: 0,
  hoverElevation: 0,
  shape: const StadiumBorder(),
  extendedTextStyle:
      mergedTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
),
```

---

## 8. AppBar — `AppBarTheme`

Frameless, blends into bg. Title uses display font (Fraunces/Instrument Serif per theme).

| Property | Value |
|----------|-------|
| Background | `bg` (`scaffoldBackgroundColor`) |
| Foreground | `text` (`colorScheme.onSurface`) |
| Elevation | 0 |
| Shadow color | none |
| Scroll under elevation | 0 (no shadow on scroll; use a subtle divider if needed) |
| Title text style | display font, 20 sp, weight 600, color `text` |
| Leading button (Profile avatar) | `CircleAvatar` radius 16, fill `accent`, icon `onAccent` — **already correct** |
| Center title | true (mobile); false (not applicable — tablets use NavigationRail, no AppBar) |
| Toolbar height | 56 dp (default) |

The AppBar title changes per active tab (scaffold_with_nav_bar.dart `_tabTitle`). This is correct
— do not add per-screen AppBars that duplicate this chrome.

```dart
appBarTheme: AppBarTheme(
  backgroundColor: p.bg,
  foregroundColor: p.text,
  elevation: 0,
  scrolledUnderElevation: 0,
  centerTitle: true,
  titleTextStyle: display(const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
),
```

---

## 9. BottomNavigationBar — `BottomNavigationBarThemeData`

Mobile 4-tab bar. No surface tint, no elevation. Active tab uses accent pill indicator.

| Property | Value |
|----------|-------|
| Background | `surface` (`colorScheme.surface`) |
| Selected item color | `accent` (`colorScheme.primary`) |
| Unselected item color | `textMuted` (`ext.textMuted`) |
| Type | `BottomNavigationBarType.fixed` |
| Elevation | 0 |
| Selected label style | `labelSmall`, weight 600 |
| Unselected label style | `labelSmall`, weight 400 |
| Icon size | 24 dp |
| Item min width | floor(screenWidth / 4) — Flutter handles automatically for `fixed` type |
| Top border | 1 dp `border` (add via `DecoratedBox` wrapper in `ScaffoldWithNavBar`, not in theme) |

Active-tab pill: M3 `NavigationBar` renders the indicator natively. With `BottomNavigationBar`
(M2 widget currently used), the filled-pill indicator requires a custom `activeIcon` wrapped in a
`Container` with `accent.withOpacity(0.15)` pill background. This is a **known gap** — migrating
to `NavigationBar` (M3) enables the pill indicator from `NavigationBarThemeData` automatically.

### NavigationBarThemeData (for future M3 migration)

| Property | Value |
|----------|-------|
| Background | `surface` |
| Indicator color | `accent.withOpacity(0.15)` |
| Icon color (active) | `accent` |
| Icon color (inactive) | `textMuted` |
| Label text style (active) | `labelSmall`, weight 600, color `accent` |
| Label text style (inactive) | `labelSmall`, weight 400, color `textMuted` |
| Height | 64 dp |
| Elevation | 0 |

```dart
// Current (M2)
bottomNavigationBarTheme: BottomNavigationBarThemeData(
  backgroundColor: p.surface,
  selectedItemColor: p.accent,
  unselectedItemColor: p.textMuted,
  type: BottomNavigationBarType.fixed,
  elevation: 0,
  selectedLabelStyle: mergedTextTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
  unselectedLabelStyle: mergedTextTheme.labelSmall,
),
```

---

## 10. Card — `CardThemeData`

Surface containers for content blocks (task groups, water card, sleep card, nav tiles).

| Property | Value |
|----------|-------|
| Color | `surface` (`colorScheme.surface`) |
| Border | 1 dp `border` (`colorScheme.outline`) |
| Border radius | `radius.md` → `BorderRadius.circular(16)` |
| Elevation | 0 |
| Shadow | none |
| Clip | `Clip.antiAlias` (prevents child overflow past rounded corners) |
| Padding (internal convention) | `EdgeInsets.all(16)` — enforced by card content, not CardTheme |
| Margin (default) | `EdgeInsets.zero` — spacing handled by parent `ListView` / `Column` gap |
| Surface tint | `Colors.transparent` (suppress M3 elevation tint) |

Special card variants (not in ThemeData — apply locally):
- **Ember card** (exam countdown): border color `ember`, 1.5 dp width. Stays pinned at top of Plan timeline.
- **Review card** (morning/evening): left border accent 3 dp, otherwise same as default card.

```dart
cardTheme: CardThemeData(
  color: p.surface,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  clipBehavior: Clip.antiAlias,
  margin: EdgeInsets.zero,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(color: p.border),
  ),
),
```

---

## 11. Chip — `ChipThemeData`

Used for type selector (task/event/exam/deadline), priority selector (low/medium/high/main),
and "what went wrong" multi-select in Diary.

| State | Fill | Foreground | Border |
|-------|------|------------|--------|
| Unselected | `surface` | `textMuted` | 1 dp `border` |
| Selected | `accent` | `onAccent` | none |
| Disabled | `surface.withOpacity(0.5)` | `textMuted.withOpacity(0.38)` | 1 dp `border.withOpacity(0.38)` |
| Pressed ripple | `accent.withOpacity(0.12)` on unselected; `onAccent.withOpacity(0.12)` on selected | — | — |

| Property | Value |
|----------|-------|
| Shape | `StadiumBorder` (`BorderRadius.circular(999)`, pill) |
| Label padding | `EdgeInsets.symmetric(horizontal: 12, vertical: 0)` |
| Min tap height | 36 dp visual / 48 dp touch target (Flutter wraps chips in a GestureDetector with 48 dp hit slop) |
| Label text style | `labelMedium` (12 sp, weight 500) |
| Avatar size | 18 dp (if icon chip) |
| Delete icon color | `textMuted` |
| Padding | `EdgeInsets.symmetric(horizontal: 4)` (outer chip padding) |

Note: `main` priority chip must additionally render a shield icon (`Icons.shield_outlined`) in the
label to communicate the "protected" concept. Selected `main` chip: accent fill + onAccent shield.

```dart
chipTheme: ChipThemeData(
  backgroundColor: p.surface,
  selectedColor: p.accent,
  disabledColor: p.surface.withOpacity(0.5),
  labelStyle: mergedTextTheme.labelMedium?.copyWith(color: p.text),
  secondaryLabelStyle: mergedTextTheme.labelMedium?.copyWith(color: p.onAccent),
  side: BorderSide(color: p.border),
  shape: const StadiumBorder(),
  padding: const EdgeInsets.symmetric(horizontal: 4),
  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
  showCheckmark: false, // use fill color change as selection indicator, not a checkmark
),
```

---

## 12. Input Decoration — `InputDecorationTheme`

Used in AddTaskSheet (title field), search fields, and all auth/profile forms.

| State | Fill | Border |
|-------|------|--------|
| Enabled | `surface` | 1 dp `border`, radius 8 |
| Focused | `surface` | 1.5 dp `accent`, radius 8 |
| Error | `surface` | 1.5 dp `ember`, radius 8 |
| Disabled | `surface.withOpacity(0.5)` | 1 dp `border.withOpacity(0.38)`, radius 8 |

| Property | Value |
|----------|-------|
| Fill | true, fill color `surface` |
| Border radius | `radius.sm` → `BorderRadius.circular(8)` |
| Content padding | `EdgeInsets.symmetric(horizontal: 16, vertical: 14)` (total height ≈ 48 dp) |
| Hint style | `bodyMedium`, color `textMuted` |
| Label style | `bodySmall`, color `textMuted` |
| Floating label style | `labelSmall`, color `accent` (when focused) / `textMuted` (when not) |
| Error style | `labelSmall`, color `ember` |
| Prefix icon color | `textMuted` |
| Suffix icon color | `textMuted` (clear button, eye toggle) |
| Cursor color | `accent` |

```dart
inputDecorationTheme: InputDecorationTheme(
  filled: true,
  fillColor: p.surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: p.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: p.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: p.accent, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: p.ember, width: 1.5),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: p.ember, width: 1.5),
  ),
  disabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: p.border.withOpacity(0.38)),
  ),
  hintStyle: mergedTextTheme.bodyMedium?.copyWith(color: p.textMuted),
  labelStyle: mergedTextTheme.bodySmall?.copyWith(color: p.textMuted),
  floatingLabelStyle: mergedTextTheme.labelSmall?.copyWith(color: p.accent),
  errorStyle: mergedTextTheme.labelSmall?.copyWith(color: p.ember),
),
```

---

## 13. Segmented Button — `SegmentedButtonThemeData`

Used on Plan screen (Day / Week / Month switcher) and Health hub (Food / Water / Train / Sleep).

| State | Fill | Foreground | Border |
|-------|------|------------|--------|
| Unselected | transparent | `textMuted` | 1 dp `border` (drawn by the segmented button outline) |
| Selected | `accent` | `onAccent` | none (segment blends into solid) |
| Pressed (unselected) | `accent.withOpacity(0.08)` | `text` | 1 dp `border` |
| Disabled | — | `textMuted.withOpacity(0.38)` | 1 dp `border.withOpacity(0.38)` |

| Property | Value |
|----------|-------|
| Shape (outer) | `RoundedRectangleBorder` with `BorderRadius.circular(radius.pill)` wrapping `OutlinedBorder` — gives pill-shaped outer container |
| Individual segment radius | follows outer shape (segments share the border) |
| Min tap height | 40 dp visual / 48 dp touch |
| Text style | `labelMedium`, weight 600 for selected, weight 400 for unselected |
| Icon size | 18 dp |
| Padding per segment | `EdgeInsets.symmetric(horizontal: 16)` |
| Selected icon (checkmark) | hidden (`showSelectedIcon: false`) — fill color is the only indicator |

```dart
segmentedButtonTheme: SegmentedButtonThemeData(
  style: SegmentedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: p.textMuted,
    selectedForegroundColor: p.onAccent,
    selectedBackgroundColor: p.accent,
    side: BorderSide(color: p.border),
    shape: const StadiumBorder(),
    minimumSize: const Size(0, 40),
    textStyle: mergedTextTheme.labelMedium,
  ),
),
```

---

## 14. Bottom Sheet — `BottomSheetThemeData`

Used for AddTaskSheet, AI menu sheet, import sheet, and all other modal sheets.

| Property | Value |
|----------|-------|
| Background | `surface` (`colorScheme.surface`) |
| Surface tint | `Colors.transparent` (suppress M3 elevation tint — already patched in showAddTaskSheet) |
| Shape | `RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)))` — `radius.lg` top corners |
| Clip | `Clip.antiAlias` |
| Elevation | 0 |
| Modal barrier color | `Colors.black.withOpacity(0.5)` (dark themes) / `Colors.black.withOpacity(0.3)` (white theme) |
| Drag handle | show (`showDragHandle: true`), color `border`, width 36 dp, height 4 dp, top margin 8 dp |
| Constraints | none in theme — individual sheets set `isScrollControlled: true` and `maxHeight` via `DraggableScrollableSheet` as needed |

Note: current `showAddTaskSheet` overrides `shape` and `backgroundColor` locally. Once this theme
entry is set centrally, those local overrides can be removed.

```dart
bottomSheetTheme: BottomSheetThemeData(
  backgroundColor: p.surface,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  clipBehavior: Clip.antiAlias,
  showDragHandle: true,
  dragHandleColor: p.border,
  dragHandleSize: const Size(36, 4),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
),
```

---

## 15. Snack Bar — `SnackBarThemeData`

Used for "Night logged", water goal toasts, undo confirmations.

| Property | Value |
|----------|-------|
| Background | `surface` for dark themes; `text` for white theme (inverted) |
| Content text style | `bodyMedium`, color `text` (dark) / `bg` (white theme) |
| Action text style | `labelMedium`, color `accent`, weight 600 |
| Action overflow threshold | 0.25 (action wraps below content if text is long) |
| Shape | `RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md))` → `BorderRadius.circular(16)` |
| Behavior | `SnackBarBehavior.floating` |
| Width | none in theme — defaults to M3 floating snackbar max width |
| Elevation | 4 dp (floating snackbar needs slight shadow to lift off surface) |
| Dismiss direction | `DismissDirection.horizontal` |
| Duration (convention, not in theme) | 3 s for info, 5 s for undo (set at call site) |

Note: `AppToast` in `core/animations/app_toast.dart` wraps snackbar styling. Ensure
`SnackBarThemeData` aligns with `AppToastVariant` color logic — done/success variant should
use accent, error variant should use ember.

```dart
snackBarTheme: SnackBarThemeData(
  backgroundColor: p.brightness == Brightness.dark ? p.surface : p.text,
  contentTextStyle: mergedTextTheme.bodyMedium?.copyWith(
    color: p.brightness == Brightness.dark ? p.text : p.bg,
  ),
  actionTextColor: p.accent,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  behavior: SnackBarBehavior.floating,
  elevation: 4,
  dismissDirection: DismissDirection.horizontal,
),
```

---

## 16. Switch — (inline, no dedicated theme key needed)

Used for water reminders toggle in health_screen.dart.

| Property | Value |
|----------|-------|
| Active track color | `accent.withOpacity(0.5)` |
| Active thumb color | `accent` |
| Inactive track color | `border` |
| Inactive thumb color | `textMuted` |
| Min tap size | 48 dp (Flutter `Switch.adaptive` meets this) |

Set via `SwitchThemeData` in `ThemeData`:

```dart
switchTheme: SwitchThemeData(
  thumbColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) return p.accent;
    return p.textMuted;
  }),
  trackColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) return p.accent.withOpacity(0.5);
    return p.border;
  }),
),
```

---

## 17. Progress Indicators — (inline, no theme entry needed)

`LinearProgressIndicator` and `CircularProgressIndicator` appear in water/sleep cards and the
loading states.

| Property | Value |
|----------|-------|
| Color (active) | `accent` (`colorScheme.primary`) — Flutter M3 default uses `primary` automatically |
| Track color | `border` (`colorScheme.surfaceContainerHighest`) |
| Border radius (linear) | `BorderRadius.circular(2)` — apply at call site via `borderRadius` param |
| Min height (linear) | 4 dp at call site |

Exception: informational-only bars (secondary macro bars in Food) must NOT use accent.
Use `textMuted.withOpacity(0.3)` for those bars to respect the accent discipline rule.

---

## 18. Divider — `DividerThemeData`

Section separators and column dividers.

| Property | Value |
|----------|-------|
| Color | `border` (`ext.border`) |
| Thickness | 1 dp |
| Space (vertical) | 0 (i.e., the divider occupies exactly 1 dp; callers add SizedBox gaps) |
| Indent / endIndent | 0 (full width) — override at call site for inset dividers |

```dart
dividerTheme: DividerThemeData(
  color: p.border,
  thickness: 1,
  space: 1,
),
```

---

## 19. List Tile — `ListTileThemeData`

Nav tile cards in HealthScreen use `Card > ListTile`. All tiles in settings / profile screens.

| Property | Value |
|----------|-------|
| Content padding | `EdgeInsets.symmetric(horizontal: 16, vertical: 4)` |
| Min vertical padding | 8 dp |
| Min leading width | 24 dp |
| Icon color | `textMuted` (default) — override to `accent` only for the primary tile in a list |
| Title text style | `bodyLarge`, color `text` |
| Subtitle text style | `bodySmall`, color `textMuted` |
| Trailing icon color | `textMuted` (`chevron_right` pattern) |
| Shape | `RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))` — slightly less than card's 16 to feel inset |
| Selected tile color | `accent.withOpacity(0.08)` |
| Dense | false |

Note: nav tiles in HealthScreen currently use `colorScheme.primary` (accent) for leading icons
on every tile. Per accent discipline, only the top tile in a group (or the contextually most
important) should receive accent color; the rest should use `textMuted`. Apply at the call site,
not in theme.

---

## 20. Summary of biggest changes vs today

The two most impactful changes relative to the current `_buildTheme` implementation are:

1. **Button shapes need to move from rectangle to pill (`StadiumBorder`) across all three button
   types**, and `FilledButton` / `OutlinedButton` need explicit `minimumSize: Size(64, 48)` to
   enforce the 48 dp tap target — currently neither `FilledButtonThemeData` nor
   `OutlinedButtonThemeData` are set at all in `_buildTheme`, so every button falls back to
   Material 3 defaults (rounded rect, 40 dp height).

2. **`BottomSheetThemeData` and `SnackBarThemeData` are entirely absent from `_buildTheme`**,
   meaning sheets and toasts do not respect the surface/tint/radius rules centrally — every call
   site (especially `showAddTaskSheet`) must locally patch color and shape, which is fragile across
   5 themes; adding these two entries to `_buildTheme` will make all sheets and snackbars
   theme-coherent automatically.
