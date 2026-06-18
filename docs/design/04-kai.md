# Kai 2.0 — Placement, Sizing & Trigger Design

> Source of truth for Kai placement, sizing, and per-moment behaviour.
> Complements MASCOT.md (form/expressions/tone), ANIMATIONS.md (durations/curves),
> and design-tokens.json (accent colours per theme).
> Status references are relative to the current widget in
> app/lib/features/mascot/kai_mascot.dart.

---

## 1. Resting State: Size and Placement

### 1.1 Size Decision

The current default of 44 px is too small on modern phones. At 44 px the squircle body
occupies roughly the same footprint as a standard icon tap target, which is appropriate
for minimum interaction size but reads as an icon rather than a presence. The asymmetric
eyes and breathing animation are both too subtle to register personality at that size.

**Decision: 56 px is the canonical ambient/header size.**

At 56 px:
- The squircle reads as a distinct shape, not an icon.
- The ±2% breathing scale (1.12 px) becomes perceptible without being distracting.
- The jitter on `anxious` is clearly readable (±1.5 px).
- It sits comfortably in the Today header row alongside a two-line greeting without
  forcing layout overflow.
- On 375 px wide screens (iPhone SE) the header Row remains comfortable: greeting
  text (~220 px) + 8 px gap + 56 px Kai + 8 px gap + tone toggle (~80 px) = ~372 px.

The celebration overlay and empty-state placements are larger because they are
contextual focal points, not ambient. See per-surface table below.

### 1.2 Per-Surface Sizes

| Surface | Size (dp) | Rationale |
|---|---|---|
| Today header (ambient) | **56** | Presence without domination |
| Focus session corner (ambient) | **40** | Deliberately subordinate; user is working |
| Celebration overlay (focal point) | **72** | Leading element above the checkmark |
| Review cards (morning / evening) | **48** | Contextual, mid-prominence |
| Empty state / long absence | **64** | Single focal element on an otherwise empty screen |
| Home widget | **32** | Constrained by widget canvas; keep legible |
| Plan screen review (future) | **48** | Matches review card convention |

> Note on focus: the existing code uses 40 px for the focus corner. Keep it.
> The reasoning in the code comment ("deliberately subordinate") is correct.

### 1.3 Today Screen Placement Rule

Current placement: trailing element of the header Row, between the greeting and the
tone toggle. This is correct and must be kept.

```
[Header Row]
  ├─ Expanded: _Header (greeting + date, 2 lines)  ← crossAxisAlignment.start
  ├─ SizedBox(width: 8)
  ├─ _KaiHeader(size: 56)  ← Padding(top: 4) for optical alignment with title baseline
  └─ _ToneToggle
```

The `top: 4` padding centres Kai optically against the two-line greeting. The ring
(`ProgressRing`) lives below the header, so Kai never overlaps it.

**General placement rule for other surfaces:** Kai must always be inert and ambient.
It appears at the top or bottom of the content area, never overlaid on actionable
content. On full-screen momentary overlays (celebration) it may be centred. On
persistent screens it lives in a fixed corner or in a designated "header presence" slot
aligned to the screen's primary reading anchor.

---

## 2. Trigger Table

One row per app moment. All placements assume `showKai == true` and
`MediaQuery.disableAnimations == false`; when either is false, Kai is static/hidden
per existing guard logic.

| # | Moment | Appears? | Expression | Size (dp) | Placement | What Kai does (motion / duration) | Tone variant | Status |
|---|---|---|---|---|---|---|---|---|
| T1 | Today idle — no tasks pending, no overdue | Yes | `neutral` | 56 | Today header trailing | Idle breathing cycle ±2% scale, period ~3.5 s, ping-pong, kCurveLift | Gentle: slow levitation. Harsh: slightly sharper rest, same breathing | Already implemented (size change: 44→56) |
| T2 | Today in-progress — some main tasks pending, none overdue | Yes | `neutral` | 56 | Today header trailing | Identical to T1. No additional motion | Both | Already implemented |
| T3 | Today all main done (pre-celebration) | Yes | `success` | 56 | Today header trailing | Morph to circle (kCurveSpring, 280 ms) + single spring bounce scale 1→1.08→1 (280 ms). Breathing continues on new shape | Both | Already implemented (size 44→56 is the only delta) |
| T4 | Overdue main/important task exists today | Yes | `anxious` | 56 | Today header trailing | Jitter ±1.5 px horizontal, 80 ms cycle (existing). Morph to compressed squircle. Gentle: jitter is soft. Harsh: jitter is sharper; ember eye colour fires | Gentle: jitter only. Harsh: ember eyes + jitter | Already implemented (emotion logic exists in today_screen.dart) |
| T5 | Morning review card visible | Yes | `thinking` | 56 | Today header trailing | Vertical stretch squircle (scaleY 1.10). One eye half-closed. Slow pulse on the stretched body via breathAnim (existing controller suffices: amplitude unchanged, but scaleY base shifts). Duration of morph to thinking: kDurationNormal (280 ms) | Both | Already implemented |
| T6 | Evening review visible (hour >= 17, pending mains) | Yes | `thinking` | 56 | Today header trailing | Same as T5 | Both | Already implemented |
| T7 | Celebration overlay — all main tasks just closed | Yes | `success` | 72 | Overlay centre, above checkmark (currently 56 in code; bump to 72) | Fade-in opacity 0→1 over _checkScale interval (200–500 ms). On completion: Gentle: spring to near-circle, single slow bob up 4 px then back (400 ms, kCurveSpring). Harsh: single sharp nod scale 1→0.9→1 (280 ms, kCurveSnap) then static | Gentle: celebratory spring. Harsh: restrained nod ("fine, you did it") | Partially implemented — size 56, no tone split on motion |
| T8 | Celebration overlay — harsh tone variant | Yes | `success` (but isHarsh=true overrides eye colour to ember, and adds brow) | 72 | Same as T7 | Nod (scale 1→0.9→1, 280 ms). No spring bounce. Dissolves cleanly when overlay closes | Harsh only | NEW (tone split for celebration) |
| T9 | Focus session — work phase active | Yes | `thinking` | 40 | Bottom-right corner, IgnorePointer | Existing: slow breathing. No change needed | Both | Already implemented |
| T10 | Focus session — break phase | Yes | `neutral` | 40 | Bottom-right corner, IgnorePointer | Existing: breathing in neutral. No change needed | Both | Already implemented |
| T11 | Focus session — user attempts to leave (app backgrounded during work phase) | Yes | `anxious` (or `harsh` if isHarsh) | 40 | Bottom-right corner | Rapid eye-open morph from thinking→anxious (kDurationSnap, 120 ms) + jitter fires. This is the "friction" moment from SPEC §C8. Reverts to thinking when app returns to foreground | Gentle: anxious. Harsh: harsh expression (ember eyes, brow) | NEW — requires AppLifecycleListener in FocusScreen |
| T12 | Long absence / empty state (Today has zero tasks, first open after multi-day gap) | Yes | `away` | 64 | Centre of empty state area, above empty-state copy | Static (away eyes, slight opacity 0.75). No breathing cycle — stillness is the message. Fade in opacity 0→0.75 over kDurationNormal (280 ms) on first render | Both (expression unchanged; harsh would show narrow "away" eyes, slightly more closed) | NEW — requires empty-state detection |
| T13 | Morning review card — Kai "presents" the cards | Yes | `thinking` | 48 | Leading slot inside the MorningReviewCard header row (left of title text) | Morph to thinking on card appear. While card is visible: subtle periodic single-blink (left eye briefly to 0.04 height, 120 ms, then back, every ~6 s). This reads as attentiveness, not animation spam | Both | NEW — requires KaiMascot in MorningReviewCard widget |
| T14 | Evening review card visible | Yes | `thinking` | 48 | Leading slot inside EveningReviewCard header row | Same as T13 | Both | NEW — requires KaiMascot in EveningReviewCard widget |
| T15 | Water log (Phase 1, optional) | Optional | `success` | 40 | Inline beside water progress bar, fades in on log | Single spring bounce (scale 1→1.1→1, kCurveSpring, 280 ms) when water is logged | Both | NEW, Phase 1 polish |
| T16 | Health/habit check logged (Phase 1, optional) | Optional | `neutral` | 40 | Trailing in the habit row that was just checked | Small nod (scale 1→0.95→1, kDurationFast, 180 ms) | Both | NEW, Phase 1 polish |

---

## 3. Behaviour Polish

### 3.1 Idle Breathing Subtlety

The current 3.5 s / ±2% breathing is the right calibration. Do not change the
amplitude or period. The cycle should only run when Kai is in `neutral`, `success`, or
`away` emotions. For `thinking` the existing pulsation on the vertically stretched body
substitutes for breathing — running both simultaneously would be visually noisy.
For `anxious` the jitter replaces breathing. For `harsh` (isHarsh override)
breathing continues on the compressed shape, but at half amplitude (±1%), because a
slightly tense presence that barely breathes is more unsettling than one that breathes
normally.

Proposed: add a `breathAmplitude` computed property in `_KaiMascotState`:
```dart
double get _breathAmplitude {
  if (widget.emotion == KaiEmotion.anxious) return 0;
  if (widget.emotion == KaiEmotion.thinking) return 0;
  if (widget.isHarsh) return 0.01;   // half amplitude in harsh
  return 0.02;                        // default ±2%
}
```

Then replace the hardcoded `0.04` in the build method:
```dart
final breathScale = 1.0 + (_breathAnim.value - 0.5) * (_breathAmplitude * 2);
```

### 3.2 Harsh Tone: Override vs Compose

**Recommendation: compose, not override.**

When `isHarsh == true`, the existing code uses the `isHarsh` branch in `_stateFor`
unconditionally — it returns the harsh expression regardless of the passed `emotion`.
This is too blunt. The `emotion` carries semantic meaning (the app state is different
when all tasks are done vs when an overdue task exists), and that semantic should
survive the tone toggle.

Proposed composition rule:

- `isHarsh` drives eye colour (→ ember), brow presence (showBrow=1), and body shape
  (cornerRadius -= 0.08, scaleY += 0.04 to feel more taut).
- `emotion` still drives the primary morph: success still springs toward a circle;
  anxious still compresses; thinking still stretches. The harsh modifications are
  *additive offsets on top of* the emotion state, not a replacement.

Implementation: in `_stateFor`, instead of the early `if (isHarsh) return ...` branch,
keep the emotion switch as the base and then apply harsh offsets:

```dart
_KaiState _stateFor(KaiEmotion emotion, bool isHarsh) {
  var base = _emotionBase(emotion);   // pure emotion, no harsh
  if (isHarsh) {
    base = _KaiState(
      cornerRadius: (base.cornerRadius - 0.08).clamp(0.40, 0.90),
      scaleY: base.scaleY + 0.04,
      leftEyeHeight: base.leftEyeHeight * 0.55,   // eyes flatten ~55%
      rightEyeHeight: base.rightEyeHeight * 0.55,
      leftEyeArch: base.leftEyeArch * 0.3,        // arches suppress
      rightEyeArch: base.rightEyeArch * 0.3,
      leftEyeOffsetY: base.leftEyeOffsetY,
      rightEyeOffsetY: base.rightEyeOffsetY,
      showBrow: 1.0,
      opacity: base.opacity,
    );
  }
  return base;
}
```

This means a harsh-tone success still has arched eyes (joy) but the brow and ember
colour signal the tone. A harsh anxious has both the jitter AND ember eyes. The
distinction reads as personality consistency rather than a mode flip.

### 3.3 When Morph Fires

Morph (the transition between `_KaiState` values) fires automatically via
`didUpdateWidget` when `emotion` or `isHarsh` changes. This is already correct.
The spring curve is already used for `success`; the lift curve for all others.

Additional morph rule for the blink micro-interaction in review cards (T13/T14): this
is NOT a full `_KaiState` transition. It is a one-shot partial animation on
`leftEyeHeight` only. Implement it as a separate `AnimationController` with duration
`kDurationSnap` (120 ms), forward then reverse, triggered by a periodic `Timer` every
6 seconds while the card is visible.

### 3.4 Tap Micro-Interaction

Current: `onTap` is an optional callback, reserved for future use.

**Decision:** On tap, cycle through a fixed emotional sequence:
`neutral → success → thinking → neutral`. This gives users a way to "pet" Kai without
adding any navigation or action. It resets to the driven emotion after 3 s (restore
the app-state-derived expression).

The cycle is purely cosmetic and must not fire if `onTap` is externally assigned to
something meaningful. Implement in `_KaiHeader` as a local override:

```dart
// In _KaiHeader widget:
KaiMascot(
  size: 56,
  emotion: _tapOverride ?? widget.emotion,
  isHarsh: widget.isHarsh,
  onTap: _handleTap,
)
```

Where `_handleTap` advances `_tapOverride` through the cycle and starts a 3 s timer
to clear it. Three taps in quick succession cycles through all three expressions.

---

## 4. Implementation Notes for the Flutter Developer

### 4.1 Existing Params — No New Required Params for Core Behaviour

All core behaviour described in this document works within the existing `KaiMascot`
constructor:

```dart
KaiMascot({
  this.size = 44,        // bump default to 56
  this.emotion = KaiEmotion.neutral,
  this.isHarsh = false,
  this.onTap,
})
```

Change the default `size` from 44 to 56. All existing callsites that pass `size`
explicitly will be unaffected. Only callsites that rely on the default (none in the
current codebase — all pass size explicitly) would change.

### 4.2 One Optional New Param: `breathAmplitude` Override

This is only needed if the harsh-tone half-amplitude rule (§3.1) is made a callsite
concern rather than internal logic. The simpler approach is to compute it internally
from `isHarsh` and `emotion` as shown in §3.1 — no new param needed.

### 4.3 Harsh-State Composition Refactor

The only structural code change is splitting `_stateFor` into `_emotionBase` + harsh
overlay as described in §3.2. This is a low-risk, self-contained refactor. The
existing `_lerpState` function handles the resulting `_KaiState` values without
modification.

### 4.4 Review Card Kai — New Widget Param

`MorningReviewCard` and `EveningReviewCard` need to accept Kai. They currently do not.
The cleanest approach: both cards are `ConsumerWidget`; they already read `toneProvider`.
Add a leading `KaiMascot` in their header row, reading `showKaiProvider` internally.
No new props needed on the card constructors — the mascot visibility is a global toggle.

### 4.5 Focus Screen — App Lifecycle Listener (T11)

The "tries to leave" friction (T11) requires detecting app backgrounding during the
work phase. Add `AppLifecycleListener` to `_FocusScreenState` and set a local
`_kaiEmotionOverride` to `KaiEmotion.anxious` (or `KaiEmotion.harsh` if isHarsh) for
2 s when `AppLifecycleState.inactive` fires during `_Phase.work`. The mascot in the
bottom-right corner responds automatically because it reads `emotion`.

### 4.6 Empty State (T12)

The empty-state trigger (T12) requires a condition in `TodayScreen`: if the items list
is empty AND the last session was more than 24 h ago (read from SharedPreferences or
the Drift `DayLogsTable`). Show an `away` Kai at 64 px centred in the body, replacing
or sitting above the empty-state copy widget.

### 4.7 Celebration Size Bump (T7)

In `celebration_overlay.dart`, line 340: change `size: 56` to `size: 72`. One line.

### 4.8 Priority Order for New Placements

| Priority | Task | Effort |
|---|---|---|
| 1 | Bump `_KaiHeader` size 44→56 in today_screen.dart | 1 line |
| 2 | Bump celebration overlay size 56→72 in celebration_overlay.dart | 1 line |
| 3 | Harsh-compose refactor in kai_mascot.dart (_stateFor split) | ~30 lines, low risk |
| 4 | Tap cycle micro-interaction in _KaiHeader | ~20 lines |
| 5 | Kai in MorningReviewCard + EveningReviewCard (T13/T14) | new widget slot per card |
| 6 | App lifecycle listener for focus friction (T11) | ~25 lines in FocusScreen |
| 7 | Empty state / away placement (T12) | conditional branch in Today body |
| 8 | Harsh celebration tone split (T8) | condition in celebration_overlay.dart |
| 9 | Phase 1 polish: Water/Health micro-reactions (T15/T16) | deferred |

---

## Summary

The canonical resting size is **56 dp** in the Today header, replacing the current
44 dp. This is the minimum size at which the squircle reads as a personality rather than
an icon, and it fits within the header row on all target screen widths without overflow.

The three highest-value new appearances, in order of emotional impact:

1. **Review card Kai (T13/T14)** — placing a 48 dp thinking Kai inside the morning and
   evening review card headers makes Kai the character who presents the plan rebuild.
   This is the moment in MASCOT.md §6 where Kai "virtually moves blocks." It directly
   reinforces the core product promise ("Kai reassembled your day") with a visible agent,
   and requires only adding a KaiMascot widget to existing card widgets.

2. **Focus friction Kai (T11)** — the sharp neutral→anxious morph when the user
   backgrounds the app during a work phase is the single most J.A.R.V.I.S.-like moment
   in the product. It is non-blocking, requires no new tap, and creates the exact
   "friction without surveillance" described in SPEC §C8.

3. **Empty state / away (T12)** — showing a 64 dp away-expression Kai on an empty Today
   screen turns an embarrassing empty state into a character moment. The stillness of
   `away` (no breathing, 75% opacity) communicates absence without being accusatory,
   which is essential for the adult audience.

File: `C:\Users\alune\glavnoe\docs\design\04-kai.md`
