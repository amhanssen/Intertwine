# Intertwine guest site

The guest side of Intertwine as a website, so guests don't need to install an app. The couple side stays an iPhone app.

Pages follow the Figma guest screens: Home (GH1), RSVP (GH2–GH3), Schedule and event (GS1–GS3), What to Wear (GW1), Details, Registry and Ask the couple (GD1–GD3). Colors, spacing and radii come from `../design-tokens.json`, and it follows the phone's light or dark setting. On a computer the tab bar becomes a top bar.

## Try it on your Mac

From the repository folder:

```
python3 -m http.server 4173 --directory guest-site
```

Then open http://localhost:4173. (Opening `index.html` straight from Finder won't work, because browsers block the scripts on files.)

## Right now

It shows Mia & Ryan's sample wedding as their guest Rosa. RSVPs and questions are saved in that browser only, and "Reset sample replies" under Details clears them.

## Next: real data

When the shared database (Supabase) is set up, only `data.js` changes. The pages keep calling the same functions (`data.events()`, `data.sendRSVP()` and so on), and each guest's invite link picks their wedding and name.

## Publishing

`.github/workflows/guest-site.yml` publishes this folder to GitHub Pages when it changes on `main`. Turn it on once under **Settings → Pages → Source: GitHub Actions**. The site will be at https://amhanssen.github.io/Intertwine/.

## Files

```
index.html   Page shell and tab bar
styles.css   Design tokens and components
app.js       Pages and navigation
data.js      Wedding data (sample now, Supabase later)
images/      Monogram and sample event photos
```
