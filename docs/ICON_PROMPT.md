# App icon prompt

Use with an image generator (ChatGPT image, Midjourney, Ideogram, Firefly...).
Then export a square 1024x1024 PNG, save it as `Resources/AppIcon.png`, and run `./build.sh`.

## Main prompt

A modern macOS app icon, rounded square with soft gradient background from deep espresso brown to warm amber.
At the center, a minimal white porcelain espresso cup on a saucer, seen slightly from above, with three thin curved
lines of steam rising and the middle steam line shaped like a small glowing power symbol.
Clean flat vector style with subtle depth and a soft inner shadow, high contrast, simple shapes that stay readable at
small sizes. No text, no letters, no border, no photo realism. Centered composition with generous padding,
1024x1024, Apple Big Sur style icon.

## Variations to try

- Night version: dark navy gradient background, cup in cream white, steam as soft teal glow (fits the "stay awake" idea).
- Italian style: red and cream palette, moka pot instead of the cup.
- Ultra minimal: single line drawing of a cup with steam, white on solid dark brown.

## Menu bar icon

The menu bar icon is drawn in code in `Sources/MenuBarIcon.swift` (outline when off, filled with steam when on), so no extra asset is needed. It no longer uses the Apple symbol `cup.and.saucer`.

## Before you publish

Make sure the generator's terms allow commercial and open source use, and that the result does not look like an existing brand logo.
