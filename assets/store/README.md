# Play Store graphic assets

First-pass, brand-matched source art for the Google Play listing, in the
app's palette (blurple `#5865F2`, dark `#1E1F22`/`#2B2D31`, Inter). These are
**starting points** — refine freely, then export to the PNGs Play requires.

| Source | Export to | Play requirement |
|---|---|---|
| `feature-graphic.svg` | `feature-graphic.png` **1024×500** | Feature graphic (required) |
| `app-icon-512.svg` | `app-icon-512.png` **512×512**, 32-bit | Hi-res app icon (required) |

## Exporting SVG → PNG

Any of these produce a pixel-exact PNG:

```bash
# rsvg-convert (librsvg)
rsvg-convert -w 1024 -h 500 feature-graphic.svg -o feature-graphic.png
rsvg-convert -w 512  -h 512 app-icon-512.svg     -o app-icon-512.png

# or Inkscape
inkscape feature-graphic.svg -w 1024 -h 500 -o feature-graphic.png
inkscape app-icon-512.svg     -w 512  -h 512 -o app-icon-512.png
```

> **Font note:** the wordmark uses `Inter` (the app's font) with a sans-serif
> fallback. Export on a machine where Inter is installed — or open the SVG in
> a design tool and convert the text to outlines — so the PNG matches the app.

## Screenshots (also required: 2–8)

Grab from a device/emulator running a release build:

```bash
flutter run --release
# then use the device/emulator screenshot control on:
#   Home (balance), Send, History (finality states), Receive (QR)
```

See `../../docs/play-store-listing.md` for the full asset checklist and
listing copy.
