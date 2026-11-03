// Wedding data for the couple's side of the website, from the shared Supabase database.
//
// Couples sign in with the same email and password as the app. Row-level security in
// ../supabase/schema.sql limits them to their own wedding, so the site can read and change
// the tables directly. Everything is loaded into `state`, and every change saves to the
// database and then loads again, so the app and the site always show the same wedding.

const SUPABASE_URL = "https://nhdfuarjvwoeghgyxtvw.supabase.co";
// The publishable key is meant to be public. On its own it can only call the guest
// functions; the couple's sign-in is what lets the site reach their wedding.
const SUPABASE_KEY = "sb_publishable_yDztgS26co172rYYSgZ8-w_KLVdKchJ";
const SESSION_KEY = "intertwine.couple";

export const GUEST_SITE = new URL("./", location.href).href;
export const inviteLink = (code) => `${GUEST_SITE}?invite=${encodeURIComponent(code)}`;

// ---------- Sign-in ----------

let session = loadSession();

function loadSession() {
  try { return JSON.parse(localStorage.getItem(SESSION_KEY)); } catch { return null; }
}

function saveSession(value) {
  session = value;
  try {
    if (value) localStorage.setItem(SESSION_KEY, JSON.stringify(value));
    else localStorage.removeItem(SESSION_KEY);
  } catch { /* storage blocked: stays signed in until the page closes */ }
}

/** Supabase's messages are written for developers; these are for couples (same as the app). */
function friendly(code, message) {
  switch (code) {
    case "invalid_credentials": return "That email and password don’t match. Check them and try again.";
    case "user_already_exists": case "email_exists": return "There’s already an account with that email. Sign in instead.";
    case "weak_password": return "Choose a longer password: at least 8 characters.";
    case "email_not_confirmed": return "Check your email and click the link to confirm your account, then sign in.";
    case "over_email_send_rate_limit": case "over_request_rate_limit": return "Too many tries. Wait a minute and try again.";
    case "validation_failed": return "Check that the email address is complete.";
    default: return message || "Something went wrong. Try again.";
  }
}

async function auth(path, body) {
  let response;
  try {
    response = await fetch(`${SUPABASE_URL}/auth/v1/${path}`, {
      method: "POST",
      headers: { apikey: SUPABASE_KEY, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  } catch {
    throw new Error("You’re offline. Check your connection and try again.");
  }
  const json = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(friendly(json.error_code, json.msg || json.message || json.error_description));
  return json;
}

function sessionFrom(json, email) {
  if (!json.access_token || !json.user) return null;
  return {
    accessToken: json.access_token,
    refreshToken: json.refresh_token,
    expiresAt: Date.now() + (json.expires_in ?? 3600) * 1000,
    userID: json.user.id,
    email: json.user.email ?? email,
  };
}

/** A fresh sign-in token, refreshed a minute before it runs out. */
async function token() {
  if (!session) throw new SignedOut();
  if (Date.now() > session.expiresAt - 60_000) {
    try {
      saveSession(sessionFrom(await auth("token?grant_type=refresh_token", { refresh_token: session.refreshToken }), session.email));
    } catch {
      saveSession(null);
    }
    if (!session) throw new SignedOut();
  }
  return session.accessToken;
}

export class SignedOut extends Error {
  constructor() { super("You’re signed out. Sign in again."); }
}

// ---------- Database ----------

async function rest(method, path, body, prefer) {
  const headers = { apikey: SUPABASE_KEY, Authorization: `Bearer ${await token()}` };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (prefer) headers.Prefer = prefer;
  let response;
  try {
    response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
      method, headers, body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new Error("You’re offline. Check your connection and try again.");
  }
  if (response.status === 401) { saveSession(null); throw new SignedOut(); }
  if (!response.ok) throw new Error("That didn’t save. Try again.");
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

const select = (table, query) => rest("GET", `${table}?${query}`);
const insert = (table, row) => rest("POST", table, row, "return=representation").then((rows) => rows[0]);
const update = (table, id, changes) => rest("PATCH", `${table}?id=eq.${id}`, changes, "return=minimal");
const remove = (table, id) => rest("DELETE", `${table}?id=eq.${id}`);
const inList = (ids) => `in.(${ids.join(",")})`;

// ---------- Photos ----------

/** Shrinks a picked photo to a JPEG no wider than 1600px, like the app does. */
async function jpeg(file) {
  const bitmap = await createImageBitmap(file);
  const scale = Math.min(1, 1600 / Math.max(bitmap.width, bitmap.height));
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(bitmap.width * scale);
  canvas.height = Math.round(bitmap.height * scale);
  canvas.getContext("2d").drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  return new Promise((resolve, reject) =>
    canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error("That photo couldn’t be read."))), "image/jpeg", 0.85));
}

/** Uploads a photo to the public "photos" bucket in the wedding's folder; returns its address. */
async function uploadPhoto(file) {
  const path = `${state.wedding.id}/web-${crypto.randomUUID()}.jpg`;
  const response = await fetch(`${SUPABASE_URL}/storage/v1/object/photos/${path}`, {
    method: "POST",
    headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${await token()}`, "Content-Type": "image/jpeg", "x-upsert": "true" },
    body: await jpeg(file),
  });
  if (!response.ok) throw new Error("The photo didn’t upload. Try a smaller photo.");
  return `${SUPABASE_URL}/storage/v1/object/public/photos/${path}`;
}

// ---------- The wedding ----------

export const state = {
  wedding: null, events: [], guests: [], rsvps: [], questions: [],
  registry: [], gifts: [], links: [],
};

const sortEvents = (a, b) =>
  (a.day ?? "9999").localeCompare(b.day ?? "9999") || (a.start_time ?? "").localeCompare(b.start_time ?? "");

export const data = {
  signedIn: () => session !== null,
  email: () => session?.email,

  async signIn(email, password) {
    saveSession(sessionFrom(await auth("token?grant_type=password", { email, password }), email));
  },

  /** Returns false when Supabase wants the email confirmed before signing in. */
  async signUp(email, password) {
    const created = sessionFrom(await auth("signup", { email, password }), email);
    if (created) saveSession(created);
    return created !== null;
  },

  /** Emails a link to choose a new password. The link opens this page signed in. */
  async forgotPassword(email) {
    const back = new URL("couple.html", GUEST_SITE).href;
    await auth(`recover?redirect_to=${encodeURIComponent(back)}`, { email });
  },

  /** Signs in from the password-reset link (the tokens Supabase puts after "#"). */
  async signInFromLink(params) {
    let response;
    try {
      response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
        headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${params.get("access_token")}` },
      });
    } catch {
      throw new Error("You’re offline. Check your connection and try again.");
    }
    if (!response.ok) throw new Error("That link has expired. Ask for a new one.");
    saveSession(sessionFrom({
      access_token: params.get("access_token"), refresh_token: params.get("refresh_token"),
      expires_in: Number(params.get("expires_in")) || 3600, user: await response.json(),
    }));
  },

  async setPassword(password) {
    let response;
    try {
      response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
        method: "PUT",
        headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${await token()}`, "Content-Type": "application/json" },
        body: JSON.stringify({ password }),
      });
    } catch {
      throw new Error("You’re offline. Check your connection and try again.");
    }
    const json = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(json.error_code === "same_password"
        ? "That’s your current password. Choose a new one."
        : friendly(json.error_code, json.msg || json.message));
    }
  },

  signOut() {
    saveSession(null);
    Object.assign(state, { wedding: null, events: [], guests: [], rsvps: [], questions: [], registry: [], gifts: [], links: [] });
  },

  /** Loads the couple's wedding (the newest one, like the app). Returns false if there's none yet. */
  async load() {
    const [wedding] = await select("weddings", `owner_id=eq.${session.userID}&order=created_at.desc&limit=1`);
    if (!wedding) { state.wedding = null; return false; }
    const w = `wedding_id=eq.${wedding.id}`;
    const [events, guests, questions, registry, links] = await Promise.all([
      select("events", w),
      select("guests", `${w}&order=created_at`),
      select("questions", `${w}&order=asked_at.desc`),
      select("registry_items", `${w}&order=created_at`),
      select("registry_links", `${w}&order=created_at`),
    ]);
    const [rsvps, gifts] = await Promise.all([
      events.length ? select("rsvps", `event_id=${inList(events.map((e) => e.id))}`) : [],
      registry.length ? select("registry_gifts", `item_id=${inList(registry.map((i) => i.id))}&order=given_at.desc`) : [],
    ]);
    Object.assign(state, { wedding, events: events.sort(sortEvents), guests, rsvps, questions, registry, gifts, links });
    return true;
  },

  async createWedding({ coupleNames, date, venue }) {
    await insert("weddings", { owner_id: session.userID, couple_names: coupleNames, date, venue });
    await this.load();
  },

  /** `crop` (like "#pos=50,30") says which part of a new photo to show. */
  async saveWedding(changes, photo, crop = "") {
    if (photo) changes.photo_url = (await uploadPhoto(photo)) + crop;
    await update("weddings", state.wedding.id, changes);
    await this.load();
  },

  /** Adds or changes an event; returns its id. */
  async saveEvent(id, fields, photo) {
    if (photo) fields.photo_url = await uploadPhoto(photo);
    if (id) await update("events", id, fields);
    else id = (await insert("events", { ...fields, wedding_id: state.wedding.id })).id;
    await this.load();
    return id;
  },

  async deleteEvent(id) { await remove("events", id); await this.load(); },

  async addGuest(name, partySize) {
    await insert("guests", { wedding_id: state.wedding.id, name, party_size: partySize });
    await this.load();
  },
  /** Adds several guests at once (from a contacts file or a pasted list). */
  async addGuests(names) {
    await rest("POST", "guests", names.map((name) => ({ wedding_id: state.wedding.id, name, party_size: 1 })), "return=minimal");
    await this.load();
  },
  async saveGuest(id, changes) { await update("guests", id, changes); await this.load(); },
  async deleteGuest(id) { await remove("guests", id); await this.load(); },

  async answer(id, text) { await update("questions", id, { answer: text || null }); await this.load(); },

  async saveItem(id, fields) {
    if (id) await update("registry_items", id, fields);
    else await insert("registry_items", { ...fields, wedding_id: state.wedding.id });
    await this.load();
  },
  async deleteItem(id) { await remove("registry_items", id); await this.load(); },
  async thankYou(id, sent) { await update("registry_gifts", id, { thank_you_sent: sent }); await this.load(); },

  async addLink(name, url) {
    await insert("registry_links", { wedding_id: state.wedding.id, name, url });
    await this.load();
  },
  async deleteLink(id) { await remove("registry_links", id); await this.load(); },

  // ---------- Lookups ----------

  event: (id) => state.events.find((e) => e.id === id),
  guest: (id) => state.guests.find((g) => g.id === id),
  item: (id) => state.registry.find((i) => i.id === id),

  /** Attending people, declined guests and guests still to reply (same as the app). */
  rsvpCounts(eventID) {
    const replies = state.rsvps.filter((r) => r.event_id === eventID);
    return {
      attending: replies.filter((r) => r.attending).reduce((sum, r) => sum + r.party_count, 0),
      declined: replies.filter((r) => !r.attending).length,
      pending: Math.max(0, state.guests.length - replies.length),
    };
  },
  reply: (eventID, guestID) => state.rsvps.find((r) => r.event_id === eventID && r.guest_id === guestID),

  /** What's still missing before an event can be published (same as the app). */
  missing(event) {
    const missing = [];
    if (!event.name?.trim()) missing.push("name");
    if (!event.day) missing.push("date");
    if (!event.start_time) missing.push("start time");
    if (!event.venue?.trim()) missing.push("venue");
    return missing;
  },

  giftsFor: (itemID) => state.gifts.filter((g) => g.item_id === itemID),
  raised: (itemID) => state.gifts.filter((g) => g.item_id === itemID).reduce((sum, g) => sum + g.amount, 0),
  isTaken: (item) => !item.is_fund && (item.purchased || state.gifts.some((g) => g.item_id === item.id)),
  unanswered: () => state.questions.filter((q) => !q.answer),
};
