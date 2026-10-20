// Intertwine guest site: the guest side of the app as a website.
// Pages follow the Figma guest screens (GH Home, GS Schedule, GW What to Wear, GD Details).
// Each page is a function that returns HTML; the address after "#" picks the page.

import { data } from "./data.js";

const main = document.querySelector("main");

// ---------- Formatting (matches Format.swift in the app) ----------

const toDate = (day, time = "12:00") => new Date(`${day}T${time}:00`);

const fmt = (day, options) => new Intl.DateTimeFormat("en-US", options).format(toDate(day));
const dayShort = (day) => fmt(day, { weekday: "short", month: "short", day: "numeric" });
const dayLong = (day) => fmt(day, { weekday: "short", month: "short", day: "numeric", year: "numeric" });

function time(t) {
  const [h, m] = t.split(":").map(Number);
  const hour = h % 12 || 12;
  return m ? `${hour}:${String(m).padStart(2, "0")}` : `${hour}`;
}
const meridiem = (t) => (Number(t.split(":")[0]) < 12 ? "AM" : "PM");

/** "6–8 PM", or "11 AM–1 PM" when the halves of the day differ. */
function timeRange(event) {
  if (!event.start) return "Time to be announced";
  if (!event.end) return `${time(event.start)} ${meridiem(event.start)}`;
  const same = meridiem(event.start) === meridiem(event.end);
  return same
    ? `${time(event.start)}–${time(event.end)} ${meridiem(event.end)}`
    : `${time(event.start)} ${meridiem(event.start)}–${time(event.end)} ${meridiem(event.end)}`;
}
const when = (event) => `${dayShort(event.day)} · ${timeRange(event)}`;

/** Escapes text a guest typed before it goes into the page. */
const esc = (text) =>
  String(text).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

const couple = () => data.wedding().coupleNames;
const firstName = () => data.guest().name.split(" ")[0];

// ---------- Icons (simple line icons, like SF Symbols in the app) ----------

const icon = (path, size = 24) =>
  `<svg class="icon" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${path}</svg>`;

const icons = {
  home: '<path d="M3 11.5 12 4l9 7.5"/><path d="M5.5 9.5V20h13V9.5"/><path d="M10 20v-5h4v5"/>',
  calendar: '<rect x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
  hanger: '<path d="M12 7.5a2 2 0 1 1 2-2"/><path d="M12 7.5v1.5L3.5 15.5a1.4 1.4 0 0 0 .9 2.5h15.2a1.4 1.4 0 0 0 .9-2.5L12 9"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5.5M12 7.5v.5"/>',
  gift: '<rect x="3.5" y="8" width="17" height="4" rx="1"/><path d="M5 12v8h14v-8M12 8v12"/><path d="M12 8C10.5 4.5 7 4.5 7 6.5S10 8 12 8c2 0 5 .5 5-1.5S13.5 4.5 12 8Z"/>',
  chat: '<path d="M4 5.5h16v10H9l-4 3.5v-3.5H4z"/>',
  chevron: '<path d="m9 6 6 6-6 6"/>',
  back: '<path d="m15 6-6 6 6 6"/>',
  map: '<path d="M9 4 3.5 6v14L9 18l6 2 5.5-2V4L15 6 9 4Z"/><path d="M9 4v14M15 6v14"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
  bed: '<path d="M3 18v-9M3 14h18v4M21 14v-2.5a2.5 2.5 0 0 0-2.5-2.5H11v5"/><circle cx="7" cy="11.5" r="1.6"/>',
};

const chevron = `<span class="chevron">${icon(icons.chevron, 18)}</span>`;

// ---------- Shared pieces (match DesignSystem/Components.swift) ----------

function badgeFor(event) {
  if (!event.rsvpRequired) return '<span class="badge info">No RSVP needed</span>';
  const reply = data.rsvp(event.id);
  if (!reply) return '<span class="badge reply">Reply needed</span>';
  return reply.attending ? '<span class="badge attending">Attending</span>' : '<span class="badge declined">Can’t go</span>';
}

function eventCard(event, { date = when(event) } = {}) {
  return `
    <a class="card event-card" href="#/event/${event.id}">
      <div class="top">
        ${event.photo ? `<img class="thumb" src="${esc(event.photo)}" alt="" loading="lazy">` : '<span class="thumb" aria-hidden="true"></span>'}
        <div class="stack" style="gap:2px">
          <span class="title3">${esc(event.name)}</span>
          <span class="subheadline secondary">${date}</span>
          <span class="subheadline secondary">${esc(event.venue)}</span>
        </div>
      </div>
      <div class="bottom">${badgeFor(event)}<span class="footnote secondary">${esc(event.dressCode)}</span></div>
    </a>`;
}

function row({ href, title, subtitle, iconPath }) {
  return `
    <a class="row" href="${href}">
      ${iconPath ? icon(iconPath) : ""}
      <span class="text"><span class="headline">${title}</span>${subtitle ? `<span class="subheadline secondary">${subtitle}</span>` : ""}</span>
      ${chevron}
    </a>`;
}

const back = (href, label) => `<a class="back" href="${href}">${icon(icons.back, 20)}${label}</a>`;

const isApple = /iPhone|iPad|iPod|Macintosh/.test(navigator.userAgent);
/** Opens the place in Apple Maps on Apple devices and Google Maps everywhere else. */
const mapsLink = (place) => isApple
  ? `https://maps.apple.com/?q=${encodeURIComponent(place)}`
  : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(place)}`;

const money = (n) => `$${Number(n).toLocaleString("en-US")}`;

/** "Add to calendar" for an event: a calendar file (Apple, Outlook) and a Google Calendar link. */
function calendarButtons(event) {
  if (!event.day || !event.start) return "";
  return `
    <div class="button-row">
      <a class="button secondary" href="${calendarFile(event)}" download="${esc(event.name)}.ics">${icon(icons.calendar, 20)}Add to calendar</a>
      <a class="button tertiary" href="${googleCalendarLink(event)}" target="_blank" rel="noopener">Google Calendar</a>
    </div>`;
}

const needsReply = () => data.events().filter((e) => e.rsvpRequired && !data.rsvp(e.id));

const nextEvent = () => {
  const now = new Date();
  const events = data.events();
  return events.find((e) => toDate(e.day, e.start) >= now) ?? events.at(-1);
};

// ---------- Pages ----------

const pages = {
  // GH1 · Home
  home() {
    const due = needsReply()[0];
    const next = nextEvent();
    return `
      <header class="screen-header">
        <div class="stack">
          <span class="footnote secondary">${esc(couple())} · ${dayLong(data.wedding().date)}</span>
          <h1 class="large-title">Welcome, ${esc(firstName())}</h1>
        </div>
      </header>

      ${due ? `
        <section class="panel accent" aria-label="RSVP needed">
          <span class="title3">Please reply by ${dayShort(due.rsvpDeadline)}</span>
          <p class="subheadline">${esc(couple())} are waiting on your RSVP for the ${esc(due.name)}.</p>
          <a class="button primary" href="#/rsvp/${due.id}">RSVP now</a>
        </section>` : ""}

      ${next ? `
        <section class="stack">
          <h2 class="title3">Your next event</h2>
          ${eventCard(next)}
        </section>` : ""}

      ${data.updates().length ? `
      <section class="stack">
        <h2 class="title3">Updates from ${esc(couple())}</h2>
        <div class="row-group">
          ${data.updates().map((u) => `
            <div class="row"><span class="text"><span class="headline">${esc(u.title)}</span><span class="subheadline secondary">${esc(u.detail)}</span></span></div>`).join("")}
        </div>
      </section>` : ""}

      ${!next ? `
      <section class="panel accent">
        <span class="title3">More soon</span>
        <p class="subheadline">${esc(couple())} haven’t shared any events yet. Check back here for the schedule.</p>
      </section>` : ""}

      <div class="row-group">
        ${row({ href: "#/registry", title: "Registry", subtitle: `Browse ${esc(couple())}’s gift list` })}
        ${row({ href: "#/ask", title: "Have a question?", subtitle: `Ask ${esc(couple())} directly` })}
      </div>`;
  },

  // GS1 · Schedule
  schedule() {
    const byDay = new Map();
    for (const e of data.events()) byDay.set(e.day, [...(byDay.get(e.day) ?? []), e]);
    return `
      <header class="stack">
        <h1 class="large-title">Schedule</h1>
        <p class="subheadline secondary">Every event you’re invited to, in order.</p>
      </header>
      ${[...byDay].map(([day, events]) => `
        <section class="stack">
          <h2 class="title3">${dayLong(day)}</h2>
          ${events.map((e) => eventCard(e, { date: timeRange(e) })).join("")}
        </section>`).join("")}`;
  },

  // GS2 · Event (and GS3 once the guest has replied)
  event(id) {
    const event = data.event(id);
    if (!event) return notFound();
    const reply = data.rsvp(id);
    return `
      ${back("#/schedule", "Schedule")}
      ${event.photo ? `<img class="cover" src="${esc(event.photo)}" alt="">` : ""}
      <header class="stack">
        <h1 class="title1">${esc(event.name)}</h1>
        <span class="headline secondary">${when(event)}</span>
        ${event.welcomeMessage ? `<p>${esc(event.welcomeMessage)}</p>` : ""}
      </header>

      ${event.rsvpRequired ? (reply ? `
        <section class="panel">
          <div>${badgeFor(event)}</div>
          <span class="title3">${reply.attending ? `You’re going${reply.partyCount > 1 ? ` · ${reply.partyCount} people` : ""}` : "You can’t make it"}</span>
          ${reply.note ? `<p class="subheadline secondary">Your note: “${esc(reply.note)}”</p>` : ""}
          <a class="button secondary" href="#/rsvp/${id}">Change RSVP</a>
        </section>` : `
        <section class="panel">
          <span class="title3">Please reply by ${dayShort(event.rsvpDeadline)}</span>
          <p class="subheadline secondary">You’re invited · RSVP required</p>
          <a class="button primary" href="#/rsvp/${id}">RSVP</a>
        </section>`) : ""}

      <section class="panel">
        <h2 class="title3">Where</h2>
        <p>${esc(event.venue)}</p>
        ${event.directions ? `<p class="subheadline secondary">${esc(event.directions)}</p>` : ""}
        ${event.venue ? `<a class="link-button" href="${mapsLink(event.venue)}" target="_blank" rel="noopener">Get directions</a>` : ""}
      </section>

      ${reply?.attending || !event.rsvpRequired ? calendarButtons(event) : ""}

      <section class="panel">
        <h2 class="title3">What to wear</h2>
        <p>${esc(event.dressCode)}</p>
        ${event.dressGuidance ? `<p class="subheadline secondary">${esc(event.dressGuidance)}</p>` : ""}
      </section>

      <div class="row-group">
        ${row({ href: `#/ask/${id}`, title: "Have a question?", subtitle: `Ask ${esc(couple())}`, iconPath: icons.chat })}
      </div>`;
  },

  // GH2 · RSVP
  rsvp(id) {
    const event = data.event(id);
    if (!event) return notFound();
    const reply = data.rsvp(id);
    const guest = data.guest();
    const attending = reply ? reply.attending : true;
    const counts = Array.from({ length: guest.partySize }, (_, i) => i + 1);
    return `
      ${back(`#/event/${id}`, event.name)}
      <header class="stack">
        <h1 class="title1">Will you be at the ${esc(event.name)}?</h1>
        <p class="subheadline secondary">${when(event)} · ${esc(event.venue)}</p>
      </header>
      <form class="stack-lg" id="rsvp-form">
        <fieldset class="segmented" style="border:0;margin:0">
          <legend class="visually-hidden">Will you be there?</legend>
          <label><input type="radio" name="attending" value="yes" ${attending ? "checked" : ""}><span>Yes, I’ll be there</span></label>
          <label><input type="radio" name="attending" value="no" ${attending ? "" : "checked"}><span>Can’t make it</span></label>
        </fieldset>
        <div class="field">
          <span class="label">Your name</span>
          <input value="${esc(guest.name)}" readonly aria-label="Your name">
        </div>
        <div class="field" id="party-field" ${attending ? "" : "hidden"}>
          <label for="party">Who’s coming with you?</label>
          <select id="party" name="party">
            ${counts.map((n) => `<option value="${n}" ${reply?.partyCount === n ? "selected" : ""}>${n === 1 ? "Just me" : `${n} people, including me`}</option>`).join("")}
          </select>
          <span class="helper">Your invitation is for ${guest.partySize} ${guest.partySize === 1 ? "guest" : "guests"}</span>
        </div>
        <div class="field">
          <label for="note">Note for ${esc(couple())} (optional)</label>
          <textarea id="note" name="note" placeholder="Can’t wait to celebrate!">${esc(reply?.note ?? "")}</textarea>
        </div>
        <div class="panel accent"><p class="subheadline">Dress code: ${esc(event.dressCode)}${event.dressGuidance ? ` — ${esc(event.dressGuidance)}` : ""}</p></div>
        <button class="button primary" type="submit">Send RSVP</button>
      </form>`;
  },

  // GH3 · RSVP sent
  sent(id) {
    const event = data.event(id);
    const reply = event && data.rsvp(id);
    if (!reply) return notFound();
    return `
      <div class="success" aria-hidden="true">${icon(icons.check, 36)}</div>
      <header class="stack center">
        <h1 class="title1">${reply.attending ? `You’re going, ${esc(firstName())}!` : `Thanks for letting them know, ${esc(firstName())}`}</h1>
        <p class="secondary">${reply.attending ? `${esc(couple())} will see your reply right away.` : `${esc(couple())} will miss you.`}</p>
      </header>
      ${eventCard(event)}
      ${reply.attending ? calendarButtons(event) : ""}
      <a class="button tertiary" href="#/schedule">Back to schedule</a>`;
  },

  // GW1 · Dress codes
  wear() {
    return `
      <header class="stack">
        <h1 class="large-title">What to Wear</h1>
        <p class="subheadline secondary">Dress codes for every event you’re invited to</p>
      </header>
      ${data.events().map((e) => `
        <a class="panel" href="#/event/${e.id}" style="text-decoration:none">
          <span class="footnote secondary">${dayLong(e.day)} · ${esc(e.name)}</span>
          <span class="title3">${esc(e.dressCode)}</span>
          ${e.dressGuidance ? `<span class="subheadline secondary">${esc(e.dressGuidance)}</span>` : ""}
        </a>`).join("")}`;
  },

  // GD1 · Wedding details
  details() {
    const w = data.wedding();
    return `
      <header class="stack">
        <h1 class="large-title">Details</h1>
        <p class="subheadline secondary">${esc(couple())} · ${dayLong(w.date)}</p>
      </header>
      ${w.photo ? `<img class="cover couple-photo" src="${esc(w.photo)}" alt="${esc(couple())}">` : ""}
      ${w.venue || w.hotelInfo ? `
      <section class="panel">
        <h2 class="title3">Where to stay</h2>
        ${w.venue ? `<p class="headline">${esc(w.venue)}</p>` : ""}
        ${w.hotelInfo ? `<p class="subheadline secondary">${esc(w.hotelInfo)}</p>` : ""}
      </section>` : ""}
      ${w.venue || w.parkingInfo ? `
      <section class="panel">
        <h2 class="title3">Getting there</h2>
        ${w.parkingInfo ? `<p class="subheadline secondary">${esc(w.parkingInfo)}</p>` : ""}
        ${w.venue ? `<a class="link-button" href="${mapsLink(w.venue)}" target="_blank" rel="noopener">Get directions</a>` : ""}
      </section>` : ""}
      <div class="row-group">
        ${row({ href: "#/registry", title: "Registry", subtitle: `Browse ${esc(couple())}’s gift list`, iconPath: icons.gift })}
        ${row({ href: "#/ask", title: `Ask ${esc(couple())}`, subtitle: "Send the couple a question", iconPath: icons.chat })}
      </div>
      ${data.isDemo() ? `<p class="footnote tertiary center">This is a sample wedding everyone can try. <button class="link-button footnote" id="reset" style="display:inline;width:auto;padding:0">Start the demo over</button></p>` : ""}`;
  },

  // GD2 · Registry
  registry(tab = "gifts") {
    const items = data.registry().filter((i) => (tab === "funds" ? i.fund : !i.fund));
    const links = data.registryLinks();
    return `
      ${back("#/details", "Details")}
      <header class="stack">
        <h1 class="title1">Registry</h1>
        <p class="subheadline secondary">Gifts for ${esc(couple())}</p>
      </header>
      <nav class="segmented" aria-label="Registry sections">
        <label><input type="radio" name="tab" value="gifts" ${tab === "gifts" ? "checked" : ""} data-href="#/registry"><span>Gifts</span></label>
        <label><input type="radio" name="tab" value="funds" ${tab === "funds" ? "checked" : ""} data-href="#/registry/funds"><span>Cash funds</span></label>
      </nav>
      <div class="row-group">
        ${items.length ? items.map((i) => row({ href: `#/gift/${i.id}`, title: esc(i.name), subtitle: giftStatus(i) })).join("")
          : `<div class="row"><span class="text subheadline secondary">${tab === "funds" ? "No cash funds yet." : "No gifts here yet."}</span></div>`}
      </div>
      ${links.length ? `
        <section class="stack">
          <h2 class="title3">Also on</h2>
          <div class="row-group">
            ${links.map((l) => `
              <a class="row" href="${esc(safeLink(l.url))}" target="_blank" rel="noopener">
                <span class="text"><span class="headline">${esc(l.name)}</span><span class="subheadline secondary">Opens the store’s website</span></span>
                ${chevron}
              </a>`).join("")}
          </div>
        </section>` : ""}`;
  },

  // A gift or cash fund: "I'll get this", or give toward the fund.
  gift(id) {
    const item = data.registry().find((i) => i.id === id);
    if (!item) return notFound();
    const backTo = back(item.fund ? "#/registry/funds" : "#/registry", "Registry");
    const header = `
      <header class="stack">
        <h1 class="title1">${esc(item.name)}</h1>
        <span class="headline secondary">${item.fund ? `${money(item.raised)} of ${money(item.price)}` : money(item.price)}</span>
        ${item.note ? `<p>${esc(item.note)}</p>` : ""}
      </header>`;
    const howItWorks = `<p class="footnote tertiary">Intertwine doesn’t take payments. This lets ${esc(couple())} know, so nobody gives the same thing twice.</p>`;

    if (item.fund) {
      const pct = item.price > 0 ? Math.min(100, Math.round((item.raised / item.price) * 100)) : 0;
      const choices = [25, 50, 100, 250];
      return `
        ${backTo}
        ${header}
        <div class="progress" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${pct}" aria-label="${pct}% of the goal"><span style="width:${pct}%"></span></div>
        ${item.mine ? `
          <section class="panel accent">
            <span class="title3">You’re giving ${money(item.mine.amount)}</span>
            ${item.mine.note ? `<p class="subheadline">Your note: “${esc(item.mine.note)}”</p>` : ""}
            <p class="subheadline">You can change the amount below.</p>
          </section>` : ""}
        <form class="stack-lg" id="give-form" data-item="${item.id}">
          <fieldset class="chips" style="border:0;margin:0;padding:0">
            <legend class="label footnote secondary" style="margin-bottom:var(--space-xs)">How much would you like to give?</legend>
            ${choices.map((n, i) => `<label><input type="radio" name="preset" value="${n}" ${(item.mine ? item.mine.amount === n : i === 1) ? "checked" : ""}><span>${money(n)}</span></label>`).join("")}
            <label><input type="radio" name="preset" value="other" ${item.mine && !choices.includes(item.mine.amount) ? "checked" : ""}><span>Other</span></label>
          </fieldset>
          <div class="field" id="other-field" ${item.mine && !choices.includes(item.mine.amount) ? "" : "hidden"}>
            <label for="other">Amount ($)</label>
            <input id="other" name="other" type="number" inputmode="numeric" min="1" max="100000" step="1" value="${item.mine?.amount ?? ""}">
          </div>
          <div class="field">
            <label for="note">Note for ${esc(couple())} (optional)</label>
            <textarea id="note" name="note" maxlength="500" placeholder="Have the best trip!">${esc(item.mine?.note ?? "")}</textarea>
          </div>
          <button class="button primary" type="submit">${item.mine ? "Update my gift" : "Give to this fund"}</button>
          ${item.mine ? `<button class="button tertiary" type="button" id="ungive" data-item="${item.id}">Take back my gift</button>` : ""}
        </form>
        ${howItWorks}`;
    }

    const store = item.link ? `<a class="button secondary" href="${esc(safeLink(item.link))}" target="_blank" rel="noopener">View in store</a>` : "";
    if (item.mine) {
      return `
        ${backTo}
        ${header}
        <section class="panel accent">
          <span class="title3">You’re getting this</span>
          <p class="subheadline">${esc(couple())} can see that it’s taken, so nobody else buys it.</p>
        </section>
        ${store}
        <button class="button tertiary" type="button" id="ungive" data-item="${item.id}">I won’t get this after all</button>`;
    }
    if (item.taken) {
      return `
        ${backTo}
        ${header}
        <section class="panel"><span class="badge info" style="align-self:flex-start">Already bought</span>
          <p class="subheadline secondary">Someone already got this one. <a href="#/registry">See what’s still available</a>.</p></section>`;
    }
    return `
      ${backTo}
      ${header}
      ${store}
      <form class="stack-lg" id="give-form" data-item="${item.id}">
        <div class="field">
          <label for="note">Note for ${esc(couple())} (optional)</label>
          <textarea id="note" name="note" maxlength="500" placeholder="Congratulations!"></textarea>
        </div>
        <button class="button primary" type="submit">I’ll get this</button>
      </form>
      ${howItWorks}`;
  },

  // GD3 · Ask the couple
  ask(eventId) {
    const mine = data.questions();
    return `
      ${back(eventId ? `#/event/${eventId}` : "#/details", eventId ? data.event(eventId)?.name ?? "Back" : "Details")}
      <header class="stack">
        <h1 class="title1">Ask ${esc(couple())}</h1>
        <p class="subheadline secondary">They’ll answer here, so you don’t have to text them.</p>
      </header>
      <form class="stack-lg" id="ask-form">
        <div class="field">
          <label for="about">About</label>
          <select id="about" name="about">
            <option value="">The wedding in general</option>
            ${data.events().map((e) => `<option value="${e.id}" ${e.id === eventId ? "selected" : ""}>${esc(e.name)}</option>`).join("")}
          </select>
        </div>
        <div class="field">
          <label for="question">Your question</label>
          <textarea id="question" name="question" placeholder="Is there parking at the hotel?" required></textarea>
        </div>
        <button class="button primary" type="submit">Send question</button>
      </form>
      ${mine.length ? `
        <section class="stack">
          <h2 class="title3">Your questions</h2>
          <div class="row-group">
            ${mine.map((q) => `
              <div class="row"><span class="text">
                <span class="headline">${esc(q.text)}</span>
                <span class="subheadline secondary">${q.answer ? esc(q.answer) : "Waiting for an answer"}</span>
              </span></div>`).join("")}
          </div>
        </section>` : ""}`;
  },
};

/** "$180 · Available", "$449 · Already bought", "You’re getting this" or "$1,240 of $3,000" (Figma GD2). */
function giftStatus(item) {
  if (item.fund) return `${money(item.raised)} of ${money(item.price)}${item.mine ? " · You gave" : ""}`;
  if (item.mine) return `${money(item.price)} · You’re getting this`;
  return `${money(item.price)} · ${item.taken ? "Already bought" : "Available"}`;
}

/** Only web links, so a typed link can't run code. */
function safeLink(url) {
  const full = /^[a-z]+:\/\//i.test(url) ? url : `https://${url}`;
  return /^https?:\/\//i.test(full) ? full : "#";
}

function notFound() {
  return `
    <header class="stack">
      <h1 class="title1">This page isn’t here</h1>
      <p class="secondary">It may have moved or been removed.</p>
    </header>
    <a class="button primary" href="#/home">Go to Home</a>`;
}

/** Calendar files need commas, semicolons and line breaks escaped. */
const icsText = (text) => String(text ?? "").replace(/[\\;,]/g, (c) => `\\${c}`).replace(/\n/g, "\\n");

/** A calendar file for the event, so guests can add it to Apple, Google or Outlook calendars. */
function calendarFile(event) {
  const stamp = (day, t) => `${day.replaceAll("-", "")}T${t.replace(":", "")}00`;
  const ics = [
    "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Intertwine//Guest site//EN", "BEGIN:VEVENT",
    `UID:${event.id}@intertwine`,
    `DTSTART:${stamp(event.day, event.start)}`,
    `DTEND:${stamp(event.day, event.end ?? event.start)}`,
    `DTSTAMP:${new Date().toISOString().replace(/[-:]/g, "").slice(0, 15)}Z`,
    `SUMMARY:${icsText(`${event.name} · ${couple()}`)}`,
    `LOCATION:${icsText(event.venue)}`,
    `DESCRIPTION:${icsText(`Dress code: ${event.dressCode}`)}`,
    "END:VEVENT", "END:VCALENDAR",
  ].join("\r\n");
  return `data:text/calendar;charset=utf-8,${encodeURIComponent(ics)}`;
}

function googleCalendarLink(event) {
  const stamp = (day, t) => `${day.replaceAll("-", "")}T${t.replace(":", "")}00`;
  const params = new URLSearchParams({
    action: "TEMPLATE",
    text: `${event.name} · ${couple()}`,
    dates: `${stamp(event.day, event.start)}/${stamp(event.day, event.end ?? event.start)}`,
    location: event.venue,
    details: `Dress code: ${event.dressCode}`,
  });
  return `https://calendar.google.com/calendar/render?${params}`;
}

// ---------- Routing ----------

const tabs = { home: "home", schedule: "schedule", event: "schedule", rsvp: "schedule", sent: "schedule", wear: "wear", details: "details", registry: "details", gift: "details", ask: "details" };
const titles = { home: "Home", schedule: "Schedule", wear: "What to Wear", details: "Details", registry: "Registry", ask: "Ask the couple" };

function render() {
  const [path, param] = location.hash.replace(/^#\/?/, "").split("/");
  const name = path || "home";
  const page = pages[name] ?? notFound;
  main.innerHTML = page(param);

  const tab = tabs[name] ?? "home";
  document.querySelectorAll(".tabbar a[data-tab]").forEach((a) => {
    if (a.dataset.tab === tab) a.setAttribute("aria-current", "page");
    else a.removeAttribute("aria-current");
  });
  const giftName = name === "gift" ? data.registry().find((i) => i.id === param)?.name : null;
  document.title = `${titles[name] ?? giftName ?? data.event(param)?.name ?? "Intertwine"} · ${couple()}’s wedding`;
  window.scrollTo(0, 0);
  // After moving to another page, focus its heading so screen readers announce it.
  const heading = main.querySelector("h1");
  if (heading && location.hash) {
    heading.setAttribute("tabindex", "-1");
    heading.focus({ preventScroll: true });
  }
}

/** Disables a form's button and shows progress while something is saved. */
async function busy(form, label, work) {
  const button = form.querySelector("button[type=submit]");
  const original = button.textContent;
  button.disabled = true;
  button.textContent = label;
  try {
    await work();
    return true;
  } catch {
    button.disabled = false;
    button.textContent = original;
    form.insertAdjacentHTML("beforeend",
      '<p class="panel warning subheadline" role="alert">That didn’t go through. Check your connection and try again.</p>');
    return false;
  }
}

// Form and button handling, in one place so pages stay plain HTML.
main.addEventListener("submit", async (e) => {
  e.preventDefault();
  const form = e.target;
  const fields = new FormData(form);
  if (form.id === "rsvp-form") {
    const id = location.hash.split("/")[2];
    const sent = await busy(form, "Sending…", () => data.sendRSVP(id, {
      attending: fields.get("attending") === "yes",
      partyCount: Number(fields.get("party") ?? 1),
      note: String(fields.get("note") ?? "").trim(),
    }));
    if (sent) location.hash = `#/sent/${id}`;
  }
  if (form.id === "give-form") {
    const item = form.dataset.item;
    const preset = fields.get("preset");
    const amount = preset === "other" ? Number(fields.get("other")) : Number(preset ?? 0);
    if (preset && !(amount >= 1 && amount <= 100000)) {
      form.querySelector("#other")?.focus();
      return;
    }
    const note = String(fields.get("note") ?? "").trim();
    if (await busy(form, "Saving…", () => data.give(item, preset ? Math.round(amount) : null, note))) {
      render();
      main.insertAdjacentHTML("afterbegin", `<p class="panel success-note subheadline" role="status">Thank you! ${esc(couple())} will see your gift.</p>`);
    }
  }
  if (form.id === "ask-form") {
    const text = String(fields.get("question") ?? "").trim();
    if (!text) return;
    if (await busy(form, "Sending…", () => data.ask(text, fields.get("about")))) render();
  }
});

main.addEventListener("change", (e) => {
  if (e.target.name === "attending") {
    main.querySelector("#party-field").hidden = e.target.value !== "yes";
  }
  if (e.target.dataset.href) location.hash = e.target.dataset.href;
  if (e.target.name === "preset") {
    const other = main.querySelector("#other-field");
    other.hidden = e.target.value !== "other";
    if (!other.hidden) other.querySelector("input").focus();
  }
});

main.addEventListener("click", async (e) => {
  if (e.target.id === "ungive") {
    e.target.disabled = true;
    try {
      await data.ungive(e.target.dataset.item);
      render();
    } catch {
      e.target.disabled = false;
      e.target.insertAdjacentHTML("afterend",
        '<p class="panel warning subheadline" role="alert">That didn’t go through. Check your connection and try again.</p>');
    }
  }
  if (e.target.id === "reset") {
    e.target.disabled = true;
    await data.resetDemo();
    location.hash = "#/home";
    render();
  }
});

// Load this guest's wedding, then show the page.
async function start() {
  main.innerHTML = '<p class="secondary center" role="status">Loading…</p>';
  try {
    if (!(await data.load())) {
      main.innerHTML = `
        <span class="mono hero-mono" aria-hidden="true"></span>
        <header class="stack center">
          <h1 class="title1">We couldn’t find your invite</h1>
          <p class="secondary">Check that you opened the whole link from the couple, or ask them to send it again.</p>
        </header>`;
      return;
    }
  } catch {
    main.innerHTML = `
      <header class="stack center">
        <h1 class="title1">Something went wrong</h1>
        <p class="secondary">We couldn’t load the wedding. Check your connection and try again.</p>
      </header>
      <button class="button primary" onclick="location.reload()">Try again</button>`;
    return;
  }
  window.addEventListener("hashchange", render);
  render();
}

start();
