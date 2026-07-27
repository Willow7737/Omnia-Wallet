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

## 11. Threads — the reply anatomy

Replies follow Threads' anatomy rather than a flat comment list, because a
conversation with no visible structure reads as a pile of unrelated remarks.

**Geometry** (`ThreadGeometry`, `lib/core/ui/thread.dart`):

| Token       | Value | Why                                                                     |
| ----------- | ----- | ----------------------------------------------------------------------- |
| `indent`    | 30    | One avatar's radius plus the gutter — a level is legible without shouting |
| `thickness` | 2     | 1px is indistinguishable from a row hairline and stops reading as a rail  |
| `corner`    | 12    | Roughly half the indent, which is what makes the turn read as a quarter-circle rather than a clipped corner |
| `maxIndent` | 4     | Past this, replies keep threading but stop marching right, or a long argument runs off the screen |

**Three separate problems, three separate places:**

1. *Which rows exist, and in what order* — `buildThreadLayout`
   (`lib/features/news/thread_model.dart`). A pure function over the flat
   reply list. It also decides, per row, whether anything is threaded below it
   and whether each ancestor's rail passes it.
2. *Where the lines go* — `ThreadConnectorPlan.forRow`. Pure geometry: rail
   positions, the elbow, the parent rail's continuation.
3. *Painting* — `ThreadConnectorPainter`, which only draws the plan.

The split exists because connector bugs are silent. A rail running to the
wrong place lays out and paints without a single warning, so neither `analyze`
nor a render smoke test can see it; the only thing that catches it is asserting
on the numbers (`test/thread_model_test.dart`, `test/thread_layout_test.dart`).

The connectors are painted *behind* the row in a `Stack` rather than laid out
beside it, so an elbow can reach across the gutter into the avatar without any
widget needing to know the geometry.

**Nesting is unbounded.** Runs of more than three answers below the top level
are held back behind a "show replies" row — top-level comments never collapse,
since they are the conversation itself.

## 12. Reactions

One table (`news_reactions`) serves posts and replies; the pair
`(content_type, content_id)` is the key everywhere. `value` is `+1` or `-1`
rather than two boolean columns, which keeps "switch my reaction" a single
upsert and the score a plain `SUM`.

Counts render optimistically — `ReactionTally.toggled` produces exactly the row
the server will end up holding, and is rolled back if the write fails. A heart
that waits on a round trip feels broken. Realtime updates arrive over the
Supabase publication and are coalesced (350 ms), because a popular post would
otherwise refetch once per like.

`supabase/migrations/20260727000000_news_reactions.sql` must be applied before
the counts are anything but zero.

## 13. Sticky day headers

Activity groups transfers under pinned day headers. A bare pinned
`SliverPersistentHeader` pins to the top of the *whole* scroll view and stays
there for the rest of the list, so every later date piles up underneath it.
Wrapping each header with its own run in a `SliverMainAxisGroup` pins it only
within that run, so the next day displaces it — which is what a date-grouped
list is expected to do. Measured in `test/history_headers_test.dart`.

## 14. Back to top

`ScrollToTop` (`lib/core/ui/scroll_to_top.dart`) floats a pill once the reader
is more than ~1.5 screens down **and moving upward**. The direction condition
matters: someone still reading downward has not asked to leave, and covering
their content with a button while they read is the thing people complain about.
It rides on whatever scrollable it wraps via scroll notifications, so it needs
no controller plumbing at the call site.

## 15. Sharing a post

`PostShareCard` paints the card straight onto a canvas rather than
screenshotting the widget on screen. The screenshot approach fails three ways
here: the card in the feed is clipped by the viewport, it carries interactive
chrome that has no business in a shared image, and capturing a live
`RepaintBoundary` needs the widget mounted and painted — which it is not, when
the share is triggered from a menu that has already covered it. Painting it
explicitly also makes the whole thing a pure function of a `NewsPost`, so it is
tested without a screen.

The link goes in the share *text*, not in the picture: every share target
linkifies text and almost none read a URL out of an image. It points at
`AppConfig.appUrl` — the only Omnia address that resolves for someone who does
not have the wallet yet, which is exactly who a shared post reaches.

## 16. Reactions — how a tap is handled

The rule every social app converges on: **the finger drives the screen, the
network follows.**

1. A tap updates local state immediately and unconditionally.
2. The write is *coalesced* — ten rapid taps send one request carrying the
   final state, not ten racing each other.
3. At most one request per piece of content is outstanding; a tap arriving
   mid-flight is recorded and sent when that one settles.
4. A refetch never overwrites content the user is currently interacting with.

Rule 4 is the one that is easy to miss and it caused a real bug: `counts` and
`mine` are two requests, so a refetch whose `mine` was read *before* the
user's like landed and whose `counts` was read *after* arrives as "1 like, but
not yours". The next tap then adds a second like on top of one already made,
and the count briefly shows 2 before the following refetch corrects it. No
arithmetic inside `ReactionTally.toggled` can fix that — the stale read has to
not be applied at all.

A failed write is *not* rolled back to a remembered "before" value; after a
burst that value is itself stale. The intent is dropped and the server is
re-read.

Pinned in `test/reactions_notifier_test.dart`, which asserts the request
count, not just the final state.

## 17. Thread connectors, continued

Two rules the first implementation got wrong, both visible only on screen:

* **Top-level comments are separate conversations.** Passing "this ancestor
  has a later sibling" down from depth 0 drew a rail beside every nested
  reply that ran on into the *next unrelated comment*, stitching two of them
  together.
* **Past `maxIndent`, parent and child share a column.** An elbow there has no
  horizontal gap to cross, so it hooked out to the right and came back through
  the avatar. At the cap there is no elbow: the parent's own rail runs
  straight down into the child, which is what a depth cap should look like.

## 18. Link previews

Parsed with regular expressions over `<head>`, not an HTML parser. The only
things needed are four `<meta>` tags, and the parse stops at `</head>` — a
full DOM would be a large dependency for a decoration, and it would also
happily read an `og:title` out of body copy.

Only the *first* link in a post gets a card, and only when the post has no
picture of its own: two images in one post compete, and five links should be
read rather than turned into five cards. The card shows the **host**, which is
the one part of a preview a page cannot dress up about itself.

Nothing renders until the metadata resolves and proves useful — no skeleton.
A card appearing a beat later disrupts less than a placeholder holding space
for something that may never arrive.
