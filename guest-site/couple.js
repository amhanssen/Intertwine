// Intertwine for couples: the couple side of the app as a website, so couples can plan
// from any phone or computer without installing the app. Same account, same wedding.
// Pages follow the app's couple tabs (Home, Events, Guests, Registry). Each page is a
// function that returns HTML; the address after "#" picks the page.

import { data, state, inviteLink, SignedOut } from "./couple-data.js";

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
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m13.5 6.5 4 4"/>',
  link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
  rings: '<circle cx="9" cy="13" r="5"/><circle cx="15" cy="13" r="5"/>',
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

// ---------- Pages ----------

const pages = {
  // Home: the countdown, what needs attention and the next event (app: Home tab).
  home() {
    const w = state.wedding;
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
        <a class="avatar" href="#/wedding" aria-label="Wedding details">${w.photo_url ? `<img src="${esc(w.photo_url)}" alt="">` : icon(icons.rings, 22)}</a>
      </header>
      <div class="stats">
        <div class="stat hero" ${w.photo_url ? `style="background-image:url('${esc(w.photo_url)}')"` : ""}>
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
      </section>
      ${e.status === "published" ? '<button class="button tertiary" type="button" data-action="unpublish">Hide from guests (back to draft)</button>' : ""}
      <button class="button tertiary danger" type="button" data-action="delete-event">Delete event</button>`;
  },

  // Add or change an event (app: Create event flow, all steps on one page).
  edit(id) {
    const isNew = id === "new";
    const e = isNew ? { type: "Welcome Party", name: "", dress_code: "Cocktail attire", rsvp_required: true } : data.event(id);
    if (!e) return notFound();
    return `
      ${back(isNew ? "#/events" : `#/event/${e.id}`, isNew ? "Events" : e.name)}
      ${header(isNew ? "New event" : "Edit event")}
      <form class="stack-lg" id="event-form" data-id="${isNew ? "" : e.id}">
        <h2 class="title3">Basics</h2>
        ${field("type", "Type of event", `<select id="type" name="type">${options(eventTypes, e.type)}</select>`)}
        ${field("name", "Event name", `<input id="name" name="name" value="${esc(e.name)}" placeholder="Event name" required>`)}
        ${field("welcome", "Welcome message (optional)", `<textarea id="welcome" name="welcome" placeholder="A short note to your guests">${esc(e.welcome_message)}</textarea>`)}
        ${field("photo", "Photo (optional)", '<input id="photo" name="photo" type="file" accept="image/*">', e.photo_url ? "This event has a photo. Pick another to replace it." : "")}

        <h2 class="title3">Date & place</h2>
        ${field("day", "Date", `<input id="day" name="day" type="date" value="${esc(e.day)}">`)}
        <div class="two-up">
          ${field("start", "Starts", `<input id="start" name="start" type="time" value="${esc(e.start_time?.slice(0, 5))}">`)}
          ${field("end", "Ends (optional)", `<input id="end" name="end" type="time" value="${esc(e.end_time?.slice(0, 5))}">`)}
        </div>
        ${field("venue", "Venue", `<input id="venue" name="venue" value="${esc(e.venue)}" placeholder="Name of the venue">`)}
        ${field("directions", "Directions (optional)", `<textarea id="directions" name="directions" placeholder="How to find it and where to park">${esc(e.directions)}</textarea>`)}

        <h2 class="title3">Dress code & RSVP</h2>
        ${field("dress", "Dress code", `<select id="dress" name="dress">${options(dressCodes, e.dress_code)}</select>`)}
        ${field("guidance", "Tips for guests (optional)", `<textarea id="guidance" name="guidance" placeholder="Anything guests should know about what to wear">${esc(e.dress_guidance)}</textarea>`)}
        <label class="check"><input type="checkbox" name="rsvp" ${e.rsvp_required ? "checked" : ""}><span>Guests need to RSVP</span></label>
        ${field("deadline", "Reply by (optional)", `<input id="deadline" name="deadline" type="date" value="${esc(e.rsvp_deadline)}">`)}

        <button class="button primary" type="submit">${isNew ? "Save event" : "Save changes"}</button>
        ${isNew ? '<p class="footnote tertiary center">New events start as drafts. Guests see them once you publish.</p>' : ""}
      </form>`;
  },

  // Guests (app: Guests tab).
  guests() {
    const people = state.guests.reduce((sum, g) => sum + g.party_size, 0);
    return `
      ${header("Guests", state.guests.length ? `${count(state.guests.length, "invitation")} · up to ${count(people, "person", "people")}` : "Everyone you’re inviting")}
      <form class="panel stack-sm" id="guest-form">
        <h2 class="headline">Add a guest</h2>
        <div class="two-up wide-first">
          ${field("guest-name", "Name", '<input id="guest-name" name="name" placeholder="Guest’s full name" required>')}
          ${field("party", "Party size", '<input id="party" name="party" type="number" min="1" max="20" value="1" required>', "Including plus-ones")}
        </div>
        <button class="button primary" type="submit">Add guest</button>
      </form>
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
      ${w.photo_url ? `<img class="cover couple-photo" src="${esc(w.photo_url)}" alt="Your photo">` : ""}
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

const tabs = { home: "home", questions: "home", wedding: "home", events: "events", event: "events", edit: "events",
  guests: "guests", guest: "guests", registry: "registry", item: "registry" };

function route() {
  const [path, param] = location.hash.replace(/^#\/?/, "").split("/");
  return { name: path || "home", param };
}

function render({ keepScroll = false } = {}) {
  const { name, param } = route();
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
    main.innerHTML = (pages[name] ?? notFound)(param);
    const tab = tabs[name] ?? "home";
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
    const photo = fields.get("photo");
    const rsvp = fields.get("rsvp") === "on";
    let id = form.dataset.id;
    if (await busy(form, "Saving…", async () => {
      id = await data.saveEvent(id || null, {
        type: text(fields, "type"), name: text(fields, "name"), welcome_message: text(fields, "welcome"),
        day: optionalDate(fields, "day"), start_time: optionalDate(fields, "start"), end_time: optionalDate(fields, "end"),
        venue: text(fields, "venue"), directions: text(fields, "directions"),
        dress_code: text(fields, "dress"), dress_guidance: text(fields, "guidance"),
        rsvp_required: rsvp, rsvp_deadline: rsvp ? optionalDate(fields, "deadline") : null,
      }, photo?.size ? photo : null);
    })) { location.hash = `#/event/${id}`; }
  }

  if (form.id === "guest-form") {
    if (await busy(form, "Adding…", () => data.addGuest(text(fields, "name"), Number(fields.get("party")) || 1))) {
      render({ keepScroll: true });
      main.querySelector("#guest-name").focus();
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
  if (target.name === "type") {
    // Name a new event after its type until the couple types their own name.
    const name = main.querySelector("#name");
    if (!name.value || eventTypes.includes(name.value)) name.value = target.value === "Other" ? "" : target.value;
  }
  if (target.dataset.action === "thank-you") {
    target.disabled = true;
    try { await data.thankYou(target.dataset.id, target.checked); render({ keepScroll: true }); }
    catch (error) { target.checked = !target.checked; target.disabled = false; showError(target.closest("section"), error); }
  }
});

// Buttons that aren't part of a form.
main.addEventListener("click", async (e) => {
  const button = e.target.closest("[data-action]");
  if (!button || button.type === "checkbox") return;
  const { name, param } = route();
  const run = async (work) => {
    button.disabled = true;
    try { await work(); } catch (error) { button.disabled = false; showError(main, error); }
  };

  switch (button.dataset.action) {
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
  }) || main.contains(document.activeElement) && /INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName);
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
