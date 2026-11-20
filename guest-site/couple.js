// Intertwine for couples: the couple side of the app as a website, so couples can plan
// from any phone or computer without installing the app. Same account, same wedding.
// Pages follow the app's couple tabs (Home, Events, Guests, Registry), plus Planning
// (to-dos and vendors), which is only on the website for now. Each page is a
// function that returns HTML; the address after "#" picks the page.

import { data, state, inviteLink, SignedOut } from "./couple-data.js?v=18";

const main = document.querySelector("main");

// ---------- Formatting (matches Format.swift in the app) ----------

const toDate = (day, time = "12:00") => new Date(`${day}T${time.slice(0, 5)}:00`);
const fmt = (day, options) => new Intl.DateTimeFormat("en-US", options).format(toDate(day));
const dayShort = (day) => fmt(day, { weekday: "short", month: "short", day: "numeric" });
const dayLong = (day) => fmt(day, { weekday: "short", month: "short", day: "numeric", year: "numeric" });
const stamp = (iso) => new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric" }).format(new Date(iso));

function clock(t) {
  const [h, m] = t.split(":").map(Number);
  return `${h % 12 || 12}${m ? `:${String(m).padStart(2, "0")}` : ""} ${h < 12 ? "AM" : "PM"}`;
}

/** "Sat, Nov 14 · 7 PM – 10 PM", or what's known so far. */
function when(e) {
  if (!e.day) return "Date to be set";
  if (!e.start_time) return dayShort(e.day);
  return `${dayShort(e.day)} · ${clock(e.start_time)}${e.end_time ? ` – ${clock(e.end_time)}` : ""}`;
}

const noun = (count, one, many = `${one}s`) => (count === 1 ? one : many);
const count = (n, one, many) => `${n} ${noun(n, one, many)}`;
const money = (n) => `$${Number(n).toLocaleString("en-US")}`;

/** Escapes typed text before it goes into the page. */
const esc = (text) =>
  String(text ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

const daysUntil = (day) => {
  const today = new Date();
  today.setHours(12, 0, 0, 0);
  return Math.round((toDate(day) - today) / 86_400_000);
};

// ---------- Icons ----------

const icon = (path, size = 24) =>
  `<svg class="icon" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${path}</svg>`;

const icons = {
  calendar: '<rect x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
  gift: '<rect x="3.5" y="8" width="17" height="4" rx="1"/><path d="M5 12v8h14v-8M12 8v12"/><path d="M12 8C10.5 4.5 7 4.5 7 6.5S10 8 12 8c2 0 5 .5 5-1.5S13.5 4.5 12 8Z"/>',
  fund: '<rect x="3" y="6.5" width="18" height="11" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M6.5 9.5v5M17.5 9.5v5"/>',
  chat: '<path d="M4 5.5h16v10H9l-4 3.5v-3.5H4z"/>',
  person: '<circle cx="12" cy="8.5" r="3.5"/><path d="M5 20c.7-3.8 3.4-6 7-6s6.3 2.2 7 6"/>',
  chevron: '<path d="m9 6 6 6-6 6"/>',
  back: '<path d="m15 6-6 6 6 6"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m13.5 6.5 4 4"/>',
  link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
  rings: '<circle cx="9" cy="13" r="5"/><circle cx="15" cy="13" r="5"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  close: '<path d="M6 6l12 12M18 6 6 18"/>',
  camera: '<path d="M4 8h3l1.5-2.5h7L17 8h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>',
  checklist: '<rect x="5" y="4.5" width="14" height="16" rx="2.5"/><path d="M9 3h6v3H9z"/><path d="m9 13 2 2 4-4.5"/>',
  phone: '<path d="M5 4.5h3.5l1.5 4-2 1.5a11 11 0 0 0 6 6l1.5-2 4 1.5V19a1.5 1.5 0 0 1-1.5 1.5A15.5 15.5 0 0 1 3.5 6 1.5 1.5 0 0 1 5 4.5Z"/>',
  mail: '<rect x="3.5" y="5.5" width="17" height="13" rx="2"/><path d="m4 7 8 6 8-6"/>',
  text: '<path d="M4 5.5h16v10H9l-4 3.5v-3.5H4z"/><path d="M8 10.5h8"/>',
  sparkle: '<path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M6 18l2.5-2.5M15.5 8.5 18 6"/>',
};

const chevron = `<span class="chevron">${icon(icons.chevron, 18)}</span>`;

function row({ href, title, subtitle, iconPath, trailing = chevron }) {
  return `
    <a class="row" href="${href}">
      ${iconPath ? icon(iconPath) : ""}
      <span class="text"><span class="headline">${title}</span>${subtitle ? `<span class="subheadline secondary">${subtitle}</span>` : ""}</span>
      ${trailing}
    </a>`;
}

const back = (href, label) => `<a class="back" href="${href}">${icon(icons.back, 20)}${label}</a>`;

const header = (title, subtitle, action = "") => `
  <header class="screen-header">
    <div class="stack"><h1 class="large-title">${title}</h1>${subtitle ? `<p class="subheadline secondary">${subtitle}</p>` : ""}</div>
    ${action}
  </header>`;

const statusBadge = (e) => e.status === "published"
  ? '<span class="badge attending">Published</span>'
  : '<span class="badge info">Draft</span>';

function rsvpLine(e) {
  if (!e.rsvp_required) return "No RSVP needed";
  const c = data.rsvpCounts(e.id);
  return `${c.attending} attending · ${c.declined} can’t go · ${c.pending} waiting`;
}

const eventTypes = ["Welcome Party", "Rehearsal Dinner", "Ceremony & Reception", "Engagement Party",
  "Bridal Shower", "Bachelor/ette Party", "Farewell Brunch", "Other"];
// Common wedding events the couple can start from (step 1 of a new event). Tapping one fills
// in the type, name, welcome message, dress code and RSVP; they can change any of it.
const eventSuggestions = [
  { type: "Engagement Party", name: "Engagement Party", welcome: "Come celebrate with us! We can’t wait to toast to what’s ahead.", dress: "Cocktail attire", rsvp: true },
  { type: "Bridal Shower", name: "Bridal Shower", welcome: "Join us for brunch, games and a little pampering.", dress: "Garden party", rsvp: true },
  { type: "Bachelor/ette Party", name: "Bachelor/ette Party", welcome: "One last big night out before the wedding.", dress: "Casual", rsvp: true },
  { type: "Rehearsal Dinner", name: "Rehearsal Dinner", welcome: "Thank you for being part of our day. Join us for dinner after the rehearsal.", dress: "Smart casual", rsvp: true },
  { type: "Welcome Party", name: "Welcome Party", welcome: "Join us for drinks before the big day.", dress: "Cocktail attire", rsvp: true },
  { type: "Ceremony & Reception", name: "Ceremony & Reception", welcome: "We can’t wait to celebrate with you.", dress: "Formal", rsvp: true },
  { type: "Other", name: "After Party", welcome: "The night isn’t over yet! Keep dancing with us.", dress: "Cocktail attire", rsvp: false },
  { type: "Farewell Brunch", name: "Farewell Brunch", welcome: "One more morning together before everyone heads home.", dress: "Casual", rsvp: false },
];

/** Suggestions for events the couple hasn't added yet. */
function suggestionsHTML() {
  const have = new Set(state.events.map((e) => (e.name ?? "").trim().toLowerCase()));
  const left = eventSuggestions.map((s, i) => ({ ...s, i })).filter((s) => !have.has(s.name.toLowerCase()));
  if (!left.length) return "";
  return `
    <div class="field">
      <span class="label">Suggestions</span>
      <div class="suggestions">
        ${left.map((s) => `<button type="button" class="suggestion" data-action="suggest" data-i="${s.i}" aria-pressed="false">${esc(s.name)}</button>`).join("")}
      </div>
      <span class="helper">Tap one to fill in the details. You can change anything.</span>
    </div>`;
}

const dressCodes = ["Casual", "Smart casual", "Garden party", "Cocktail attire", "Formal",
  "Black tie optional", "Black tie"];
// Sample photos for events that don't have their own yet (same as the app).
const samplePhotos = {
  "Engagement Party": "EventEngagementParty", "Bridal Shower": "EventBridalShower",
  "Rehearsal Dinner": "EventRehearsalDinner", "Welcome Party": "EventWelcomeParty",
  "Ceremony & Reception": "EventWeddingDay",
};
const photoFor = (e) => e.photo_url || (samplePhotos[e.type] ? `images/${samplePhotos[e.type]}.jpg` : null);

const options = (list, selected) =>
  list.map((v) => `<option ${v === selected ? "selected" : ""}>${esc(v)}</option>`).join("");

const field = (id, label, input, helper = "") => `
  <div class="field">
    <label for="${id}">${label}</label>
    ${input}
    ${helper ? `<span class="helper">${helper}</span>` : ""}
  </div>`;

// Phones that let a website open the contact list (Chrome on Android; iPhone once its setting is on).
const canPickContacts = "contacts" in navigator && "select" in navigator.contacts;
const isIPhone = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.maxTouchPoints > 1 && /Macintosh/.test(navigator.userAgent));
const isMac = !isIPhone && /Macintosh/.test(navigator.userAgent);

/**
 * A photo address can end in #pos=X,Y: where to centre the photo (in %) when it's cropped.
 * The couple sets it with "Move photo" on Home. The app ignores the end of the address.
 */
function photoParts(url) {
  const [src, hash = ""] = String(url ?? "").split("#");
  const m = hash.match(/pos=(\d+(?:\.\d+)?),(\d+(?:\.\d+)?)/);
  return { src, x: m ? Number(m[1]) : 50, y: m ? Number(m[2]) : 30, pos: m ? `${m[1]}% ${m[2]}%` : "50% 30%" };
}

/** Help under the buttons, written for the device the couple is on. */
function contactsHelp() {
  const steps = canPickContacts ? `
      <p class="footnote secondary">Tap <b>Choose from contacts</b> and tick the people you’re inviting. Nothing else is shared.</p>`
    : isIPhone ? `
      <p class="footnote secondary"><b>Easiest:</b> tap <b>Paste a list</b> and type or paste names from Notes, a group text or a spreadsheet.</p>
      <p class="footnote secondary"><b>From the Contacts app:</b> open Contacts, tap <b>Lists</b> at the top left, press and hold a list (like <b>All iCloud</b>), tap <b>Export</b>, then <b>Save to Files</b>. Come back, tap <b>Import a contacts file</b> and pick the file you saved.</p>`
    : isMac ? `
      <p class="footnote secondary"><b>Easiest:</b> click <b>Paste a list</b> and paste names from Notes, Numbers, Excel or an email.</p>
      <p class="footnote secondary"><b>From the Contacts app:</b> select the people, choose <b>File → Export → Export vCard</b>, then drag the file onto this box (or click <b>Import a contacts file</b>).</p>
      <p class="footnote secondary"><b>From Google Contacts:</b> open contacts.google.com, tick people, then <b>Export → vCard</b>.</p>`
    : `
      <p class="footnote secondary"><b>Easiest:</b> click <b>Paste a list</b> and paste names from a spreadsheet or an email.</p>
      <p class="footnote secondary"><b>From Google Contacts:</b> open contacts.google.com, tick people, then <b>Export → vCard</b>, and drag the file onto this box.</p>`;
  return `
    <details class="how">
      <summary class="footnote secondary">How do I add lots of guests at once?</summary>
      ${steps}
    </details>`;
}

/**
 * Guests from pasted or typed text: one per line, or separated by commas. Copes with lists
 * from Notes (bullets, numbers, ticks), spreadsheets (first and last name in two columns, a
 * header row) and email ("Rosa Diaz <rosa@…>"). "+1", "and guest" or "Jess & Marcus" makes
 * a party of 2; "(4)" or "x4" at the end sets the party size.
 */
function listGuests(textValue) {
  let lines = textValue.split(/\r?\n/);
  if (lines.filter((l) => l.trim()).length === 1 && !/\t/.test(textValue)) lines = textValue.split(/[,;]/);
  const nameish = (c) => !!c && /^[\p{L}'’.-]+$/u.test(c);
  const out = [];
  for (let line of lines) {
    const cells = line.split("\t").map((c) => c.trim()).filter(Boolean);
    if (/^((first|full|last)\s*)?name|^guests?\b|^given/i.test(cells[0] ?? "")) continue; // a header row
    // Two short columns from a spreadsheet: first name, last name (then maybe a party size).
    if (cells.length >= 2 && nameish(cells[0]) && nameish(cells[1])) {
      const rest = cells.slice(2).join(" ");
      line = `${cells[0]} ${cells[1]}` + (/^\d{1,2}$/.test(rest) ? ` (${rest})` : /\+\s*\d/.test(rest) ? ` ${rest}` : "");
    } else if (cells.length >= 2 && /^\d{1,2}$/.test(cells[1])) line = `${cells[0]} (${cells[1]})`;
    else line = cells[0] ?? "";
    let party = 1;
    line = line
      .replace(/<[^>]*>|\S+@\S+|\+?\(?\d[\d\s().-]{7,}\d/g, " ")          // emails and phone numbers
      .replace(/^\s*(?:[-*•·◦▪☐☑✓✔]|\[[ x]?\]|\d+[.)])\s*/i, "");     // bullets, ticks and numbering
    const plus = line.match(/\+\s*(\d+)|\s(?:and|&|\+)\s*(?:a\s+)?guest\b/i);
    if (plus) { party += Number(plus[1] ?? 1); line = line.replace(plus[0], " "); }
    const size = line.match(/\((\d{1,2})\)\s*$|\s[x×]\s?(\d{1,2})\s*$/i);
    if (size) { party = Number(size[1] ?? size[2]); line = line.replace(size[0], " "); }
    else if (party === 1 && /\s(?:&|and)\s/i.test(line)) party = 2;
    const name = line.replace(/\s+/g, " ").replace(/^[\s,;:-]+|[\s,;:-]+$/g, "");
    if (name && /\p{L}/u.test(name)) out.push({ name, party: Math.min(Math.max(party, 1), 10) });
  }
  return out;
}

/** The checklist shown after importing contacts: everyone ticked, people already invited greyed out. */
function pickList(people) {
  const taken = new Set(state.guests.map((g) => g.name.toLowerCase()));
  const seen = new Set();
  const list = [];
  for (const person of people) {
    const { name, party = 1 } = typeof person === "string" ? { name: person } : person;
    const key = name.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    list.push({ name, party, already: taken.has(key) });
  }
  const fresh = list.filter((x) => !x.already).length;
  return `
    <form class="stack-sm" id="bulk-form">
      <div class="pick-top">
        <span class="headline">Who are you inviting?</span>
        ${fresh ? '<button class="link-button" type="button" data-action="pick-all">Untick all</button>' : ""}
      </div>
      <div class="pick-list">
        ${list.map((x) => `
          <label class="check">
            <input type="checkbox" name="pick" value="${esc(x.name)}" data-party="${x.party}" ${x.already ? "disabled" : "checked"}>
            <span>${esc(x.name)}${x.already ? ' <span class="footnote secondary">· already on your list</span>'
              : x.party > 1 ? ` <span class="footnote secondary">· party of ${x.party}</span>` : ""}</span>
          </label>`).join("")}
      </div>
      <button class="button primary" type="submit">${addLabel(fresh)}</button>
      <button class="button tertiary" type="button" data-action="bulk-cancel">Cancel</button>
    </form>`;
}

/** Keeps the checklist's button count and "Tick all / Untick all" in step with the boxes. */
function updatePick() {
  const boxes = [...main.querySelectorAll('input[name="pick"]:not(:disabled)')];
  const ticked = boxes.filter((b) => b.checked).length;
  const submit = main.querySelector('#bulk-form button[type="submit"]');
  submit.textContent = addLabel(ticked);
  submit.disabled = !ticked;
  const all = main.querySelector('[data-action="pick-all"]');
  if (all) all.textContent = ticked ? "Untick all" : "Tick all";
}

const addLabel = (n) => n ? `Add ${count(n, "guest")}` : "Tick at least one person";

const pasteHelp = "One guest per line. Copy them from Notes, a spreadsheet, a group text or an email. Add “+1” for a guest who’s bringing someone.";

/** The box for typing or pasting names. */
const pasteForm = () => `
  <form class="stack-sm" id="paste-form">
    <div class="pick-top">
      <label class="headline" for="bulk-names">Type or paste names</label>
      ${navigator.clipboard?.readText ? '<button class="link-button" type="button" data-action="paste-names">Paste</button>' : ""}
    </div>
    <textarea id="bulk-names" name="names" rows="7" placeholder="Jessica Avery\nMarcus Lee +1\nThe Diaz family (4)"></textarea>
    <span class="helper" id="paste-count">${pasteHelp}</span>
    <button class="button primary" type="submit">Next</button>
    <button class="button tertiary" type="button" data-action="bulk-cancel">Cancel</button>
  </form>`;

// ---------- Signed out ----------

const pagesSignedOut = {
  signin: () => authPage("signin"),
  signup: () => authPage("signup"),
  forgot: () => `
    ${back("#/signin", "Sign in")}
    <header class="stack">
      <h1 class="title1">Reset your password</h1>
      <p class="secondary">Enter the email you signed up with. We’ll send you a link to choose a new password.</p>
    </header>
    <form class="stack-lg" id="forgot-form">
      ${field("email", "Email", '<input id="email" name="email" type="email" autocomplete="email" placeholder="you@email.com" required>')}
      <button class="button primary" type="submit">Send reset link</button>
    </form>`,
};

function newPasswordPage() {
  return `
    <header class="stack">
      <h1 class="title1">Choose a new password</h1>
      <p class="secondary">For ${esc(data.email())}. Use it to sign in here and in the app.</p>
    </header>
    <form class="stack-lg" id="password-form">
      ${field("password", "New password", '<input id="password" name="password" type="password" minlength="8" autocomplete="new-password" required>', "At least 8 characters.")}
      <button class="button primary" type="submit">Save password</button>
    </form>`;
}

function authPage(mode) {
  const signingUp = mode === "signup";
  return `
    <span class="mono hero-mono" aria-hidden="true"></span>
    <header class="stack center">
      <h1 class="title1">${signingUp ? "Create your account" : "Sign in to Intertwine"}</h1>
      <p class="secondary">${signingUp
        ? "Plan every wedding event with your guests, in one shared place."
        : "Use the same email and password as the Intertwine app."}</p>
    </header>
    <form class="stack-lg" id="auth-form" data-mode="${mode}">
      ${field("email", "Email", '<input id="email" name="email" type="email" autocomplete="email" placeholder="you@email.com" required>')}
      ${field("password", "Password", `<input id="password" name="password" type="password" minlength="8" autocomplete="${signingUp ? "new-password" : "current-password"}" required>`,
        signingUp ? "At least 8 characters." : "")}
      <button class="button primary" type="submit">${signingUp ? "Create account" : "Sign in"}</button>
    </form>
    ${signingUp ? "" : '<a class="link-button" href="#/forgot">Forgot password?</a>'}
    <a class="link-button" href="${signingUp ? "#/signin" : "#/signup"}">${signingUp ? "I already have an account" : "New here? Create an account"}</a>
    <p class="footnote tertiary center">Guests don’t need an account. They open the personal link you send them.</p>`;
}

function setupPage() {
  return `
    <span class="mono hero-mono" aria-hidden="true"></span>
    <header class="stack center">
      <h1 class="title1">Tell us about your wedding</h1>
      <p class="secondary">You can change all of this later.</p>
    </header>
    <form class="stack-lg" id="setup-form">
      ${field("names", "Your names", '<input id="names" name="names" placeholder="Partner 1 & Partner 2" required>')}
      ${field("date", "Wedding date", '<input id="date" name="date" type="date" required>')}
      ${field("venue", "Venue (optional)", '<input id="venue" name="venue" placeholder="Name of your venue">')}
      <button class="button primary" type="submit">Continue</button>
    </form>
    <button class="link-button" type="button" data-action="sign-out">Sign out</button>`;
}

// ---------- Contacts import ----------

/** Opens the phone's own contact list (Contact Picker). Nothing is shared until people are picked. */
async function pickContacts() {
  const bulk = main.querySelector("#bulk");
  const show = (html) => { bulk.innerHTML = html; bulk.scrollIntoView({ behavior: "smooth", block: "start" }); };
  const problem = (text) => show(`<p class="panel warning subheadline" role="alert">${text}</p>`);
  let picked;
  try {
    // Ask for email and phone too (when the phone offers them), so people saved without a name still show up.
    const offered = (await navigator.contacts.getProperties?.()) ?? ["name"];
    const wanted = ["name", "email", "tel"].filter((p) => offered.includes(p));
    picked = await navigator.contacts.select(wanted.length ? wanted : ["name"], { multiple: true });
  } catch (error) {
    console.warn("Contact picker:", error);
    return problem("Your contacts didn’t open. Reload this page and try again. If it still doesn’t work, tap <b>Paste a list</b> instead.");
  }
  if (!picked?.length) return; // closed without picking anyone
  const names = picked.map((c) => (c.name ?? []).map((n) => n?.trim()).find(Boolean) || c.email?.[0]?.trim() || c.tel?.[0]?.trim())
    .filter(Boolean);
  if (!names.length) return problem("Those contacts don’t have names saved, so there’s nothing to add. Try <b>Paste a list</b> and type their names.");
  show(pickList(names));
}

/** Reads a contacts file (vCard, CSV or a plain list of names) and shows the checklist. */
async function importFile(file) {
  const bulk = main.querySelector("#bulk");
  if (!bulk) return;
  const textFile = await file.text();
  const names = /BEGIN:VCARD/i.test(textFile) || /\.csv$/i.test(file.name) ? contactNames(textFile) : listGuests(textFile);
  bulk.innerHTML = names.length ? pickList(names)
    : '<p class="panel warning subheadline" role="alert">No names found in that file. Try <b>Paste a list</b> instead: copy the names and paste them in.</p>';
  bulk.scrollIntoView({ behavior: "smooth", block: "start" });
}

/** Names from a vCard (.vcf) or CSV file exported from Contacts, Google or Outlook. */
function contactNames(textFile) {
  return /BEGIN:VCARD/i.test(textFile) ? vcardNames(textFile) : csvNames(textFile);
}

function vcardNames(textFile) {
  const unescape = (v) => v.replace(/\\([,;\\])/g, "$1").replace(/\\n/gi, " ").trim();
  const lines = textFile.replace(/\r?\n[ \t]/g, "").split(/\r?\n/); // unfold wrapped lines
  const names = [];
  let full = "", parts = "";
  for (const line of lines) {
    const [key, ...rest] = line.split(":");
    const value = rest.join(":");
    const prop = key.split(";")[0].toUpperCase().replace(/^ITEM\d+\./, "");
    if (prop === "BEGIN") { full = ""; parts = ""; }
    if (prop === "FN") full = unescape(value);
    if (prop === "N") {
      const [last = "", first = ""] = value.split(/(?<!\\);/).map(unescape);
      parts = [first, last].filter(Boolean).join(" ");
    }
    if (prop === "END" && (full || parts)) names.push(full || parts);
  }
  return names;
}

function csvNames(textFile) {
  const rows = parseCSV(textFile).filter((r) => r.some((c) => c.trim()));
  if (!rows.length) return [];
  const header = rows[0].map((h) => h.trim().toLowerCase());
  const col = (...names) => header.findIndex((h) => names.includes(h));
  const full = col("name", "full name", "display name");
  const first = col("first name", "given name");
  const last = col("last name", "family name");
  if (full < 0 && first < 0) return rows.map((r) => r[0].trim()).filter(Boolean); // a plain list of names
  return rows.slice(1).map((r) => {
    const joined = [r[first], r[last]].filter((v) => v?.trim()).map((v) => v.trim()).join(" ");
    return (full >= 0 && r[full]?.trim()) || joined;
  }).filter(Boolean);
}

/** A small CSV reader that handles quoted cells with commas and line breaks. */
function parseCSV(textFile) {
  const rows = [[]];
  let cell = "", quoted = false;
  for (let i = 0; i < textFile.length; i++) {
    const c = textFile[i];
    if (quoted) {
      if (c === '"' && textFile[i + 1] === '"') { cell += '"'; i++; }
      else if (c === '"') quoted = false;
      else cell += c;
    } else if (c === '"') quoted = true;
    else if (c === ",") { rows.at(-1).push(cell); cell = ""; }
    else if (c === "\n" || c === "\r") {
      if (c === "\r" && textFile[i + 1] === "\n") i++;
      rows.at(-1).push(cell); cell = ""; rows.push([]);
    } else cell += c;
  }
  rows.at(-1).push(cell);
  return rows;
}

// ---------- Create event steps (app: CreateEventFlow) ----------

const stepNames = ["Basics", "Date & place", "Dress code & RSVP", "Guest preview", "Publish"];
const stepTitles = ["Event basics", "Date & place", "Dress code & RSVP", "Preview your event", "Ready to publish?"];

const invitedHelper = (rsvp) => rsvp ? "RSVPs open when you publish" : "Guests will see the event without an RSVP button";

/** The event form as a table row (the photo is sent separately). */
function eventFields(form) {
  const fields = new FormData(form);
  const rsvp = fields.get("rsvp") === "yes";
  return {
    type: text(fields, "type"), name: text(fields, "name"), welcome_message: text(fields, "welcome"),
    day: optionalDate(fields, "day"), start_time: optionalDate(fields, "start"), end_time: optionalDate(fields, "end"),
    venue: text(fields, "venue"), directions: text(fields, "directions"),
    dress_code: text(fields, "dress"), dress_guidance: text(fields, "guidance"),
    rsvp_required: rsvp, rsvp_deadline: rsvp ? optionalDate(fields, "deadline") : null,
    // Only sent when it changed, so saving still works before the database has this column.
    ...(form.elements.board.value !== form.elements.board.defaultValue && { mood_link: boardLink(form.elements.board.value) }),
  };
}

/** The photo to preview: a newly picked one, the event's own, or the sample for its type. */
function previewPhoto(form) {
  const file = form.querySelector("#photo").files[0];
  if (file) {
    if (form.pickedFile !== file) {
      if (form.pickedURL) URL.revokeObjectURL(form.pickedURL);
      form.pickedFile = file;
      form.pickedURL = URL.createObjectURL(file);
    }
    return form.pickedURL;
  }
  return form.dataset.photo || photoFor({ type: form.querySelector("#type").value });
}

function stepButtons(step, published, complete) {
  if (step <= 3) return `
    <button class="button primary" type="button" data-action="step" data-to="next">${step === 3 ? "Preview as guest" : "Continue"}</button>
    ${published ? "" : '<button class="button tertiary" type="submit" value="draft">Save draft</button>'}`;
  if (step === 4) return `
    <button class="button primary" type="button" data-action="step" data-to="5">Looks good, continue</button>
    <button class="button tertiary" type="button" data-action="step" data-to="1">Edit event</button>`;
  return `
    <button class="button primary" type="submit" value="publish" ${complete ? "" : "disabled"}>${published ? "Save changes" : "Publish event"}</button>
    <button class="button tertiary" type="button" data-action="step" data-to="4">Back to preview</button>`;
}

/** Step 4: the event as a guest will see it (same layout as the guest website's event page). */
function previewHTML(e, photo) {
  return `
    <p class="panel accent subheadline">This is exactly what guests will see. RSVP is off while you preview.</p>
    <div class="stack-lg guest-preview">
      ${photo ? `<img class="cover" src="${esc(photo)}" alt="">` : ""}
      <header class="stack">
        <h2 class="title1">${esc(e.name)}</h2>
        <span class="headline secondary">${when(e)}</span>
        ${e.welcome_message ? `<p>${esc(e.welcome_message)}</p>` : ""}
      </header>
      ${e.rsvp_required ? `
        <section class="panel">
          <span class="title3">${e.rsvp_deadline ? `Please reply by ${dayShort(e.rsvp_deadline)}` : "Please reply"}</span>
          <p class="subheadline secondary">You’re invited · RSVP required</p>
          <button class="button primary" type="button" disabled>RSVP</button>
        </section>` : ""}
      <section class="panel">
        <h3 class="title3">Where</h3>
        <p>${esc(e.venue)}</p>
        ${e.directions ? `<p class="subheadline secondary">${esc(e.directions)}</p>` : ""}
      </section>
      <section class="panel">
        <h3 class="title3">What to wear</h3>
        <p>${esc(e.dress_code)}</p>
        ${e.dress_guidance ? `<p class="subheadline secondary">${esc(e.dress_guidance)}</p>` : ""}
        ${moodGrid(e.mood_photos)}
        ${boardButton(e.mood_link)}
      </section>
    </div>`;
}

const whoCanSee = (n) => n === 0 ? "Guests you add" : n === 1 ? "Your 1 invited guest" : `All ${n} invited guests`;

/** Step 5: one last look before publishing. */
function reviewHTML(e, published) {
  const missing = data.missing(e);
  const rsvp = !e.rsvp_required ? "No RSVP needed"
    : e.rsvp_deadline ? `Required · reply by ${dayShort(e.rsvp_deadline)}` : "Required";
  const line = (label, value) => `<div><dt class="footnote secondary">${label}</dt><dd>${value}</dd></div>`;
  return `
    <p class="subheadline secondary">${published ? "Guests will see these changes right away."
      : "Check the details once more. You can still edit the event after it’s live."}</p>
    <section class="panel">
      <h2 class="title3">${esc(e.name)}</h2>
      <dl class="info-lines">
        ${line("When", when(e))}
        ${line("Where", e.venue ? esc(e.venue) : "Venue to be set")}
        ${line("What to wear", esc(e.dress_code))}
        ${line("RSVP", rsvp)}
        ${line("Who can see it", whoCanSee(state.guests.length))}
      </dl>
    </section>
    ${missing.length ? `<p class="panel warning subheadline">Add the ${missing.join(", ")} before publishing.</p>` : ""}`;
}

/** What's missing on a step before the couple can move on (same rules as the app). */
function stepErrors(form, step) {
  const e = eventFields(form);
  const errors = {};
  if (step === 1 && !e.name) errors.name = "Add a name so guests know what this event is";
  if (step === 2) {
    if (!e.day) errors.day = "Add the date of the event";
    if (!e.start_time) errors.start = "Add a start time";
    if (!e.venue) errors.venue = "Add where the event is";
  }
  return errors;
}

function markErrors(form, errors) {
  form.querySelectorAll(".field-error").forEach((p) => p.remove());
  form.querySelectorAll("[aria-invalid]").forEach((input) => input.removeAttribute("aria-invalid"));
  for (const [id, message] of Object.entries(errors)) {
    const input = form.querySelector(`#${id}`);
    input.setAttribute("aria-invalid", "true");
    input.closest(".field").insertAdjacentHTML("beforeend", `<p class="field-error" role="alert">${message}</p>`);
  }
  const first = Object.keys(errors)[0];
  if (first) form.querySelector(`#${first}`).focus();
  return !first;
}

// ---------- Mood board ----------

const MOOD_MAX = 9;
// Photos picked for the mood board but not saved yet, by tile id.
const moodFiles = new Map();

function moodTile(src, attrs) {
  return `
    <div class="mood-tile" ${attrs}>
      <img src="${esc(src)}" alt="">
      <button type="button" data-action="mood-remove" aria-label="Remove photo">${icon(icons.close, 16)}</button>
    </div>`;
}

/** Ready-made mood boards (free Unsplash photos in images/moods, see CREDITS.md there). */
const moodStyles = { garden: "Garden party", blacktie: "Black tie", beach: "Beach", rustic: "Rustic barn", cocktail: "Cocktail" };
const moodStylePhotos = (key) => [1, 2, 3, 4, 5, 6].map((i) => new URL(`images/moods/${key}-${i}.jpg`, location.href).href);
const isStylePhoto = (url) => /\/images\/moods\//.test(url ?? "");

/**
 * "Not sure?" quiz: three tap-to-answer questions that point to one of the ready-made boards.
 * Each answer gives points to styles; the place counts most and settles a tie.
 */
const moodQuiz = [
  { q: "Where is it?", answers: [
    { a: "Garden or park", short: "garden", points: { garden: 2 } },
    { a: "Ballroom or hotel", short: "ballroom", points: { blacktie: 2 } },
    { a: "Beach or by the water", short: "beach", points: { beach: 2 } },
    { a: "Barn or farm", short: "barn", points: { rustic: 2 } },
    { a: "Rooftop, bar or restaurant", short: "rooftop", points: { cocktail: 2 } },
  ] },
  { q: "When is it?", answers: [
    { a: "Daytime", short: "daytime", points: { garden: 1, beach: 1, rustic: 1 } },
    { a: "Evening", short: "evening", points: { blacktie: 1, cocktail: 1 } },
  ] },
  { q: "How dressed up?", answers: [
    { a: "Relaxed", short: "relaxed", points: { beach: 1, rustic: 1 } },
    { a: "Dressy", short: "dressy", points: { garden: 1, cocktail: 1 } },
    { a: "Very formal", short: "very formal", points: { blacktie: 2 } },
  ] },
];

/** The best style for the answers (answer index per question). */
function quizResult(picks) {
  const score = Object.fromEntries(Object.keys(moodStyles).map((k) => [k, 0]));
  picks.forEach((i, q) => Object.entries(moodQuiz[q].answers[i].points).forEach(([k, n]) => { score[k] += n; }));
  const place = Object.keys(moodQuiz[0].answers[picks[0]].points)[0];
  return Object.keys(score).reduce((best, k) => (score[k] > score[best] ? k : best), place);
}

/** One step of the quiz: the next question, or the result once all three are answered. */
function quizHTML(picks) {
  const step = picks.length;
  if (step < moodQuiz.length) {
    const { q, answers } = moodQuiz[step];
    return `
      <p class="quiz-step">Question ${step + 1} of ${moodQuiz.length}</p>
      <p class="quiz-question" id="quiz-q">${q}</p>
      <div class="suggestions" role="group" aria-labelledby="quiz-q">
        ${answers.map(({ a }, i) => `<button class="suggestion" type="button" data-action="quiz-answer" data-i="${i}">${a}</button>`).join("")}
      </div>
      <div class="quiz-actions">
        ${step ? '<button class="link-button" type="button" data-action="quiz-back">Back</button>' : ""}
        <button class="link-button" type="button" data-action="quiz-close">Close</button>
      </div>`;
  }
  const key = quizResult(picks);
  const why = picks.map((i, q) => moodQuiz[q].answers[i].short);
  const sentence = why.join(" + ");
  return `
    <p class="quiz-step">Your style</p>
    <p class="quiz-question">${moodStyles[key]}</p>
    <p class="helper">${sentence[0].toUpperCase() + sentence.slice(1)} → ${moodStyles[key]}. You can still remove photos, add your own or pick another style.</p>
    <div class="mood-grid quiz-preview">${moodStylePhotos(key).slice(0, 3).map((u) => `<img src="${esc(u)}" alt="" loading="lazy">`).join("")}</div>
    <button class="button primary" type="button" data-action="quiz-use" data-style="${key}">Use this board</button>
    <div class="quiz-actions">
      <button class="link-button" type="button" data-action="quiz-open">Start over</button>
      <button class="link-button" type="button" data-action="quiz-close">Close</button>
    </div>`;
}

/** Shows the quiz at the given answers (or hides it with null). */
function showQuiz(form, picks) {
  const box = form.querySelector("#mood-quiz");
  box.hidden = !picks;
  form.querySelector(".quiz-open").setAttribute("aria-expanded", String(!!picks));
  if (!picks) { form.querySelector(".quiz-open").focus(); return; }
  box.dataset.picks = picks.join(",");
  box.innerHTML = quizHTML(picks);
  box.querySelector("button")?.focus();
}
const quizPicks = (form) => (form.querySelector("#mood-quiz").dataset.picks || "").split(",").filter(Boolean).map(Number);

/** The mood board editor in the event form's "What to wear" step. */
function moodField(urls) {
  moodFiles.clear();
  return `
    <div class="field">
      <span class="label">Mood board (optional)</span>
      <span class="helper">Start from a ready-made board, then remove or add photos.</span>
      <div class="suggestions" role="group" aria-label="Ready-made mood boards">
        ${Object.entries(moodStyles).map(([key, name]) => `<button class="suggestion" type="button" data-action="mood-style" data-style="${key}"
          aria-pressed="${urls.some((u) => u.includes(`/moods/${key}-`))}">${name}</button>`).join("")}
      </div>
      <button class="link-button quiz-open" type="button" data-action="quiz-open" aria-expanded="false" aria-controls="mood-quiz">Not sure? Take a 3-question quiz</button>
      <div class="mood-quiz" id="mood-quiz" hidden></div>
      <div class="mood-grid" id="mood-grid">
        ${urls.map((url) => moodTile(url, `data-url="${esc(url)}"`)).join("")}
        <label class="mood-add" for="mood-input" ${urls.length >= MOOD_MAX ? "hidden" : ""}>${icon(icons.plus, 24)}<span>Add photos</span></label>
      </div>
      <input id="mood-input" class="visually-hidden" type="file" accept="image/*" multiple>
      <span class="helper">Outfits, colors or a feeling. Guests see these with the dress code. Up to ${MOOD_MAX}.</span>
    </div>`;
}

/** A pasted board address, made into a full link. Copes with whatever Pinterest's Share
 *  button copies ("Check out this board… https://pin.it/abc"), a missing https://, and
 *  tracking bits on the end (?invite_code=…). */
function boardLink(value) {
  const v = value.trim();
  if (!v) return "";
  const found = v.match(/https?:\/\/\S+/i)?.[0] ?? v.match(/(?:[\w-]+\.)?(?:pinterest\.[a-z.]+|pin\.it)\/\S+/i)?.[0] ?? v;
  const url = /^https?:\/\//i.test(found) ? found : `https://${found}`;
  return /pinterest\./i.test(url) ? url.replace(/[?#].*$/, "") : url;
}

/** A full board address from a Pinterest username and board name ("Our Wedding" → our-wedding). */
function boardFromName(user, board) {
  const u = user.trim().replace(/^@/, "").replace(/^.*pinterest\.[a-z.]+\//i, "").replace(/\/.*$/, "");
  const b = board.trim().toLowerCase().replace(/['’]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
  return u && b ? `https://www.pinterest.com/${u}/${b}/` : "";
}

const isShortPin = (value) => /pin\.it/i.test(value);

/** The Pinterest board part of "What to wear": paste a link, or type username + board name. */
function boardField(link) {
  const canPaste = !!navigator.clipboard?.readText;
  return `
    <div class="field">
      <label for="board">Pinterest board (optional)</label>
      <div class="board-row">
        <input id="board" name="board" type="text" inputmode="url" autocomplete="off" autocapitalize="off" spellcheck="false"
          placeholder="Paste your board’s link" value="${esc(link)}">
        ${canPaste ? '<button class="button secondary" type="button" data-action="board-paste">Paste</button>' : ""}
      </div>
      <a class="helper link" id="board-check" href="${esc(boardLink(link))}" target="_blank" rel="noopener" ${link ? "" : "hidden"}>Open the link to check it’s your board ↗</a>
      <p class="panel subheadline" id="board-short" ${isShortPin(link) ? "" : "hidden"}>This link works: guests get a button that opens your board. To also show them a preview of the pins, fill in your username and board name below.</p>
      <details class="board-help" ${isShortPin(link) ? "open" : ""}>
        <summary>How do I find my board’s link?</summary>
        <div class="stack-sm subheadline">
          <p><strong>In the Pinterest app:</strong> open your board, tap the <strong>Share</strong> button (the arrow), then <strong>Copy link</strong>. Come back here and tap <strong>Paste</strong>.</p>
          <p><strong>On a computer:</strong> open your board on pinterest.com and copy the address from the top of the browser.</p>
          <p><strong>Or just type it:</strong> your username is on your Pinterest profile, under your name.</p>
          <div class="two-up">
            ${field("pin-user", "Username", '<input id="pin-user" type="text" autocomplete="off" autocapitalize="off" spellcheck="false" placeholder="e.g. miaandryan">')}
            ${field("pin-board", "Board name", '<input id="pin-board" type="text" autocomplete="off" placeholder="e.g. Our Wedding">')}
          </div>
        </div>
      </details>
    </div>`;
}

/** Keeps the check link and the short-link note in step with the board field. */
function boardChanged(form) {
  const value = form.elements.board.value;
  const check = form.querySelector("#board-check");
  check.hidden = !value.trim();
  check.href = boardLink(value);
  form.querySelector("#board-short").hidden = !isShortPin(value);
}

/** "See the Pinterest board" for a Pinterest link, otherwise "See more ideas". */
function boardButton(url) {
  if (!/^https?:\/\//i.test(url ?? "")) return "";
  const label = /pinterest\.|pin\.it/i.test(url) ? "See the Pinterest board" : "See more ideas";
  return `<a class="link-button" href="${esc(url)}" target="_blank" rel="noopener">${label}</a>`;
}

const moodTiles = (form) => [...form.querySelectorAll(".mood-tile")];
/** The board in order: saved photo addresses and newly picked files. */
const moodBoard = (form) => moodTiles(form).map((t) => t.dataset.url ?? moodFiles.get(t.dataset.new));
const moodPreview = (form) => moodTiles(form).map((t) => t.querySelector("img").src);

function updateMoodAdd(form) {
  form.querySelector(".mood-add").hidden = moodTiles(form).length >= MOOD_MAX;
}

/** Mood board photos as guests see them. */
function moodGrid(urls) {
  return urls?.length ? `<div class="mood-grid">${urls.map((u) => `<img src="${esc(u)}" alt="" loading="lazy">`).join("")}</div>` : "";
}

function showStep(form, step) {
  const published = form.dataset.published === "true";
  const e = eventFields(form);
  form.dataset.current = step;
  form.querySelectorAll("[data-step]").forEach((el) => { el.hidden = Number(el.dataset.step) !== step; });
  main.querySelectorAll("[data-when]").forEach((el) => { el.hidden = !el.dataset.when.split(" ").includes(String(step)); });
  const title = main.querySelector("#step-title");
  title.textContent = step === 5 && published ? "Save changes?" : stepTitles[step - 1];
  document.title = `${title.textContent} · Intertwine`;
  main.querySelector("#step-name").textContent = `Step ${step} of 5 · ${stepNames[step - 1]}`;
  main.querySelector("#step-bar").style.width = `${step * 20}%`;
  if (step === 4) form.querySelector("#preview").innerHTML = previewHTML({ ...e, mood_photos: moodPreview(form), mood_link: boardLink(form.elements.board.value) }, previewPhoto(form));
  if (step === 5) form.querySelector("#review").innerHTML = reviewHTML(e, published);
  form.querySelector("#step-buttons").innerHTML = stepButtons(step, published, !data.missing(e).length);
  form.querySelector(".form-error")?.remove();
  window.scrollTo(0, 0);
  title.setAttribute("tabindex", "-1");
  title.focus({ preventScroll: true });
}

function nextStep(form) {
  const step = Number(form.dataset.current);
  if (markErrors(form, stepErrors(form, step))) showStep(form, step + 1);
}

// ---------- Pages ----------

// ---------- Planning: to-dos and vendors ----------

const vendorTypes = ["Venue", "Photographer", "Videographer", "Caterer", "Florist", "Music / DJ", "Officiant",
  "Hair & makeup", "Cake & desserts", "Planner", "Rentals", "Transportation", "Attire", "Stationery", "Other"];

/** Common wedding to-dos and how many months before the wedding to do them. */
const starterTasks = [
  ["Set your budget", 12], ["Book the venue", 12], ["Book a photographer", 10], ["Book the caterer", 9],
  ["Choose an officiant", 9], ["Book the florist", 6], ["Find your wedding outfits", 6], ["Send save-the-dates", 6],
  ["Book hair & makeup", 4], ["Order the cake", 3], ["Send invite links to guests", 2], ["Get your marriage license", 1],
  ["Make the seating plan", 0.5], ["Confirm times with every vendor", 0.25],
];

/** The starter checklist, with due dates counted back from the wedding (none if already past). */
function starterList() {
  const wedding = toDate(state.wedding.date);
  return starterTasks.map(([title, months]) => {
    const due = new Date(wedding);
    if (months >= 1) due.setMonth(due.getMonth() - months);
    else due.setDate(due.getDate() - Math.round(months * 30));
    const day = `${due.getFullYear()}-${String(due.getMonth() + 1).padStart(2, "0")}-${String(due.getDate()).padStart(2, "0")}`;
    return { title, due: daysUntil(day) >= 0 ? day : null };
  });
}

const byDue = (a, b) => (a.due ?? "9999").localeCompare(b.due ?? "9999") || a.created_at.localeCompare(b.created_at);
const openTasks = () => state.tasks.filter((t) => !t.done).sort(byDue);
/** To-dos that are overdue or due in the next two weeks (shown on Home). */
const tasksDueSoon = () => openTasks().filter((t) => t.due && daysUntil(t.due) <= 14);

function dueText(day) {
  if (!day) return "";
  const days = daysUntil(day);
  if (days < 0) return `Overdue · was due ${dayShort(day)}`;
  if (days === 0) return "Due today";
  if (days === 1) return "Due tomorrow";
  return `Due ${dayShort(day)}`;
}

/** A select for linking a to-do or vendor to one event (or none). Empty when there are no events. */
function eventSelect(id, selected, label = "For which event (optional)") {
  if (!state.events.length) return "";
  return field(id, label, `<select id="${id}" name="event">
    <option value="">No event (the whole wedding)</option>
    ${state.events.map((e) => `<option value="${e.id}" ${e.id === selected ? "selected" : ""}>${esc(e.name)}</option>`).join("")}
  </select>`);
}

const eventName = (id) => (id ? data.event(id)?.name ?? "" : "");

/** A to-do with a checkbox. On Planning it also names its event; on the event page it doesn't need to. */
function taskRow(t, { showEvent = true } = {}) {
  const due = dueText(t.due);
  const linked = showEvent ? eventName(t.event_id) : "";
  const late = t.due && !t.done && daysUntil(t.due) < 0;
  return `
    <div class="row task${t.done ? " done" : ""}">
      <label class="check-row task-check">
        <input type="checkbox" data-action="task-done" data-id="${t.id}" ${t.done ? "checked" : ""} aria-label="${t.done ? "Mark not done" : "Mark done"}: ${esc(t.title)}">
        <span class="text"><span class="headline">${esc(t.title)}</span>${due || linked ? `<span class="subheadline ${late ? "late" : "secondary"}">${[due, linked && esc(linked)].filter(Boolean).join(" · ")}</span>` : ""}</span>
      </label>
      <button class="icon-button" type="button" data-action="delete-task" data-id="${t.id}" aria-label="Remove ${esc(t.title)}">${icon(icons.close, 18)}</button>
    </div>`;
}

const telHref = (phone) => `tel:${phone.replace(/[^\d+]/g, "")}`;
const webHref = (url) => (/^https?:\/\//i.test(url) ? url : `https://${url}`);

function vendorSubtitle(v, { showEvent = true } = {}) {
  return [v.category, showEvent && eventName(v.event_id), v.contact_name, v.phone].filter(Boolean).map(esc).join(" · ");
}

/** The event's vendors and to-dos (couple only), with a quick way to add more. */
function eventPlanning(e) {
  const vendors = data.eventVendors(e.id);
  const tasks = data.eventTasks(e.id).sort(byDue);
  const open = tasks.filter((t) => !t.done), done = tasks.length - open.length;
  return `
    <section class="stack">
      <h2 class="title3">Vendors &amp; to-dos</h2>
      <p class="subheadline secondary">Only the two of you see this. Everything here is also on <a href="#/planning">Planning</a>.</p>
      ${vendors.length ? `<div class="row-group">${vendors.map((v) => row({
        href: `#/vendor/${v.id}/${e.id}`, title: esc(v.name), subtitle: vendorSubtitle(v, { showEvent: false }), iconPath: icons.person,
      })).join("")}</div>` : ""}
      <a class="button secondary" href="#/vendor/new/${e.id}">${icon(icons.plus, 20)}Add a vendor for this event</a>
      ${open.length ? `<div class="row-group">${open.map((t) => taskRow(t, { showEvent: false })).join("")}</div>` : ""}
      ${done ? `<p class="footnote secondary">${count(done, "to-do")} done for this event.</p>` : ""}
      <form class="panel stack-sm" id="task-form" data-event="${e.id}">
        <div class="two-up wide-first">
          ${field("task-title", "New to-do for this event", '<input id="task-title" name="title" placeholder="Confirm the setup time" maxlength="300" required>')}
          ${field("task-due", "Due (optional)", '<input id="task-due" name="due" type="date">')}
        </div>
        <button class="button secondary" type="submit">${icon(icons.plus, 20)}Add to-do</button>
      </form>
    </section>`;
}

const pages = {
  // Home: the countdown, what needs attention and the next event (app: Home tab).
  home() {
    const w = state.wedding;
    const photo = photoParts(w.photo_url);
    const days = daysUntil(w.date);
    const published = state.events.filter((e) => e.status === "published");
    const replies = state.rsvps.filter((r) => published.some((e) => e.id === r.event_id)).length;
    const attention = [
      ...state.events.filter((e) => e.status === "draft").map((e) => {
        const missing = data.missing(e);
        return row({ href: `#/event/${e.id}`, title: `Finish ${esc(e.name)}`,
          subtitle: missing.length ? `Missing ${missing.join(", ")}` : "Ready to publish" });
      }),
      ...(data.unanswered().length ? [row({ href: "#/questions", title: count(data.unanswered().length, "guest question"),
        subtitle: "Answer so guests don’t have to text you" })] : []),
      ...(tasksDueSoon().length ? [row({ href: "#/planning", iconPath: icons.checklist,
        title: `${count(tasksDueSoon().length, "to-do")} due soon`,
        subtitle: tasksDueSoon().slice(0, 2).map((t) => esc(t.title)).join(", ") + (tasksDueSoon().length > 2 ? "…" : "") })] : []),
      ...(state.guests.length ? [] : [row({ href: "#/guests", title: "Add your guests", subtitle: "Each guest gets a personal invite link" })]),
      ...(state.events.length ? [] : [row({ href: "#/edit/new", title: "Add your first event", subtitle: "Welcome party, ceremony, brunch…" })]),
    ];
    const upcoming = published.filter((e) => e.day && daysUntil(e.day) >= 0)[0];
    return `
      <header class="screen-header">
        <div class="stack">
          <p class="subheadline secondary">${dayLong(w.date)}${w.venue ? ` · ${esc(w.venue)}` : ""}</p>
          <h1 class="large-title">${esc(w.couple_names)}</h1>
        </div>
        <a class="avatar" href="#/wedding" aria-label="Wedding details">${w.photo_url ? `<img src="${esc(photo.src)}" style="object-position:${photo.pos}" alt="">` : icon(icons.rings, 22)}</a>
      </header>
      <div class="stats">
        <div class="stat hero" ${w.photo_url ? `style="background-image:url('${esc(photo.src)}');background-position:${photo.pos}" data-x="${photo.x}" data-y="${photo.y}"` : ""}>
          <input id="hero-photo" class="visually-hidden" type="file" accept="image/*">
          <label class="hero-photo" for="hero-photo" title="${w.photo_url ? "Change photo" : "Add a photo"}">${icon(icons.camera, 20)}<span class="visually-hidden">${w.photo_url ? "Change photo" : "Add a photo"}</span></label>
          <span class="number">${Math.abs(days)}</span>
          <span class="subheadline">${days >= 0 ? `${noun(days, "day")} until “I do”` : `${noun(-days, "day")} since “I do”`}</span>
        </div>
        <a class="stat" href="#/guests"><span class="number">${state.guests.length}</span><span class="subheadline secondary">${noun(state.guests.length, "guest")} invited</span></a>
        <a class="stat" href="#/events"><span class="number">${replies}</span><span class="subheadline secondary">${noun(replies, "RSVP")} received</span></a>
      </div>
      ${upcoming ? `<section class="stack"><h2 class="title3">Your next event</h2>${nextEventCard(upcoming)}</section>` : ""}
      <section class="stack">
        <h2 class="title3">Needs your attention</h2>
        ${attention.length ? `<div class="row-group">${attention.join("")}</div>`
          : '<p class="panel subheadline secondary">You’re all caught up.</p>'}
      </section>
      ${thankYous()}
      ${otherStores()}
      <section class="stack">
        <h2 class="title3">More</h2>
        <div class="row-group">
          ${row({ href: "#/wedding", title: "Wedding details", subtitle: "Names, date, travel and your photo", iconPath: icons.rings })}
          ${row({ href: "#/questions", title: "Guest questions", subtitle: state.questions.length ? `${state.questions.length} asked · ${data.unanswered().length} to answer` : "Nothing asked yet", iconPath: icons.chat })}
        </div>
      </section>
      <p class="footnote tertiary center">Signed in as ${esc(data.email())}</p>
      <button class="button tertiary" type="button" data-action="sign-out">Sign out</button>`;
  },

  // Events (app: Events tab).
  events() {
    return `
      ${header("Events", state.events.length ? `${count(state.events.length, "event")} · ${state.events.filter((e) => e.status === "published").length} published` : "Every part of your wedding, in one place")}
      <a class="button primary" href="#/edit/new">Add an event</a>
      ${state.events.length ? `<div class="stack-sm">${state.events.map(eventCard).join("")}</div>`
        : '<p class="panel subheadline secondary">No events yet. Add your welcome party, ceremony, brunch and anything else guests should know about.</p>'}`;
  },

  // One event: its details and who's coming.
  event(id) {
    const e = data.event(id);
    if (!e) return notFound();
    const missing = data.missing(e);
    const photo = photoFor(e);
    const guestRows = state.guests.map((g) => {
      const r = data.reply(e.id, g.id);
      const badge = !r ? '<span class="badge reply">Waiting</span>'
        : r.attending ? `<span class="badge attending">Coming${r.party_count > 1 ? ` · ${r.party_count}` : ""}</span>`
          : '<span class="badge declined">Can’t go</span>';
      return `
        <a class="row" href="#/guest/${g.id}">
          <span class="text"><span class="headline">${esc(g.name)}</span>${r?.note ? `<span class="subheadline secondary">“${esc(r.note)}”</span>` : ""}</span>
          ${badge}
        </a>`;
    });
    return `
      ${back("#/events", "Events")}
      ${photo ? `<img class="cover" src="${esc(photo)}" alt="">` : ""}
      <header class="stack">
        <div>${statusBadge(e)}</div>
        <h1 class="title1">${esc(e.name)}</h1>
        <span class="headline secondary">${when(e)}</span>
        ${e.venue ? `<span class="subheadline secondary">${esc(e.venue)}</span>` : ""}
      </header>
      ${e.status === "draft"
        ? missing.length
          ? `<p class="panel warning subheadline">Add the ${missing.join(", ")} before guests can see this event.</p>`
          : '<button class="button primary" type="button" data-action="publish">Publish to guests</button>'
        : '<p class="panel accent subheadline">Guests can see this event on their invite.</p>'}
      <a class="button secondary" href="#/edit/${e.id}">${icon(icons.edit, 20)}Edit event</a>
      ${e.rsvp_required ? `
        <section class="stack">
          <h2 class="title3">Replies</h2>
          <p class="subheadline secondary">${rsvpLine(e)}${e.rsvp_deadline ? ` · due ${dayShort(e.rsvp_deadline)}` : ""}</p>
          ${state.guests.length ? `<div class="row-group">${guestRows.join("")}</div>`
            : '<p class="panel subheadline secondary">Add guests to start collecting replies.</p>'}
        </section>` : '<p class="subheadline secondary">Guests don’t need to reply to this event.</p>'}
      <section class="stack">
        <h2 class="title3">Dress code</h2>
        <p>${esc(e.dress_code)}</p>
        ${e.dress_guidance ? `<p class="subheadline secondary">${esc(e.dress_guidance)}</p>` : ""}
        ${moodGrid(e.mood_photos)}
        ${boardButton(e.mood_link)}
      </section>
      ${eventPlanning(e)}
      ${e.status === "published" ? '<button class="button tertiary" type="button" data-action="unpublish">Hide from guests (back to draft)</button>' : ""}
      <button class="button tertiary danger" type="button" data-action="delete-event">Delete event</button>`;
  },

  // Add or change an event (app: Create event flow). Five steps: Basics → Date & place →
  // Dress code & RSVP → Guest preview → Publish. Steps are shown one at a time by showStep().
  edit(id) {
    const isNew = id === "new";
    const e = isNew ? { type: "Welcome Party", name: "", dress_code: "Cocktail attire", rsvp_required: true } : data.event(id);
    if (!e) return notFound();
    const published = e.status === "published";
    return `
      <div class="step-top">
        <a class="back" href="${isNew ? "#/events" : `#/event/${e.id}`}" data-when="1">${icon(icons.back, 20)}Cancel</a>
        <button class="back" type="button" data-action="step" data-to="back" data-when="2 3 4 5" hidden>${icon(icons.back, 20)}Back</button>
        ${statusBadge(e)}
      </div>
      <header class="stack-sm">
        <p class="footnote secondary">${isNew ? "New event" : esc(e.name)}</p>
        <h1 class="title1" id="step-title">${stepTitles[0]}</h1>
        <p class="footnote secondary" id="step-name">Step 1 of 5 · ${stepNames[0]}</p>
        <div class="progress step-bar" aria-hidden="true"><span id="step-bar" style="width:20%"></span></div>
      </header>
      <form class="stack-lg" id="event-form" novalidate data-id="${isNew ? "" : e.id}" data-current="1"
        data-published="${published}" data-photo="${esc(e.photo_url ?? "")}">
        <fieldset class="stack-lg" data-step="1">
          <p class="subheadline secondary">Start with a name and a short welcome. You’ll add the time, place and dress code next.</p>
          ${isNew ? suggestionsHTML() : ""}
          ${field("type", "Event type", `<select id="type" name="type">${options(eventTypes, e.type)}</select>`)}
          ${field("name", "Event name", `<input id="name" name="name" value="${esc(e.name)}" placeholder="e.g. Welcome Party">`)}
          ${field("welcome", "Welcome message (optional)", `<textarea id="welcome" name="welcome" placeholder="Join us for drinks before the big day.">${esc(e.welcome_message)}</textarea>`)}
          ${field("photo", "Cover photo (optional)", '<input id="photo" name="photo" type="file" accept="image/*">', e.photo_url ? "This event has a photo. Pick another to replace it." : "")}
        </fieldset>

        <fieldset class="stack-lg" data-step="2" hidden>
          ${field("day", "Date", `<input id="day" name="day" type="date" value="${esc(e.day)}">`)}
          <div class="two-up">
            ${field("start", "Start time", `<input id="start" name="start" type="time" value="${esc(e.start_time?.slice(0, 5))}">`)}
            ${field("end", "End time (optional)", `<input id="end" name="end" type="time" value="${esc(e.end_time?.slice(0, 5))}">`)}
          </div>
          ${field("venue", "Venue", `<input id="venue" name="venue" value="${esc(e.venue)}" placeholder="e.g. Seaport Hotel">`)}
          ${field("directions", "Directions for guests (optional)", `<textarea id="directions" name="directions" placeholder="Use the main entrance and follow the signs.">${esc(e.directions)}</textarea>`, "Tell guests which door or room to look for")}
        </fieldset>

        <fieldset class="stack-lg" data-step="3" hidden>
          <h2 class="title3">What to wear</h2>
          ${field("dress", "Dress code", `<select id="dress" name="dress">${options(dressCodes, e.dress_code)}</select>`)}
          ${field("guidance", "Guidance for guests (optional)", `<textarea id="guidance" name="guidance" placeholder="Dresses or suits; comfortable shoes welcome.">${esc(e.dress_guidance)}</textarea>`)}
          ${moodField(e.mood_photos ?? [])}
          ${boardField(e.mood_link ?? "")}
          <h2 class="title3">RSVP</h2>
          <div class="segmented" role="radiogroup" aria-label="RSVP">
            <label><input type="radio" name="rsvp" value="yes" ${e.rsvp_required ? "checked" : ""}><span>RSVP required</span></label>
            <label><input type="radio" name="rsvp" value="no" ${e.rsvp_required ? "" : "checked"}><span>No RSVP</span></label>
          </div>
          <div id="deadline-field" ${e.rsvp_required ? "" : "hidden"}>
            ${field("deadline", "Reply by (optional)", `<input id="deadline" name="deadline" type="date" value="${esc(e.rsvp_deadline)}">`)}
          </div>
          <div class="field">
            <span class="label">Who’s invited</span>
            <p class="panel">All wedding guests</p>
            <span class="helper" id="invited-helper">${invitedHelper(e.rsvp_required)}</span>
          </div>
        </fieldset>

        <div class="stack-lg" data-step="4" id="preview" hidden></div>
        <div class="stack-lg" data-step="5" id="review" hidden></div>
        <div class="stack-sm" id="step-buttons">${stepButtons(1, published, false)}</div>
      </form>`;
  },

  // After a first publish (app: the "is live" screen at the end of Create event).
  live(id) {
    const e = data.event(id);
    if (!e) return notFound();
    const n = state.guests.length;
    const guests = n === 0 ? "Guests you add will see it on their invite."
      : n === 1 ? "Your invited guest can now see it on their invite."
        : `All ${n} invited guests can now see it on their invite.`;
    return `
      <div class="success" aria-hidden="true">${icon(icons.check, 36)}</div>
      <header class="stack center">
        <h1 class="title1">${esc(e.name)} is live</h1>
        <p class="secondary">${guests}${e.rsvp_required && e.rsvp_deadline ? ` RSVPs close ${dayShort(e.rsvp_deadline)}.` : ""}</p>
      </header>
      ${eventCard(e)}
      <a class="button primary" href="#/events">Done</a>`;
  },

  // Guests (app: Guests tab).
  guests() {
    const people = state.guests.reduce((sum, g) => sum + g.party_size, 0);
    return `
      ${header("Guests", state.guests.length ? `${count(state.guests.length, "invitation")} · up to ${count(people, "person", "people")}` : "Everyone you’re inviting")}
      <section class="panel stack-sm" id="add-guests" aria-labelledby="add-title">
        <h2 class="headline" id="add-title">Add guests</h2>
        <form class="stack-sm" id="guest-form">
          <div class="two-up wide-first">
            ${field("guest-name", "Name", '<input id="guest-name" name="name" placeholder="Guest’s full name" autocomplete="off" required>')}
            ${field("party", "Party size", `<select id="party" name="party">${Array.from({ length: 10 }, (_, i) => `<option value="${i + 1}">${i === 0 ? "1" : `${i + 1} (+${i})`}</option>`).join("")}</select>`)}
          </div>
          <button class="button primary" type="submit">Add guest</button>
        </form>
        <div class="or-line" aria-hidden="true"><span>or add many</span></div>
        <input id="contacts-file" class="visually-hidden" type="file" accept=".vcf,.csv,.txt,.tsv,text/vcard,text/x-vcard,text/csv,text/plain" aria-label="Import a contacts file">
        <div class="add-many">
          ${canPickContacts ? `<button class="button secondary" type="button" data-action="pick-contacts">${icon(icons.person, 20)}Choose from contacts</button>` : ""}
          <button class="button secondary" type="button" data-action="paste-list">Paste a list</button>
          <label class="button tertiary" for="contacts-file">Import a contacts file</label>
        </div>
        ${contactsHelp()}
        <div id="bulk"></div>
      </section>
      ${state.guests.length ? `<div class="row-group">${state.guests.map((g) => row({
        href: `#/guest/${g.id}`, title: esc(g.name), iconPath: icons.person,
        subtitle: `Party of ${g.party_size} · ${guestReplies(g)}`,
      })).join("")}</div>` : '<p class="panel subheadline secondary">No guests yet. Each guest you add gets a personal link to your wedding website.</p>'}`;
  },

  // One guest: their invite link, replies and details.
  guest(id) {
    const g = data.guest(id);
    if (!g) return notFound();
    const link = inviteLink(g.invite_code);
    const published = state.events.filter((e) => e.status === "published" && e.rsvp_required);
    return `
      ${back("#/guests", "Guests")}
      ${header(esc(g.name), `Party of ${g.party_size}`)}
      <section class="panel stack-sm">
        <h2 class="headline">Personal invite link</h2>
        <p class="subheadline secondary">Send this to ${esc(g.name.split(" ")[0])}. It opens their invite: RSVPs, schedule, what to wear and your registry.</p>
        <input class="link-box" readonly value="${esc(link)}" aria-label="Invite link">
        <div class="two-up">
          <button class="button primary" type="button" data-action="copy" data-link="${esc(link)}">${icon(icons.link, 20)}Copy link</button>
          <a class="button secondary" href="${esc(link)}" target="_blank" rel="noopener">See their invite</a>
        </div>
      </section>
      <section class="stack">
        <h2 class="title3">Replies</h2>
        ${published.length ? `<div class="row-group">${published.map((e) => {
          const r = data.reply(e.id, g.id);
          return `<a class="row" href="#/event/${e.id}"><span class="text"><span class="headline">${esc(e.name)}</span>${r?.note ? `<span class="subheadline secondary">“${esc(r.note)}”</span>` : ""}</span>
            ${!r ? '<span class="badge reply">Waiting</span>' : r.attending ? `<span class="badge attending">Coming${r.party_count > 1 ? ` · ${r.party_count}` : ""}</span>` : '<span class="badge declined">Can’t go</span>'}</a>`;
        }).join("")}</div>` : '<p class="subheadline secondary">Publish an event to start collecting replies.</p>'}
      </section>
      <form class="stack-lg" id="guest-edit-form" data-id="${g.id}">
        <h2 class="title3">Details</h2>
        <div class="two-up wide-first">
          ${field("edit-name", "Name", `<input id="edit-name" name="name" value="${esc(g.name)}" required>`)}
          ${field("edit-party", "Party size", `<input id="edit-party" name="party" type="number" min="1" max="20" value="${g.party_size}" required>`)}
        </div>
        <button class="button secondary" type="submit">Save changes</button>
      </form>
      <button class="button tertiary danger" type="button" data-action="delete-guest">Remove guest</button>`;
  },

  // Registry (app: Registry tab, CR1–CR4).
  registry() {
    const raised = state.registry.filter((i) => i.is_fund).reduce((sum, i) => sum + data.raised(i.id), 0);
    const taken = state.registry.filter(data.isTaken).length;
    return `
      ${header("Registry", "Gifts and cash funds guests can choose from")}
      <a class="button primary" href="#/item/new">Add a gift or fund</a>
      ${state.registry.length ? `
        <p class="subheadline secondary">${count(state.registry.length, "gift")} listed · ${taken} bought${raised ? ` · ${money(raised)} in cash funds` : ""}</p>
        <div class="row-group">${state.registry.map((i) => row({
          href: `#/item/${i.id}`, title: esc(i.name), iconPath: i.is_fund ? icons.fund : icons.gift,
          subtitle: i.is_fund ? `${money(data.raised(i.id))} of ${money(i.price)}` : `${money(i.price)} · ${itemStatus(i)}`,
        })).join("")}</div>`
        : '<p class="panel subheadline secondary">Add gifts and cash funds. Guests see them on your wedding website and can say “I’ll get this,” so nobody buys the same thing twice.</p>'}`;
  },

  // Add or change a gift or cash fund (app: CR2).
  item(id) {
    const isNew = id === "new";
    const i = isNew ? { name: "", price: "", is_fund: false, link: "", note: "", purchased: false } : data.item(id);
    if (!i) return notFound();
    const given = isNew ? [] : data.giftsFor(i.id);
    return `
      ${back("#/registry", "Registry")}
      ${header(isNew ? "Add to registry" : esc(i.name))}
      ${given.length ? `<p class="panel accent subheadline">${i.is_fund
        ? `${money(data.raised(i.id))} raised from ${count(given.length, "guest")}.`
        : `${esc(data.guest(given[0].guest_id)?.name ?? "A guest")} is getting this.`}</p>` : ""}
      <form class="stack-lg" id="item-form" data-id="${isNew ? "" : i.id}">
        <div class="segmented" role="radiogroup" aria-label="Kind">
          <label><input type="radio" name="kind" value="gift" ${i.is_fund ? "" : "checked"}><span>Gift</span></label>
          <label><input type="radio" name="kind" value="fund" ${i.is_fund ? "checked" : ""}><span>Cash fund</span></label>
        </div>
        ${field("item-name", "Name", `<input id="item-name" name="name" value="${esc(i.name)}" placeholder="Gift name" required>`)}
        ${field("price", `<span id="price-label">${i.is_fund ? "Goal ($)" : "Price ($)"}</span>`, `<input id="price" name="price" type="number" min="0" max="1000000" step="1" value="${esc(i.price)}" required>`)}
        ${field("link", "Store link (optional)", `<input id="link" name="link" value="${esc(i.link)}" placeholder="https://…">`)}
        ${field("note", "Note for guests (optional)", `<textarea id="note" name="note" placeholder="Color, size or anything else">${esc(i.note)}</textarea>`)}
        <label class="check" id="bought-field" ${i.is_fund ? "hidden" : ""}><input type="checkbox" name="purchased" ${i.purchased ? "checked" : ""}><span>We already have this (shows as bought)</span></label>
        <button class="button primary" type="submit">${isNew ? "Add to registry" : "Save changes"}</button>
      </form>
      ${isNew ? "" : '<button class="button tertiary danger" type="button" data-action="delete-item">Remove from registry</button>'}`;
  },

  // Planning: the couple's to-do list and vendors. Only the couple sees this.
  planning() {
    const open = openTasks();
    const done = state.tasks.filter((t) => t.done).sort(byDue);
    return `
      ${header("Planning", "Your to-do list and vendors. Only the two of you see this.")}
      ${state.planningReady ? "" : '<p class="panel warning subheadline">Planning needs a quick database update before it can save. Run <b>supabase/schema.sql</b> again in the Supabase SQL Editor.</p>'}
      <section class="stack">
        <h2 class="title3">To-do</h2>
        ${state.tasks.length ? `<p class="subheadline secondary">${done.length} of ${state.tasks.length} done${open.length ? "" : " · All done!"}</p>` : ""}
        <form class="panel stack-sm" id="task-form">
          <div class="two-up wide-first">
            ${field("task-title", "New to-do", '<input id="task-title" name="title" placeholder="Book the florist" maxlength="300" required>')}
            ${field("task-due", "Due (optional)", '<input id="task-due" name="due" type="date">')}
          </div>
          ${eventSelect("task-event")}
          <button class="button secondary" type="submit">${icon(icons.plus, 20)}Add to-do</button>
        </form>
        ${open.length ? `<div class="row-group">${open.map((t) => taskRow(t)).join("")}</div>` : ""}
        ${state.tasks.length ? "" : `
          <div class="panel accent stack-sm">
            <p class="headline">Not sure where to start?</p>
            <p class="subheadline">Add a checklist of the usual wedding to-dos, with due dates counted back from ${dayShort(state.wedding.date)}. You can remove any you don’t need.</p>
            <button class="button primary" type="button" data-action="starter-tasks">${icon(icons.sparkle, 20)}Add a starter checklist</button>
          </div>`}
        ${done.length ? `
          <details class="done-tasks">
            <summary class="subheadline secondary">Done (${done.length})</summary>
            <div class="row-group">${done.map((t) => taskRow(t)).join("")}</div>
          </details>` : ""}
      </section>
      <section class="stack">
        <h2 class="title3">Vendors</h2>
        <p class="subheadline secondary">Phone numbers, emails and notes for everyone you’ve booked, in one place.</p>
        ${state.vendors.length ? `<div class="row-group">${state.vendors.map((v) => row({
          href: `#/vendor/${v.id}`, title: esc(v.name), subtitle: vendorSubtitle(v), iconPath: icons.person,
        })).join("")}</div>` : ""}
        <a class="button ${state.vendors.length ? "secondary" : "primary"}" href="#/vendor/new">${icon(icons.plus, 20)}Add a vendor</a>
      </section>`;
  },

  // Add or change a vendor, with buttons to call, text or email them.
  // Opened from an event page, the address also has that event (#/vendor/<id>/<event id>),
  // so Back and Save return there and a new vendor starts linked to it.
  vendor(id, from) {
    const isNew = id === "new";
    const fromEvent = from && data.event(from);
    const v = isNew ? { category: "", name: "", contact_name: "", phone: "", email: "", website: "", notes: "", event_id: fromEvent?.id ?? null } : data.vendor(id);
    if (!v) return notFound();
    const actions = isNew ? [] : [
      v.phone && `<a class="button secondary" href="${esc(telHref(v.phone))}">${icon(icons.phone, 20)}Call</a>`,
      v.phone && `<a class="button secondary" href="sms:${esc(v.phone.replace(/[^\d+]/g, ""))}">${icon(icons.text, 20)}Text</a>`,
      v.email && `<a class="button secondary" href="mailto:${esc(v.email)}">${icon(icons.mail, 20)}Email</a>`,
      v.website && `<a class="button secondary" href="${esc(webHref(v.website))}" target="_blank" rel="noopener">${icon(icons.link, 20)}Website</a>`,
    ].filter(Boolean);
    const known = vendorTypes.includes(v.category);
    return `
      ${fromEvent ? back(`#/event/${fromEvent.id}`, esc(fromEvent.name)) : back("#/planning", "Planning")}
      ${header(isNew ? "Add a vendor" : esc(v.name), isNew ? "" : esc([v.category, eventName(v.event_id)].filter(Boolean).join(" · ")))}
      ${actions.length ? `<div class="contact-actions">${actions.join("")}</div>` : ""}
      <form class="stack-lg" id="vendor-form" data-id="${isNew ? "" : v.id}" data-back="${fromEvent ? `#/event/${fromEvent.id}` : "#/planning"}">
        ${field("v-category", "What they do", `<select id="v-category" name="category">
          <option value="" ${v.category ? "" : "selected"} disabled>Choose one</option>
          ${vendorTypes.map((t) => `<option ${t === v.category ? "selected" : ""}>${t}</option>`).join("")}
          ${v.category && !known ? `<option selected>${esc(v.category)}</option>` : ""}
        </select>`)}
        ${eventSelect("v-event", v.event_id ?? "", "Working at which event (optional)")}
        ${field("v-name", "Business name", `<input id="v-name" name="name" value="${esc(v.name)}" placeholder="Bloom & Co." required>`)}
        ${field("v-contact", "Contact person (optional)", `<input id="v-contact" name="contact" value="${esc(v.contact_name)}" placeholder="Who you talk to">`)}
        <div class="two-up">
          ${field("v-phone", "Phone", `<input id="v-phone" name="phone" type="tel" value="${esc(v.phone)}" placeholder="(555) 123-4567" autocomplete="off">`)}
          ${field("v-email", "Email", `<input id="v-email" name="email" type="email" value="${esc(v.email)}" placeholder="name@example.com" autocomplete="off">`)}
        </div>
        ${field("v-website", "Website (optional)", `<input id="v-website" name="website" value="${esc(v.website)}" placeholder="https://…">`)}
        ${field("v-notes", "Notes", `<textarea id="v-notes" name="notes" placeholder="Price, deposit paid, arrival time, what’s included…">${esc(v.notes)}</textarea>`)}
        <button class="button primary" type="submit">${isNew ? "Add vendor" : "Save changes"}</button>
      </form>
      ${isNew ? "" : '<button class="button tertiary danger" type="button" data-action="delete-vendor">Remove vendor</button>'}`;
  },

  // Questions guests asked, with answers.
  questions() {
    const eventName = (id) => data.event(id)?.name;
    return `
      ${back("#/home", "Home")}
      ${header("Guest questions", "Your answer shows up on the guest’s invite, so they don’t have to text you.")}
      ${state.questions.length ? state.questions.map((q) => `
        <form class="panel stack-sm answer-form" data-id="${q.id}">
          <span class="footnote secondary">${esc(data.guest(q.guest_id)?.name ?? "A guest")}${eventName(q.event_id) ? ` · ${esc(eventName(q.event_id))}` : ""} · ${stamp(q.asked_at)}</span>
          <p class="headline">${esc(q.text)}</p>
          <div class="field">
            <label for="answer-${q.id}">${q.answer ? "Your answer" : "Answer"}</label>
            <textarea id="answer-${q.id}" name="answer" placeholder="Type your answer">${esc(q.answer)}</textarea>
          </div>
          <button class="button ${q.answer ? "secondary" : "primary"}" type="submit">${q.answer ? "Update answer" : "Send answer"}</button>
        </form>`).join("") : '<p class="panel subheadline secondary">No questions yet. Guests can ask you anything from their invite.</p>'}`;
  },

  // Wedding details and the couple photo.
  wedding() {
    const w = state.wedding;
    return `
      ${back("#/home", "Home")}
      ${header("Wedding details")}
      ${w.photo_url ? `<img class="cover couple-photo" src="${esc(photoParts(w.photo_url).src)}" style="object-position:${photoParts(w.photo_url).pos}" alt="Your photo">` : ""}
      <form class="stack-lg" id="wedding-form">
        ${field("w-names", "Your names", `<input id="w-names" name="names" value="${esc(w.couple_names)}" required>`)}
        ${field("w-date", "Wedding date", `<input id="w-date" name="date" type="date" value="${esc(w.date)}" required>`)}
        ${field("w-venue", "Venue", `<input id="w-venue" name="venue" value="${esc(w.venue)}">`)}
        ${field("w-hotel", "Where to stay", `<textarea id="w-hotel" name="hotel" placeholder="Hotels near the venue">${esc(w.hotel_info)}</textarea>`)}
        ${field("w-parking", "Parking", `<textarea id="w-parking" name="parking" placeholder="Where guests can park">${esc(w.parking_info)}</textarea>`)}
        ${field("w-photo", "Your photo", '<input id="w-photo" name="photo" type="file" accept="image/*">', "Guests see it on the home page of their invite.")}
        <button class="button primary" type="submit">Save changes</button>
      </form>`;
  },
};

/** Gifts guests gave, with thank-you checkboxes (shown on Home). */
function thankYous() {
  if (!state.gifts.length) return "";
  const guestName = (id) => esc(data.guest(id)?.name ?? "A guest");
  const due = state.gifts.filter((g) => !g.thank_you_sent).length;
  return `
        <section class="stack">
          <h2 class="title3">Thank-you notes</h2>
          <p class="subheadline secondary">${due ? `${count(due, "thank-you")} to send. ` : "All sent. "}Tick a gift once you’ve sent the note.</p>
          <div class="row-group">${state.gifts.map((g) => {
            const item = data.item(g.item_id);
            return `
              <label class="row check-row">
                <input type="checkbox" data-action="thank-you" data-id="${g.id}" ${g.thank_you_sent ? "checked" : ""}>
                <span class="text"><span class="headline">${esc(item?.name)}${item?.is_fund ? ` · ${money(g.amount)}` : ""}</span>
                <span class="subheadline secondary">From ${guestName(g.guest_id)} · ${stamp(g.given_at)} · ${g.thank_you_sent ? "Thank-you sent" : "Thank-you due"}</span>
                ${g.note ? `<span class="subheadline secondary">“${esc(g.note)}”</span>` : ""}</span>
              </label>`;
          }).join("")}</div>
        </section>`;
}

/** Registries the couple keeps at other stores (shown on Home). */
function otherStores() {
  return `<section class="stack">
        <h2 class="title3">Registries at other stores</h2>
        <p class="subheadline secondary">Guests see these next to your gift list.</p>
        ${state.links.length ? `<div class="row-group">${state.links.map((l) => `
          <div class="row">${icon(icons.link)}<span class="text"><span class="headline">${esc(l.name)}</span><span class="subheadline secondary">${esc(l.url)}</span></span>
            <button class="button tertiary small" type="button" data-action="delete-link" data-id="${l.id}" aria-label="Remove ${esc(l.name)}">Remove</button></div>`).join("")}</div>` : ""}
        <form class="panel stack-sm" id="link-form">
          <div class="two-up">
            ${field("store", "Store", '<input id="store" name="name" placeholder="Store name" required>')}
            ${field("url", "Link", '<input id="url" name="url" type="url" placeholder="https://…" required>')}
          </div>
          <button class="button secondary" type="submit">Link registry</button>
        </form>
      </section>`;
}

/** The large card for the next event on Home: photo on top, then the details. */
function nextEventCard(e) {
  const photo = photoFor(e);
  const days = daysUntil(e.day);
  return `
    <a class="card next-event" href="#/event/${e.id}">
      ${photo ? `<img src="${esc(photo)}" alt="">` : ""}
      <div class="stack">
        <span class="footnote secondary">${days === 0 ? "Today" : days === 1 ? "Tomorrow" : `In ${count(days, "day")}`}</span>
        <span class="title2">${esc(e.name)}</span>
        <span class="headline secondary">${when(e)}</span>
        ${e.venue ? `<span class="subheadline secondary">${esc(e.venue)}</span>` : ""}
        ${e.rsvp_required ? `<span class="subheadline">${rsvpLine(e)}</span>` : ""}
      </div>
    </a>`;
}

function eventCard(e) {
  const photo = photoFor(e);
  return `
    <a class="card event-card" href="#/event/${e.id}">
      <div class="top">
        ${photo ? `<img class="thumb" src="${esc(photo)}" alt="" loading="lazy">` : '<span class="thumb" aria-hidden="true"></span>'}
        <div class="stack" style="gap:2px">
          <span class="title3">${esc(e.name)}</span>
          <span class="subheadline secondary">${when(e)}</span>
          ${e.venue ? `<span class="subheadline secondary">${esc(e.venue)}</span>` : ""}
        </div>
      </div>
      <div class="bottom">${statusBadge(e)}<span class="footnote secondary">${e.status === "published" ? rsvpLine(e) : `${count(data.missing(e).length, "detail")} missing`}</span></div>
    </a>`;
}

function guestReplies(g) {
  const asked = state.events.filter((e) => e.status === "published" && e.rsvp_required);
  if (!asked.length) return "Invite link ready";
  const replied = asked.filter((e) => data.reply(e.id, g.id)).length;
  return replied === asked.length ? "All replied" : `${replied} of ${asked.length} replied`;
}

function itemStatus(i) {
  if (i.purchased) return "You have it";
  const gift = data.giftsFor(i.id)[0];
  return gift ? `${esc(data.guest(gift.guest_id)?.name ?? "A guest")} is getting it` : "Available";
}

function notFound() {
  return `
    ${back("#/home", "Home")}
    <header class="stack"><h1 class="title1">This page isn’t here</h1><p class="secondary">It may have been removed.</p></header>`;
}

// ---------- Routing ----------

const tabs = { home: "home", questions: "home", wedding: "home", events: "events", event: "events", edit: "events", live: "events",
  guests: "guests", guest: "guests", registry: "registry", item: "registry", planning: "planning", vendor: "planning" };

function route() {
  const [path, param, extra] = location.hash.replace(/^#\/?/, "").split("/");
  return { name: path || "home", param, extra };
}

function render({ keepScroll = false } = {}) {
  const { name, param, extra } = route();
  const signedIn = data.signedIn() && state.wedding;
  document.body.classList.toggle("signed-out", !signedIn);
  if (!data.signedIn()) {
    main.innerHTML = (pagesSignedOut[name] ?? pagesSignedOut.signin)();
  } else if (name === "new-password") {
    document.body.classList.add("signed-out");
    main.innerHTML = newPasswordPage();
  } else if (!state.wedding) {
    main.innerHTML = setupPage();
  } else {
    main.innerHTML = (pages[name] ?? notFound)(param, extra);
    const tab = name === "vendor" && extra ? "events" : tabs[name] ?? "home";
    document.querySelectorAll(".tabbar a[data-tab]").forEach((a) => {
      if (a.dataset.tab === tab) a.setAttribute("aria-current", "page");
      else a.removeAttribute("aria-current");
    });
  }
  const heading = main.querySelector("h1");
  document.title = `${heading?.textContent.trim() || "Intertwine"} · Intertwine`;
  if (pendingNote) { note(pendingNote); pendingNote = null; }
  if (keepScroll) return;
  window.scrollTo(0, 0);
  if (heading && location.hash) {
    heading.setAttribute("tabindex", "-1");
    heading.focus({ preventScroll: true });
  }
}

function showError(near, error) {
  if (error instanceof SignedOut) { location.hash = "#/signin"; render(); return; }
  near.querySelector?.(".form-error")?.remove();
  near.insertAdjacentHTML("beforeend",
    `<p class="panel warning subheadline form-error" role="alert">${esc(error.message || "That didn’t go through. Try again.")}</p>`);
}

/** Disables a form's button and shows progress while something saves. */
async function busy(form, label, work) {
  const button = form.querySelector("button[type=submit]");
  const original = button.innerHTML;
  button.disabled = true;
  button.textContent = label;
  try {
    await work();
    return true;
  } catch (error) {
    button.disabled = false;
    button.innerHTML = original;
    showError(form, error);
    return false;
  }
}

function note(text) {
  main.insertAdjacentHTML("afterbegin", `<p class="panel success-note subheadline" role="status">${esc(text)}</p>`);
}

/** Opens a page and shows a message at its top once it's drawn. */
let pendingNote = null;
function go(hash, message = null) {
  pendingNote = message;
  if (location.hash === hash) render();
  else location.hash = hash; // the hashchange listener draws the page
}

const text = (fields, name) => String(fields.get(name) ?? "").trim();
const optionalDate = (fields, name) => text(fields, name) || null;
/** The vendor's event, sent only when there is one to save or clear (so it works before the database update). */
function eventField(fields, id) {
  const chosen = text(fields, "event") || null;
  return chosen || data.vendor(id)?.event_id ? { event_id: chosen } : {};
}

// Forms, in one place so pages stay plain HTML.
main.addEventListener("submit", async (e) => {
  e.preventDefault();
  const form = e.target;
  const fields = new FormData(form);

  if (form.id === "auth-form") {
    const email = text(fields, "email"), password = String(fields.get("password"));
    const signingUp = form.dataset.mode === "signup";
    let confirmFirst = false;
    const ok = await busy(form, signingUp ? "Creating account…" : "Signing in…", async () => {
      if (signingUp) confirmFirst = !(await data.signUp(email, password));
      else await data.signIn(email, password);
      if (!confirmFirst) await data.load();
    });
    if (!ok) return;
    if (confirmFirst) {
      go("#/signin", "Check your email and click the link to confirm your account. Then sign in here.");
      return;
    }
    location.hash = "#/home";
    render();
  }

  if (form.id === "forgot-form") {
    if (await busy(form, "Sending…", () => data.forgotPassword(text(fields, "email")))) {
      go("#/signin", "If there’s an account for that email, a reset link is on its way. Check your inbox (and spam).");
    }
  }

  if (form.id === "password-form") {
    if (await busy(form, "Saving…", () => data.setPassword(String(fields.get("password"))))) {
      await data.load().catch(() => {});
      go("#/home", "Your password is changed.");
    }
  }

  if (form.id === "setup-form") {
    if (await busy(form, "Saving…", () => data.createWedding({
      coupleNames: text(fields, "names"), date: text(fields, "date"), venue: text(fields, "venue"),
    }))) { location.hash = "#/home"; render(); }
  }

  if (form.id === "wedding-form") {
    const photo = fields.get("photo");
    if (await busy(form, "Saving…", () => data.saveWedding({
      couple_names: text(fields, "names"), date: text(fields, "date"), venue: text(fields, "venue"),
      hotel_info: text(fields, "hotel"), parking_info: text(fields, "parking"),
    }, photo?.size ? photo : null))) { render(); note("Saved. Guests see the changes on their invite."); }
  }

  if (form.id === "event-form") {
    // Enter in a text box moves to the next step instead of saving.
    if (!e.submitter) { if (Number(form.dataset.current) <= 3) nextStep(form); return; }
    const publishing = e.submitter.value === "publish";
    const wasPublished = form.dataset.published === "true";
    const row = eventFields(form);
    if (!row.name) { showStep(form, 1); markErrors(form, stepErrors(form, 1)); return; }
    if (publishing) row.status = "published";
    const photo = fields.get("photo");
    // Only send the mood board when it changed (older databases don't have it yet).
    const mood = form.dataset.moodChanged ? moodBoard(form) : null;
    let id = form.dataset.id;
    if (await busy(form, publishing && !wasPublished ? "Publishing…" : "Saving…", async () => {
      id = await data.saveEvent(id || null, row, photo?.size ? photo : null, mood);
    })) {
      if (!publishing) go(`#/event/${id}`, "Saved as a draft. Guests can’t see it until you publish.");
      else if (wasPublished) go(`#/event/${id}`, "Changes saved. Guests see them right away.");
      else go(`#/live/${id}`);
    }
  }

  if (form.id === "guest-form") {
    if (await busy(form, "Adding…", () => data.addGuest(text(fields, "name"), Number(fields.get("party")) || 1))) {
      render({ keepScroll: true });
      main.querySelector("#guest-name").focus();
    }
  }

  if (form.id === "paste-form") {
    const people = listGuests(String(fields.get("names")));
    if (!people.length) { main.querySelector("#bulk-names").focus(); return; }
    main.querySelector("#bulk").innerHTML = pickList(people);
  }

  if (form.id === "bulk-form") {
    const names = [...form.querySelectorAll('input[name="pick"]:checked')]
      .map((b) => ({ name: b.value, party: Number(b.dataset.party) || 1 }));
    if (!names.length) return;
    if (await busy(form, "Adding…", () => data.addGuests(names))) {
      go("#/guests", `Added ${count(names.length, "guest")}. Each one has their own invite link.`);
    }
  }

  if (form.id === "guest-edit-form") {
    if (await busy(form, "Saving…", () => data.saveGuest(form.dataset.id, {
      name: text(fields, "name"), party_size: Number(fields.get("party")) || 1,
    }))) { render({ keepScroll: true }); }
  }

  if (form.id === "item-form") {
    const fund = fields.get("kind") === "fund";
    let link = text(fields, "link");
    if (link && !/^https?:\/\//i.test(link)) link = `https://${link}`;
    if (await busy(form, "Saving…", () => data.saveItem(form.dataset.id || null, {
      name: text(fields, "name"), price: Math.round(Number(fields.get("price")) || 0), is_fund: fund,
      link, note: text(fields, "note"), purchased: !fund && fields.get("purchased") === "on",
    }))) { location.hash = "#/registry"; }
  }

  if (form.id === "link-form") {
    let url = text(fields, "url");
    if (!/^https?:\/\//i.test(url)) url = `https://${url}`;
    if (await busy(form, "Adding…", () => data.addLink(text(fields, "name"), url))) render({ keepScroll: true });
  }

  if (form.id === "task-form") {
    if (await busy(form, "Adding…", () => data.addTasks([{ title: text(fields, "title"), due: optionalDate(fields, "due"),
      event_id: form.dataset.event || text(fields, "event") || null }]))) {
      render({ keepScroll: true });
      main.querySelector("#task-title")?.focus();
    }
  }

  if (form.id === "vendor-form") {
    const website = text(fields, "website");
    if (await busy(form, "Saving…", () => data.saveVendor(form.dataset.id || null, {
      category: text(fields, "category"), name: text(fields, "name"), contact_name: text(fields, "contact"),
      phone: text(fields, "phone"), email: text(fields, "email"), website: website ? webHref(website) : "",
      notes: text(fields, "notes"), ...eventField(fields, form.dataset.id),
    }))) { go(form.dataset.back, form.dataset.id ? "Vendor saved." : "Vendor added."); }
  }

  if (form.classList.contains("answer-form")) {
    if (await busy(form, "Sending…", () => data.answer(form.dataset.id, text(fields, "answer")))) {
      render({ keepScroll: true });
    }
  }
});

main.addEventListener("change", async (e) => {
  const target = e.target;
  if (target.name === "kind") {
    const fund = target.value === "fund";
    main.querySelector("#price-label").textContent = fund ? "Goal ($)" : "Price ($)";
    main.querySelector("#bought-field").hidden = fund;
  }
  if (target.id === "contacts-file" && target.files[0]) {
    const file = target.files[0];
    target.value = "";
    await importFile(file);
  }
  if (target.id === "mood-input" && target.files.length) {
    const form = target.form;
    const room = MOOD_MAX - moodTiles(form).length;
    const add = form.querySelector(".mood-add");
    for (const file of [...target.files].slice(0, room)) {
      const key = crypto.randomUUID();
      moodFiles.set(key, file);
      add.insertAdjacentHTML("beforebegin", moodTile(URL.createObjectURL(file), `data-new="${key}"`));
    }
    target.value = "";
    form.dataset.moodChanged = "true";
    updateMoodAdd(form);
  }
  if (target.id === "hero-photo" && target.files[0]) {
    // A photo behind the countdown (the couple photo guests also see). It shows here first
    // so the couple can drag it into place; Save uploads it.
    pendingPhoto = target.files[0];
    target.value = "";
    const hero = main.querySelector(".stat.hero");
    const preview = URL.createObjectURL(pendingPhoto);
    hero.setAttribute("style", `background-image:url('${preview}');background-position:50% 30%`);
    hero.dataset.x = 50;
    hero.dataset.y = 30;
    startMove(hero, preview);
  }
  if (target.name === "pick") updatePick();
  if (target.name === "rsvp") {
    const required = target.value === "yes";
    main.querySelector("#deadline-field").hidden = !required;
    main.querySelector("#invited-helper").textContent = invitedHelper(required);
  }
  if (target.name === "type") {
    // Name a new event after its type until the couple types their own name.
    const name = main.querySelector("#name");
    if (!name.value || eventTypes.includes(name.value)) name.value = target.value === "Other" ? "" : target.value;
  }
  if (target.dataset.action === "task-done") {
    target.disabled = true;
    try { await data.saveTask(target.dataset.id, { done: target.checked }); render({ keepScroll: true }); }
    catch (error) { target.checked = !target.checked; target.disabled = false; showError(target.closest("section"), error); }
  }
  if (target.dataset.action === "thank-you") {
    target.disabled = true;
    try { await data.thankYou(target.dataset.id, target.checked); render({ keepScroll: true }); }
    catch (error) { target.checked = !target.checked; target.disabled = false; showError(target.closest("section"), error); }
  }
});

// In the event steps, Enter in a text box goes to the next step (not "Save draft").
main.addEventListener("keydown", (e) => {
  const form = e.target.form;
  if (e.key !== "Enter" || form?.id !== "event-form" || e.target.tagName !== "INPUT") return;
  e.preventDefault();
  if (Number(form.dataset.current) <= 3) nextStep(form);
});

// A newly picked countdown photo, waiting for Save.
let pendingPhoto = null;

/** Lets the couple drag the countdown photo to choose how it's cropped. */
function startMove(hero, src) {
  main.querySelector(".move-bar")?.remove();
  hero.classList.add("moving");
  // The photo's own size tells how far it can slide inside the card.
  const image = new Image();
  image.onload = () => { hero.dataset.w = image.naturalWidth; hero.dataset.h = image.naturalHeight; };
  image.src = src;
  hero.insertAdjacentHTML("beforeend", `
    <div class="move-bar">
      <span class="footnote">Drag to move it</span>
      <button class="button tertiary small" type="button" data-action="move-cancel">Cancel</button>
      <button class="button primary small" type="button" data-action="move-save">Save</button>
    </div>`);
}

// Dragging the countdown photo into place.
let drag = null;
main.addEventListener("pointerdown", (e) => {
  const hero = e.target.closest(".stat.hero.moving");
  if (!hero || e.target.closest(".move-bar")) return;
  // How far the photo can slide each way: the part of it the card crops off.
  const box = hero.getBoundingClientRect();
  const w = Number(hero.dataset.w) || box.width, h = Number(hero.dataset.h) || box.height;
  const scale = Math.max(box.width / w, box.height / h);
  drag = {
    hero, startX: e.clientX, startY: e.clientY, x: Number(hero.dataset.x), y: Number(hero.dataset.y),
    spareX: w * scale - box.width, spareY: h * scale - box.height,
  };
  hero.setPointerCapture(e.pointerId);
});
main.addEventListener("pointermove", (e) => {
  if (!drag) return;
  const clamp = (n) => Math.min(100, Math.max(0, n));
  const x = drag.spareX > 0 ? clamp(drag.x - ((e.clientX - drag.startX) / drag.spareX) * 100) : 50;
  const y = drag.spareY > 0 ? clamp(drag.y - ((e.clientY - drag.startY) / drag.spareY) * 100) : 50;
  drag.hero.dataset.x = x;
  drag.hero.dataset.y = y;
  drag.hero.style.backgroundPosition = `${x}% ${y}%`;
});
const endDrag = () => { drag = null; };
main.addEventListener("pointerup", endDrag);
main.addEventListener("pointercancel", endDrag);

// Drag a contacts file onto the Add guests box (on a computer).
const dropZone = (e) => e.target.closest?.("#add-guests");
main.addEventListener("dragover", (e) => {
  if (!dropZone(e) || !e.dataTransfer?.types.includes("Files")) return;
  e.preventDefault();
  dropZone(e).classList.add("dropping");
});
main.addEventListener("dragleave", (e) => {
  if (dropZone(e) && !dropZone(e).contains(e.relatedTarget)) dropZone(e).classList.remove("dropping");
});
main.addEventListener("drop", async (e) => {
  const zone = dropZone(e);
  if (!zone) return;
  e.preventDefault();
  zone.classList.remove("dropping");
  if (e.dataTransfer.files[0]) await importFile(e.dataTransfer.files[0]);
});

main.addEventListener("input", ({ target }) => {
  if (target.id === "bulk-names") {
    const n = listGuests(target.value).length;
    main.querySelector("#paste-count").textContent = n ? `${count(n, "guest")} found. Tap Next to check them.` : pasteHelp;
  }
  if (target.id === "board") boardChanged(target.form);
  if (target.id === "pin-user" || target.id === "pin-board") {
    const form = target.form;
    const link = boardFromName(form.querySelector("#pin-user").value, form.querySelector("#pin-board").value);
    if (link) { form.elements.board.value = link; boardChanged(form); }
  }
});

main.addEventListener("click", async (e) => {
  const button = e.target.closest("[data-action]");
  if (!button || button.type === "checkbox") return;
  const { name, param } = route();
  const run = async (work) => {
    button.disabled = true;
    try { await work(); } catch (error) { button.disabled = false; showError(main, error); }
  };

  switch (button.dataset.action) {
    case "mood-style": {
      // Swap in a ready-made board: earlier ready-made photos go, the couple's own stay.
      const form = button.form;
      moodTiles(form).filter((t) => isStylePhoto(t.dataset.url)).forEach((t) => t.remove());
      const add = form.querySelector(".mood-add");
      const room = MOOD_MAX - moodTiles(form).length;
      for (const url of moodStylePhotos(button.dataset.style).slice(0, room)) {
        add.insertAdjacentHTML("beforebegin", moodTile(url, `data-url="${esc(url)}"`));
      }
      form.querySelectorAll('[data-action="mood-style"]').forEach((b) => b.setAttribute("aria-pressed", String(b === button)));
      form.dataset.moodChanged = "true";
      updateMoodAdd(form);
      return;
    }
    case "quiz-open":
      showQuiz(button.form, []);
      return;
    case "quiz-answer":
      showQuiz(button.form, [...quizPicks(button.form), Number(button.dataset.i)]);
      return;
    case "quiz-back":
      showQuiz(button.form, quizPicks(button.form).slice(0, -1));
      return;
    case "quiz-close":
      showQuiz(button.form, null);
      return;
    case "quiz-use": {
      const form = button.form;
      showQuiz(form, null);
      form.querySelector(`[data-action="mood-style"][data-style="${button.dataset.style}"]`).click();
      form.querySelector("#mood-grid").scrollIntoView({ behavior: "smooth", block: "nearest" });
      return;
    }
    case "mood-remove": {
      const form = button.form;
      const tile = button.closest(".mood-tile");
      moodFiles.delete(tile.dataset.new);
      tile.remove();
      form.dataset.moodChanged = "true";
      updateMoodAdd(form);
      return;
    }
    case "move-cancel":
      pendingPhoto = null;
      render();
      return;
    case "move-save": {
      const hero = main.querySelector(".stat.hero");
      const crop = `#pos=${Math.round(hero.dataset.x)},${Math.round(hero.dataset.y)}`;
      button.textContent = "Saving…";
      await run(async () => {
        await data.saveWedding({}, pendingPhoto, crop);
        pendingPhoto = null;
        render();
        note("Photo saved. Guests see it on their invite too.");
      });
      if (button.disabled === false) button.textContent = "Save";
      return;
    }
    case "pick-contacts":
      // Opens the phone's own contact list; nothing is shared until the couple picks people.
      pickContacts();
      return;
    case "paste-list":
      main.querySelector("#bulk").innerHTML = pasteForm();
      main.querySelector("#bulk-names").focus();
      return;
    case "paste-names": {
      const box = main.querySelector("#bulk-names");
      try {
        const pasted = await navigator.clipboard.readText();
        if (pasted.trim()) {
          box.value = (box.value.trim() ? `${box.value.trimEnd()}\n` : "") + pasted;
          box.dispatchEvent(new Event("input", { bubbles: true }));
        }
      } catch { box.focus(); note("Couldn’t paste. Tap the box and choose Paste instead."); }
      return;
    }
    case "bulk-cancel":
      main.querySelector("#bulk").innerHTML = "";
      return;
    case "pick-all": {
      const boxes = [...main.querySelectorAll('input[name="pick"]:not(:disabled)')];
      const tick = !boxes.some((b) => b.checked);
      boxes.forEach((b) => { b.checked = tick; });
      updatePick();
      return;
    }
    case "sign-out":
      data.signOut();
      location.hash = "#/signin";
      render();
      break;
    case "copy":
      try {
        await navigator.clipboard.writeText(button.dataset.link);
      } catch {
        const box = main.querySelector(".link-box");
        box.select();
        document.execCommand("copy");
      }
      button.textContent = "Copied!";
      setTimeout(() => { if (button.isConnected) button.innerHTML = `${icon(icons.link, 20)}Copy link`; }, 2000);
      break;
    case "board-paste": {
      const form = button.form;
      try {
        const pasted = await navigator.clipboard.readText();
        if (pasted.trim()) { form.elements.board.value = boardLink(pasted); boardChanged(form); }
      } catch {
        form.elements.board.focus();
        note("Couldn’t paste. Tap the box and choose Paste instead.");
      }
      break;
    }
    case "suggest": {
      const form = main.querySelector("#event-form");
      const s = eventSuggestions[Number(button.dataset.i)];
      const set = (id, value) => { form.querySelector(`#${id}`).value = value; };
      set("type", s.type);
      set("name", s.name);
      set("welcome", s.welcome);
      set("dress", s.dress);
      form.querySelector(`input[name="rsvp"][value="${s.rsvp ? "yes" : "no"}"]`).checked = true;
      form.querySelector("#deadline-field").hidden = !s.rsvp;
      form.querySelector("#invited-helper").textContent = invitedHelper(s.rsvp);
      form.querySelectorAll(".suggestion").forEach((b) => b.setAttribute("aria-pressed", String(b === button)));
      break;
    }
    case "step": {
      const form = main.querySelector("#event-form");
      const to = button.dataset.to;
      if (to === "next") nextStep(form);
      else {
        markErrors(form, {});
        showStep(form, to === "back" ? Number(form.dataset.current) - 1 : Number(to));
      }
      break;
    }
    case "publish":
    case "unpublish":
      await run(async () => {
        await data.saveEvent(param, { status: button.dataset.action === "publish" ? "published" : "draft" });
        render({ keepScroll: true });
        if (button.dataset.action === "publish") note("Published. Your guests can now see it on their invite.");
      });
      break;
    case "delete-event":
      if (name === "event" && confirm("Delete this event? Guests’ replies to it are deleted too.")) {
        await run(async () => { await data.deleteEvent(param); location.hash = "#/events"; });
      }
      break;
    case "delete-guest":
      if (confirm("Remove this guest? Their invite link stops working, and their replies are deleted.")) {
        await run(async () => { await data.deleteGuest(param); location.hash = "#/guests"; });
      }
      break;
    case "delete-item":
      if (confirm("Remove this from your registry? Guests won’t see it any more.")) {
        await run(async () => { await data.deleteItem(param); location.hash = "#/registry"; });
      }
      break;
    case "starter-tasks":
      await run(async () => { await data.addTasks(starterList()); render({ keepScroll: true }); });
      break;
    case "delete-task":
      await run(async () => { await data.deleteTask(button.dataset.id); render({ keepScroll: true }); });
      break;
    case "delete-vendor":
      if (confirm("Remove this vendor and their details?")) {
        await run(async () => { const back = main.querySelector("#vendor-form")?.dataset.back ?? "#/planning";
        await data.deleteVendor(param); go(back, "Vendor removed."); });
      }
      break;
    case "delete-link":
      await run(async () => { await data.deleteLink(button.dataset.id); render({ keepScroll: true }); });
      break;
  }
});

// ---------- Staying up to date ----------

/** True when the couple has typed something that a refresh would wipe out. */
function editing() {
  return [...main.querySelectorAll("input, textarea, select")].some((el) => {
    if (el.type === "checkbox" || el.type === "radio") return el.checked !== el.defaultChecked;
    if (el.tagName === "SELECT") return [...el.options].some((o) => o.selected !== o.defaultSelected);
    if (el.type === "file") return el.files.length > 0;
    return el.value !== el.defaultValue;
  }) || main.contains(document.activeElement) && /INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)
    || Boolean(main.querySelector(".moving")); // moving the countdown photo
}

/** Brings in new RSVPs, questions and gifts from guests, like the app's 30-second check. */
async function refresh() {
  if (!data.signedIn() || !state.wedding || document.hidden || editing()) return;
  try {
    await data.load();
    if (!editing()) render({ keepScroll: true });
  } catch (error) {
    if (error instanceof SignedOut) render();
  }
}

async function start() {
  main.innerHTML = '<p class="secondary center" role="status">Loading…</p>';
  // Back from the password-reset email: Supabase puts the sign-in (or an error) after "#".
  const link = new URLSearchParams(location.hash.slice(1));
  let linkProblem = null;
  if (link.get("type") === "recovery" && link.get("access_token")) {
    history.replaceState(null, "", "#/new-password");
    try { await data.signInFromLink(link); } catch (error) { linkProblem = error.message; }
  } else if (link.get("error_description")) {
    history.replaceState(null, "", "#/signin");
    linkProblem = link.get("error_code") === "otp_expired"
      ? "That link has expired or was already used. Ask for a new one with “Forgot password?”."
      : link.get("error_description").replace(/\+/g, " ");
  }
  if (data.signedIn()) {
    try {
      await data.load();
    } catch (error) {
      if (!(error instanceof SignedOut)) {
        main.innerHTML = `
          <header class="stack center">
            <h1 class="title1">Something went wrong</h1>
            <p class="secondary">We couldn’t load your wedding. Check your connection and try again.</p>
          </header>
          <button class="button primary" onclick="location.reload()">Try again</button>`;
        return;
      }
    }
  }
  window.addEventListener("hashchange", () => render());
  setInterval(refresh, 30_000);
  document.addEventListener("visibilitychange", refresh);
  render();
  if (linkProblem) go("#/signin", linkProblem);
}

start();
