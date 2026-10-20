// Wedding data for the guest site, from the shared Supabase database.
//
// A guest's link carries their private invite code (…/Intertwine/?invite=CODE). The site
// remembers it, then loads everything that guest may see in one call (guest_view) and
// keeps it here, so pages can read it straight away. Sending an RSVP or a question calls
// the database and then loads again. Without a code it shows the demo guest, Rosa.
// The database side is in ../supabase/schema.sql.

const SUPABASE_URL = "https://nhdfuarjvwoeghgyxtvw.supabase.co";
// The publishable key is meant to be public: it only allows the guest_ functions.
const SUPABASE_KEY = "sb_publishable_yDztgS26co172rYYSgZ8-w_KLVdKchJ";

const DEMO_CODE = "demo-rosa";
const CODE_KEY = "intertwine.invite";

/** The invite code from the link, or the one remembered from an earlier visit. */
function inviteCode() {
  const fromLink = new URLSearchParams(location.search).get("invite");
  if (fromLink) {
    try { localStorage.setItem(CODE_KEY, fromLink); } catch { /* storage blocked: the link still works */ }
    return fromLink;
  }
  try { return localStorage.getItem(CODE_KEY) || DEMO_CODE; } catch { return DEMO_CODE; }
}

const code = inviteCode();

async function call(fn, args) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: { apikey: SUPABASE_KEY, "Content-Type": "application/json" },
    body: JSON.stringify(args),
  });
  if (!response.ok) throw new Error(`${fn} failed (${response.status})`);
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

let view = null;

export const data = {
  /** Loads this guest's wedding. Returns false when the invite code isn't known. */
  async load() {
    view = await call("guest_view", { code });
    return view !== null;
  },

  isDemo: () => code === DEMO_CODE || view.wedding.isDemo,

  wedding: () => view.wedding,
  guest: () => view.guest,
  updates: () => view.updates,
  registry: () => view.registry,
  questions: () => view.questions,

  /** Published events, in date order. */
  events: () => view.events,
  event: (id) => view.events.find((e) => e.id === id),
  rsvp: (eventId) => view.rsvps[eventId] ?? null,

  async sendRSVP(eventId, { attending, partyCount, note }) {
    await call("guest_rsvp", { code, event: eventId, attending, party_count: partyCount, note });
    await this.load();
  },

  async ask(text, eventId) {
    await call("guest_ask", { code, question: text, event: eventId || null });
    await this.load();
  },

  /** Puts the demo wedding back the way it started. Only works on the demo. */
  async resetDemo() {
    await call("reset_demo", {});
    await this.load();
  },
};
