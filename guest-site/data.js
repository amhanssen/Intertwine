// Wedding data for the guest site.
//
// For now this is Mia & Ryan's sample wedding (the same as SampleData.swift in the app), and a
// guest's RSVPs and questions are saved in this browser only. When the shared database
// (Supabase) is set up, only this file changes: the pages call the same functions.

const SAMPLE = {
  wedding: {
    coupleNames: "Mia & Ryan",
    date: "2027-09-26",
    venue: "Seaport Hotel",
    hotelInfo: "We have a room block at the Seaport Hotel until Aug 25. Mention “Mia & Ryan” when you book.",
    parkingInfo: "Valet parking at the main entrance, or the Seaport garage across the street.",
    photo: "images/Couple.jpg",
  },
  guest: { id: "rosa", name: "Rosa", partySize: 1 },
  events: [
    {
      id: "engagement", name: "Engagement Party", welcomeMessage: "Come celebrate with us!",
      day: "2026-11-14", start: "19:00", end: "22:00",
      venue: "Harbor View Terrace", directions: "Take the elevator to the rooftop.",
      dressCode: "Smart casual", dressGuidance: "Whatever makes you feel good — it’s a party.",
      rsvpRequired: true, rsvpDeadline: "2026-11-01", photo: "images/EventEngagementParty.jpg",
    },
    {
      id: "shower", name: "Bridal Shower", welcomeMessage: "An afternoon of tea and games for Mia.",
      day: "2027-07-18", start: "13:00", end: "16:00",
      venue: "Rosa’s house", directions: "Park on the street; the gate is on the left.",
      dressCode: "Garden party", dressGuidance: "Light colors and flat shoes — we’ll be on the lawn.",
      rsvpRequired: true, rsvpDeadline: "2027-07-01", photo: "images/EventBridalShower.jpg",
    },
    {
      id: "welcome", name: "Welcome Party", welcomeMessage: "Join us for drinks before the big day.",
      day: "2027-09-25", start: "18:00", end: "20:00",
      venue: "Seaport Hotel", directions: "Use the main entrance and follow the Welcome Party signs.",
      dressCode: "Cocktail attire", dressGuidance: "Dresses or suits; comfortable shoes welcome.",
      rsvpRequired: true, rsvpDeadline: "2027-09-10", photo: "images/EventWelcomeParty.jpg",
    },
  ],
  // Replies the guest had already sent in the sample.
  rsvps: {
    engagement: { attending: true, partyCount: 1, note: "" },
    shower: { attending: true, partyCount: 1, note: "I’ll bring dessert!" },
  },
  updates: [
    { title: "Welcome Party added", detail: "Drinks the night before · Sep 25" },
    { title: "Hotel block closes Aug 25", detail: "Mention “Mia & Ryan” when you book" },
  ],
  registry: [
    { id: "napkins", name: "Linen napkin set", price: 45, purchased: false },
    { id: "dutch-oven", name: "Dutch oven", price: 120, purchased: true },
    { id: "honeymoon", name: "Honeymoon fund", price: 25, purchased: false, fund: true },
    { id: "mixer", name: "Stand mixer", price: 380, purchased: false },
  ],
};

const STORAGE_KEY = "intertwine.guest.v1";

// Browser storage can be missing or blocked (private windows, previews), so every
// read and write is guarded and the site still works without it.
function loadSaved() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {};
  } catch {
    return {};
  }
}

function save(saved) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(saved));
  } catch {
    // Not saved; the reply still shows until the page is closed.
  }
}

let saved = loadSaved();

export const data = {
  wedding: () => SAMPLE.wedding,
  guest: () => SAMPLE.guest,
  updates: () => SAMPLE.updates,
  registry: () => SAMPLE.registry,

  /** Published events, in date order. */
  events: () => [...SAMPLE.events].sort((a, b) => (a.day + a.start).localeCompare(b.day + b.start)),
  event: (id) => SAMPLE.events.find((e) => e.id === id),

  rsvp: (eventId) => saved.rsvps?.[eventId] ?? SAMPLE.rsvps[eventId] ?? null,

  sendRSVP(eventId, { attending, partyCount, note }) {
    saved = { ...saved, rsvps: { ...saved.rsvps, [eventId]: { attending, partyCount: attending ? partyCount : 0, note } } };
    save(saved);
  },

  questions: () => saved.questions ?? [],

  ask(text, eventId) {
    const question = { text, eventId: eventId || null, askedAt: new Date().toISOString(), answer: null };
    saved = { ...saved, questions: [question, ...(saved.questions ?? [])] };
    save(saved);
  },

  /** Puts the sample back the way it started (for demos). */
  reset() {
    saved = {};
    save(saved);
  },
};
