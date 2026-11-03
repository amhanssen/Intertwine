# Intertwine guest site

The guest side of Intertwine as a website, so guests don't need to install an app.

`couple.html` is the couple side as a website too, for couples without the iPhone app. They sign in with the same account, and the app and site share one wedding: Home, Events (add, edit, publish), Guests (invite links), Registry (gifts, funds, thank-yous, other stores), guest questions and wedding details. It checks for new replies every 30 seconds.

Pages follow the Figma guest screens: Home (GH1), RSVP (GH2–GH3), Schedule and event (GS1–GS3), What to Wear (GW1), Details, Registry and Ask the couple (GD1–GD3). Colors, spacing and radii come from `../design-tokens.json`, and it follows the phone's light or dark setting. On a computer the tab bar becomes a top bar.

## Try it on your Mac

From the repository folder:

```
python3 -m http.server 4173 --directory guest-site
```

Then open http://localhost:4173. (Opening `index.html` straight from Finder won't work, because browsers block the scripts on files.)

## Data

Each guest's invite link (`?invite=…`) loads their wedding from Supabase through the `guest_` functions. `?invite=demo-rosa` shows Mia & Ryan's sample wedding as their guest Rosa. The couple pages read and change the tables directly after sign-in; row-level security keeps each couple to their own wedding.

## Publishing

`.github/workflows/guest-site.yml` publishes this folder to GitHub Pages when it changes on `main`. Turn it on once under **Settings → Pages → Source: GitHub Actions**. The site will be at https://amhanssen.github.io/Intertwine/.

## Files

```
index.html   Page shell and tab bar
styles.css   Design tokens and components
app.js       Pages and navigation
data.js      Wedding data for guests
couple.html  The couple's pages (sign in at /couple.html)
couple.js    Couple pages and navigation
couple-data.js  Couple sign-in and wedding data
images/      Monogram and sample event photos
```
