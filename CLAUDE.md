# Intertwine: notes for Claude

Read this first. It's written for a new chat picking up where the last one left off.

## About the person

Amanda is a design student (MassArt, *Everyday Enhancements*, Module 3). She designs in Figma and is new to coding, Git and terminals.
- Explain in plain, short steps. Give direct links and exact button names. One step at a time when she's stuck.
- She uses **GitHub Desktop** to push. The terminal here is not signed in to GitHub, so `git push` fails: commit locally, then ask her to click **Push origin** in GitHub Desktop (Current Branch: **main**).
- She may use the iOS Simulator at the same time. **Ask before tapping in the simulator.** (Once our taps collided and replaced a test wedding.)
- Ask before pushing, publishing, or anything with her accounts. Never ask her for passwords, the Supabase secret key or the database password.

## What Intertwine is

One wedding, in one place. **The couple side is an iPhone app; the guest side is a website.** Guests open a personal invite link; no app or account needed.

- **iOS app** (SwiftUI, `Intertwine.xcodeproj`, iOS 17+): onboarding, couple tabs (Home, Events, Guests, Registry), a guest preview, and a Mia & Ryan demo.
- **Guest website** (`guest-site/`, plain HTML/CSS/JS, no build step): Home, RSVP, Schedule, event pages, What to Wear, Details, Registry, Ask the couple. Live at **https://amhanssen.github.io/Intertwine/** (demo link: `?invite=demo-rosa`). Published by `.github/workflows/guest-site.yml` when `main` is pushed.
- **Database**: Supabase project `nhdfuarjvwoeghgyxtvw` (https://nhdfuarjvwoeghgyxtvw.supabase.co). Setup is `supabase/schema.sql`; Amanda runs it in the Supabase SQL Editor (it's safe to re-run). Guests only reach it through the `guest_` functions (`guest_view`, `guest_rsvp`, `guest_ask`, `guest_give`, `guest_ungive`) with their invite code; couples sign in and row-level security limits them to their own wedding. The publishable key in the code is meant to be public.
- **Design**: Figma file *Everyday enhancements module 3* (file key `GcfFAJunr96orm0j8ebEBn`), page **Site Map · Brand pass** (her current designs). Colors and spacing come from `design-tokens.json`. Headings: Alegreya Sans on the web; the app falls back to the system font until Elido is added. Brand assets: the script monogram plus sample photos (`Assets.xcassets/Brand`, `guest-site/images`).

## How the app syncs

- `Model/Supabase.swift`: sign-in (email + password, session in the Keychain) and REST calls. No packages.
- `Model/Sync.swift`: maps app data to tables. Upload the couple's rows, then download everything (that's how RSVPs and questions from the website arrive).
- `Model/AppStore.swift`: couple changes go through `coupleChange`, which saves on the phone and then syncs. Sync also runs when the app opens and on pull-to-refresh (Home, Guests).
- Photos: picked photos are uploaded once to the public Storage bucket `photos` (folder = wedding id) and their address is saved in `photo_url`; the website shows them from there.
- Registry: `registry_items` (a fund's `price` is its goal), `registry_gifts` (who gave what; guests add them on the website, the couple ticks thank-yous), `registry_links` (other stores). App screens in `Couple/Registry.swift` (CR1–CR4).
- `Model/Reminders.swift`: phone reminders the day before RSVPs are due and 2 hours before each event. iOS asks permission the first time an event is published.
- Demo and "set up on this phone only" weddings never sync. A phone-only wedding can go online via the profile menu → **Share with guests online**.

## Status (as of Oct 20, 2026)

Done and committed on `main`:
- Brand pass, onboarding (O1–O6), guest website and couple app, all connected to Supabase.
- Photos on the website, the full registry (app CR1–CR4, website GD2 with "I'll get this" and cash funds), reminders, add-to-calendar (file + Google), Apple/Google Maps, link previews (`guest-site/images/share.jpg`).

**Amanda must re-run `supabase/schema.sql`** for photos and the registry to work online (the website copes until then). The couple app is **not yet tested with a real account**.

Supabase still emails a confirmation link on sign-up. She may turn off **Authentication → Sign In / Providers → Email → Confirm email** for easier demos.

## Next steps (in rough order)

1. Help her test: create an account in the app → add a guest, a gift and a photo, publish an event → open the guest's link → RSVP and "I'll get this" on the website → pull down on Home / Registry and see them. Fix whatever breaks.
2. Show photos picked on another phone in the app (`remotePhotoURL` is stored but not displayed yet).
3. Later: push notifications, the Elido font, TestFlight for real testers (needs the $99 Apple Developer Program).

## Running things

- **Build:** `xcodebuild -project Intertwine.xcodeproj -scheme Intertwine -destination 'generic/platform=iOS Simulator' build`
- **Website locally:** `python3 -m http.server 4173 --directory guest-site`, then open http://localhost:4173. Opening the file directly won't work. (The browser pane's `preview_start` can't read ~/Documents; run the server from Bash and open the URL.)
- **Her iPhone:** the signing team is set and her Apple ID is in Xcode. Plug in and unlock the phone, then run it from Xcode. A free Apple ID build expires after 7 days.
