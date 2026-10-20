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
- **Database**: Supabase project `nhdfuarjvwoeghgyxtvw` (https://nhdfuarjvwoeghgyxtvw.supabase.co). Setup is `supabase/schema.sql`; Amanda runs it in the Supabase SQL Editor (it's safe to re-run). Guests only reach it through `guest_view`, `guest_rsvp` and `guest_ask` with their invite code; couples sign in and row-level security limits them to their own wedding. The publishable key in the code is meant to be public.
- **Design**: Figma file *Everyday enhancements module 3* (file key `GcfFAJunr96orm0j8ebEBn`), page **Site Map · Brand pass** (her current designs). Colors and spacing come from `design-tokens.json`. Headings: Alegreya Sans on the web; the app falls back to the system font until Elido is added. Brand assets: the script monogram plus sample photos (`Assets.xcassets/Brand`, `guest-site/images`).

## How the app syncs

- `Model/Supabase.swift`: sign-in (email + password, session in the Keychain) and REST calls. No packages.
- `Model/Sync.swift`: maps app data to tables. Upload the couple's rows, then download everything (that's how RSVPs and questions from the website arrive).
- `Model/AppStore.swift`: couple changes go through `coupleChange`, which saves on the phone and then syncs. Sync also runs when the app opens and on pull-to-refresh (Home, Guests).
- Demo and "set up on this phone only" weddings never sync. A phone-only wedding can go online via the profile menu → **Share with guests online**.

## Status (as of Oct 20, 2026)

Done and committed on `main` (Amanda may still need to push the last 2 commits):
- Brand pass from Figma (monogram, photos); event cover photos and a couple photo picked from the phone.
- Onboarding from Figma (O1–O6), with real account creation and sign-in.
- Guest website, connected to Supabase; RSVP tested end to end.
- Couple app connected to Supabase, with invite links to share from the Guests tab. **Not yet tested with a real account** (Claude can't sign up on her behalf); she was about to try it.

Supabase still emails a confirmation link on sign-up. She may turn off **Authentication → Sign In / Providers → Email → Confirm email** for easier demos.

## Next steps (in rough order)

1. Help her test: create an account in the app → add a guest and publish an event → open the guest's link → RSVP on the website → pull down on Home and see the RSVP. Fix whatever breaks.
2. Upload photos to Supabase Storage so event and couple photos show on the website (they're phone-only right now).
3. Registry: couples add, edit and delete gifts and cash funds; guests mark "I'll get this" on the website; who-gave-what for thank-you notes (Figma CR1–CR4, GD2).
4. Reminders on the phone (RSVP due, event starting soon).
5. Later: push notifications, the Elido font, TestFlight for real testers (needs the $99 Apple Developer Program).

## Running things

- **Build:** `xcodebuild -project Intertwine.xcodeproj -scheme Intertwine -destination 'generic/platform=iOS Simulator' build`
- **Website locally:** `python3 -m http.server 4173 --directory guest-site`, then open http://localhost:4173. Opening the file directly won't work.
- **Her iPhone:** the signing team is set and her Apple ID is in Xcode. Plug in and unlock the phone, then run it from Xcode. A free Apple ID build expires after 7 days.
