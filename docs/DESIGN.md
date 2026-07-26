# Omnia Wallet — design language

The wallet's UI is modelled on the **Bluesky** mobile app. This document records
what was actually measured from Bluesky's open-source client (rather than eyeballed),
and how each finding maps onto this Flutter codebase.

## 1. Where the numbers come from

Bluesky's design system is called **ALF** (Application Layout Framework). The tokens
live in the `@bsky.app/alf` npm package, consumed by `bluesky-social/social-app`
at `src/alf/themes.ts`. Everything in `lib/core/design/tokens.dart` is transcribed
from `@bsky.app/alf@0.1.15` — `src/palette.ts` and `src/tokens.ts`.

## 2. Colour

ALF does not use a Material-style seed. It uses four **ramps** — `contrast`,
`primary`, `positive`, `negative` — each with 13–15 steps. The dark themes are the
*same* ramps read backwards (`invertPalette`), which is why light and dark stay
in lockstep without a second hand-tuned palette.

| Role | Token |
| --- | --- |
| Page background | `contrast_0` |
| Primary text | `contrast_1000` |
| Secondary text | `contrast_700` (`text_contrast_medium`) |
| Tertiary / timestamps | `contrast_400` (`text_contrast_low`) |
| Hairline dividers | `contrast_100` (`border_contrast_low`) |
| Stronger borders | `contrast_200` / `contrast_300` |
| Accent | `primary_500` = `#006AFF` |
| Link text (dark) | `primary_600` — the ramp is inverted, so this is the *lighter* blue |

Three themes ship, exactly as Bluesky does:

- **light** — `DEFAULT_PALETTE`, background `#FFFFFF`
- **dim** — `invertPalette(DEFAULT_SUBDUED_PALETTE)`, background `#151D28`
- **dark** — `invertPalette(DEFAULT_PALETTE)`, background `#000000` (true black, for OLED)

`dim` is the default dark theme. Pure black is reserved for people who ask for it.

## 3. Scales

Straight from `src/tokens.ts`:

```
space          2 · 4 · 8 · 12 · 16 · 20 · 24 · 28 · 32 · 40
radius         2 · 4 · 8 · 12 · 16 · 20 · 999
fontSize       9.4 · 11.3 · 13.1 · 15 · 16.9 · 18.8 · 20.6 · 24.3 · 30 · 37.5
lineHeight     tight 1.15 · snug 1.3 · relaxed 1.5
weight         400 · 500 · 600 · 700
tracking       0
```

Two things worth calling out because they are unusual and very much "the Bluesky look":

- **Font sizes are fractional** (15, 16.9, 18.8…). It is a 1.125 modular scale from a
  15px base, not rounded. Rounding them to 14/16/18 measurably changes the feel.
- **Tracking is zero everywhere.** No negative letter-spacing on headings. The old
  Omnia theme used `-0.6` on titles; that has been removed.

## 4. Shape

Bluesky is a **flat, hairline-separated** interface. There are no elevated cards.

- Buttons are **fully rounded pills** (`radius.full`) at every size. Not 16px rounded
  rectangles.
- Bottom sheets use a **20px top corner radius** — `cornerRadius={20}` in
  `src/components/Dialog/index.tsx`.
- Content cards, inputs and images use `radius.md` (12) or `radius.sm` (8).
- Separation comes from 1px `border_contrast_low` hairlines that run **full-bleed**,
  edge to edge — not from insets, shadows, or filled card backgrounds.

Button geometry, from `src/components/Button.tsx`:

| Size | Padding V | Padding H | Gap | Text |
| --- | --- | --- | --- | --- |
| large | 12 | 24 | 6 | 15 / medium |
| small | 8 | 14 | 5 | 13.1 / medium |
| tiny | 5 | 10 | 3 | 11.3 / semibold |

Colour variants: solid primary is `primary_500` → `primary_600` when pressed, disabled
`primary_200`. Solid secondary is `contrast_50` → `contrast_100`. Solid negative is
`negative_500` → `negative_600`.

## 5. Haptics — the finding that matters

From `src/lib/haptics.ts`:

```ts
// Users said the medium impact was too strong on Android; see APP-537
const style = isIOS ? ImpactFeedbackStyle[strength] : ImpactFeedbackStyle.Light
```

**Android clamps every impact to Light.** This is the single most important haptics
detail in the whole app and it is why most Flutter apps feel "buzzy" on Android:
`HapticFeedback.mediumImpact()` on Android maps to a much heavier vibration than the
iOS taptic equivalent. `lib/core/haptics.dart` reproduces the clamp.

Three further rules implemented on top of that:

1. **Micro-haptics must be rate-limited.** A selection tick fired on every page-view
   frame, or on every character of an amount field, turns into a continuous buzz.
   `Haptics.tick()` is throttled to one pulse per 40 ms.
2. **Fire on touch-down, not on tap-up.** Perceived latency is dominated by when the
   haptic lands, not when the visual lands. Every `Pressable` fires its haptic in
   `onTapDown`.
3. **Compound patterns need real gaps.** A "success" pattern that fires two impacts
   back to back reads as one smeared buzz. 90 ms between pulses is the floor at which
   two taps read as two taps.

Haptics are user-disableable (Bluesky has the same preference) and are suppressed
entirely on web.

## 6. Motion

Bluesky's stack navigator uses the platform-native push (iOS horizontal slide,
predictive-back on Android) and reserves fades for tab switches. `lib/core/motion.dart`
mirrors that: pushed routes slide horizontally with a parallax on the outgoing screen;
tab switches cross-fade with no travel.

Durations are short. Anything over ~300 ms on a tap response reads as sluggish:

```
micro  90ms   press-state changes
fast   180ms  sheets closing, chips
normal 260ms  page pushes, sheet opening
slow   420ms  hero / count-up
```

The press interaction is scale **and** opacity (0.97 / 0.85), which is what React
Native's `Pressable` does by default and what makes RN apps feel different from
Material's ink ripple. Ripples are disabled app-wide (`splashFactory: NoSplash`).

## 7. Navigation

Bluesky is a **5-tab bottom shell**. Tabs never push over the tab bar; the bar is
always visible, translucent, with a 1px top hairline. Inactive icons are the *linear*
weight, active icons are the *bold* weight of the same glyph, and the label is hidden.

Iconsax ships exactly this pairing: `Iconsax.home` is the bold cut, `Iconsax.home_copy`
is the linear cut (verified by rendering the glyphs out of `FlutterIconsax.ttf`). So
`Iconsax.x` / `Iconsax.x_copy` is the active/inactive pair throughout the app.

Tabs: **Home · Activity · News · Notifications · Profile**.

## 8. Sheets over dialogs

Bluesky has essentially no centred alert dialogs on mobile — every confirmation,
picker, form and menu is a bottom sheet with a grab handle. This app previously used
`AlertDialog` for 11 different flows; all of them are now
`showOmniaSheet` / `showOmniaConfirm` / `showOmniaMenu` (`lib/core/ui/sheet.dart`).

## 9. Iconography

`iconsax_flutter ^1.0.1` — 1,025 glyphs × 2 weights. Material Icons are no longer used
anywhere in `lib/`.

## 10. SVG assets

The previous build had three genuine rendering bugs, all now fixed:

1. `signin_screen.dart` loaded `assets/brand_icons/google_g.png` and `github_mark.png`.
   Those files never existed — only `.svg` did. Both slots rendered as broken/blank.
2. `hero_dots.svg` drew a 400-circle grid in `#8A8A8A` at `fill-opacity="0.08"` over a
   `#2563EB` radial glow. On the dark background that is invisible — the "blank"
   hero. It was also 28 KB of hand-unrolled `<circle>` elements.
3. `github_mark.svg` hard-coded `fill="#000000"`, so it disappeared on dark.

All brand/illustration SVGs now paint in `currentColor` and are tinted at the call
site with a `ColorFilter`, so they track the theme. `hero_dots.svg` is replaced by
`hero_glow.svg`, a 1 KB gradient + `<pattern>` that renders identically at any size.
