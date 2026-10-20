# Intertwine

**One wedding, in one place.** An iOS app that gives couples and their guests one shared place for every wedding event: where to be, what to wear, and who's coming.

Built with SwiftUI for Module 3 of *Everyday Enhancements* (MassArt), from the designs in Figma.

## Run it

1. You need a Mac with **Xcode 16 or newer**.
2. Open `Intertwine.xcodeproj`.
3. Pick an iPhone simulator (any iPhone running iOS 17 or later) and press **Run** (⌘R).

To run it on your own iPhone, select your phone as the run destination, then go to **Intertwine target → Signing & Capabilities** and pick your Apple ID under **Team**. A free Apple ID works.

## What works

On first launch, onboarding walks a couple through setting up their own wedding: welcome → choose your role → your names → wedding date, venue and guest count → invite guests (from contacts or one by one) → Home. There are no accounts yet, so everything stays on the phone, and choosing "I'm a guest" opens the sample wedding. **Try the demo** on the welcome screen loads Mia & Ryan's sample wedding as either side.

**Couple (Mia & Ryan)** has four tabs: Home, Events, Guests, Registry.
- Home shows a countdown, guest and RSVP totals, what needs your attention, and the next event.
- Creating an event takes 5 steps: basics → date & place → dress code & RSVP → guest preview → publish. You can save a draft at any step.
- Add a cover photo from your iPhone photos in the first step of an event. It shows on the event's cards and cover for both sides.
- Add a photo of the two of you with the photo button on the Home countdown tile (long-press the tile to remove it). Photos are saved on the phone only.
- See RSVPs per event, answer guest questions, add guests, and mark registry gifts as bought.

**Guest (Rosa)** has four tabs: Home, Schedule, What to Wear, Details.
- See the RSVPs you still owe, your schedule by date, and the dress code for every event.
- RSVP with a yes or no, how many people are coming, and a note. Then add the event to your calendar or get directions.
- Ask the couple a question. Their answer shows up under Details.

Both sides share the same data on the phone. An event the couple publishes appears in the guest's Schedule, and a guest's RSVP appears for the couple. Use the profile menu (top right on Home) to switch sides or reset the demo data. The app follows the phone's light or dark setting.

**Not built yet:** accounts and syncing between phones (including photos), linking an outside registry, and push notifications.

## Design system ↔ Figma

The colors, spacing, radii, and type in code come from the Figma variables and text styles (file: *Everyday enhancements module 3*, pages *Foundations* and *iOS Foundations*).

| Figma | Code |
|---|---|
| Color variables (Light + Dark modes) | `Assets.xcassets/Colors`, used through `Palette` in `DesignSystem/Tokens.swift`. Each color set is named after the variable's iOS code syntax, e.g. `color/bg/canvas` → `colorBgCanvas`. |
| Spacing & Radius variables | `Space` and `Radius` in `Tokens.swift` |
| Text styles | `Typo` in `Tokens.swift` |
| Components (Button, Text Field, Status Badge, List Row, Event Card, Step Progress, Sheet Footer) | `DesignSystem/Components.swift` |
| Brand pass: monogram, event and couple photos (page *Site Map · Brand pass*) | `Assets.xcassets/Brand`, used through `Brand`, `Monogram`, `MonogramCover` and `CountdownTile` in `DesignSystem/Brand.swift` |

To change a color, edit `design-tokens.json`, then run:

```
python3 scripts/generate_colors.py
```

### Using the Elido font

Headings ask for the brand font Elido and fall back to the system font until it's added. To add it:
1. Drag the Elido font files (`.otf` or `.ttf`) into the `Intertwine` folder in Xcode.
2. In the target's **Info** tab, add **Fonts provided by application** and list each file name.
3. In `Tokens.swift`, set `Typo.headingBold` and `Typo.headingMedium` to the fonts' PostScript names, which you can find in Font Book under ⓘ.

Check the font's license allows embedding it in an app.

## Project layout

```
Intertwine/
  App/            App entry, onboarding
  DesignSystem/   Tokens (colors, spacing, type) and reusable components
  Model/          Data types, AppStore (saves to the phone), sample data, date formatting
  Shared/         Views both sides use (event header, where, dress code, profile menu)
  Couple/         Couple tabs and the create-event flow
  Guest/          Guest tabs, RSVP, what to wear, details
design-tokens.json
scripts/generate_colors.py
```
