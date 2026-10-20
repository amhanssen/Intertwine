-- Intertwine database: run this once in Supabase → SQL Editor → New query → Run.
-- It is safe to run again: it only creates what is missing and re-seeds the demo wedding.
--
-- How access works
-- • Couples sign in (from the app, later) and can read and change only their own wedding.
-- • Guests don't sign in. Each guest has a private invite code in their link, and the
--   website can only call the guest_ functions below with it. Guests can't read
--   the tables directly, so they never see other guests' details or replies.

-- ---------- Tables ----------

create table if not exists weddings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users on delete cascade,
  couple_names text not null,
  date date not null,
  venue text not null default '',
  hotel_info text not null default '',
  parking_info text not null default '',
  photo_url text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists events (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references weddings on delete cascade,
  type text not null default 'Welcome Party',
  name text not null,
  welcome_message text not null default '',
  day date,
  start_time time,
  end_time time,
  venue text not null default '',
  directions text not null default '',
  dress_code text not null default 'Cocktail attire',
  dress_guidance text not null default '',
  rsvp_required boolean not null default true,
  rsvp_deadline date,
  status text not null default 'draft' check (status in ('draft', 'published')),
  photo_url text,
  created_at timestamptz not null default now()
);

create table if not exists guests (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references weddings on delete cascade,
  name text not null,
  party_size int not null default 1 check (party_size between 1 and 20),
  -- The private part of the guest's link. Hard to guess on purpose.
  invite_code text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists rsvps (
  event_id uuid not null references events on delete cascade,
  guest_id uuid not null references guests on delete cascade,
  attending boolean not null,
  party_count int not null default 1,
  note text not null default '' check (char_length(note) <= 1000),
  updated_at timestamptz not null default now(),
  primary key (event_id, guest_id)
);

create table if not exists questions (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references weddings on delete cascade,
  guest_id uuid references guests on delete set null,
  event_id uuid references events on delete set null,
  text text not null check (char_length(text) between 1 and 1000),
  answer text,
  asked_at timestamptz not null default now()
);

create table if not exists updates (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references weddings on delete cascade,
  title text not null,
  detail text not null default '',
  posted_at timestamptz not null default now()
);

create table if not exists registry_items (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references weddings on delete cascade,
  name text not null,
  price int not null default 0,
  is_fund boolean not null default false,
  purchased boolean not null default false,
  created_at timestamptz not null default now()
);
-- Added later; "if not exists" keeps re-runs safe. For a cash fund, price is the goal.
alter table registry_items add column if not exists link text not null default '';
alter table registry_items add column if not exists note text not null default '';

-- Who gave what: a guest's "I'll get this", or what they put toward a cash fund.
create table if not exists registry_gifts (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references registry_items on delete cascade,
  guest_id uuid references guests on delete set null,
  amount int not null default 0 check (amount between 0 and 100000),
  note text not null default '' check (char_length(note) <= 500),
  thank_you_sent boolean not null default false,
  given_at timestamptz not null default now()
);

-- Registries the couple keeps at other stores (Figma CR3). Guests see them under "Also on".
create table if not exists registry_links (
  id uuid primary key default gen_random_uuid(),
  wedding_id uuid not null references weddings on delete cascade,
  name text not null,
  url text not null check (url ~* '^https?://'),
  created_at timestamptz not null default now()
);

-- A new guest's invite code: 16 random letters and digits, easy to put in a link.
create or replace function make_invite_code() returns text language sql volatile as $$
  select substr(replace(gen_random_uuid()::text, '-', ''), 1, 16)
$$;
alter table guests alter column invite_code set default make_invite_code();

-- ---------- Couples: row-level security ----------

alter table weddings enable row level security;
alter table events enable row level security;
alter table guests enable row level security;
alter table rsvps enable row level security;
alter table questions enable row level security;
alter table updates enable row level security;
alter table registry_items enable row level security;
alter table registry_gifts enable row level security;
alter table registry_links enable row level security;

create or replace function owns_wedding(w uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from weddings where id = w and owner_id = auth.uid())
$$;

drop policy if exists "couple owns wedding" on weddings;
create policy "couple owns wedding" on weddings for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "couple owns events" on events;
create policy "couple owns events" on events for all to authenticated
  using (owns_wedding(wedding_id)) with check (owns_wedding(wedding_id));

drop policy if exists "couple owns guests" on guests;
create policy "couple owns guests" on guests for all to authenticated
  using (owns_wedding(wedding_id)) with check (owns_wedding(wedding_id));

drop policy if exists "couple reads rsvps" on rsvps;
create policy "couple reads rsvps" on rsvps for select to authenticated
  using (owns_wedding((select wedding_id from events where events.id = rsvps.event_id)));

drop policy if exists "couple owns questions" on questions;
create policy "couple owns questions" on questions for all to authenticated
  using (owns_wedding(wedding_id)) with check (owns_wedding(wedding_id));

drop policy if exists "couple owns updates" on updates;
create policy "couple owns updates" on updates for all to authenticated
  using (owns_wedding(wedding_id)) with check (owns_wedding(wedding_id));

drop policy if exists "couple owns registry" on registry_items;
create policy "couple owns registry" on registry_items for all to authenticated
  using (owns_wedding(wedding_id)) with check (owns_wedding(wedding_id));

drop policy if exists "couple owns gifts" on registry_gifts;
create policy "couple owns gifts" on registry_gifts for all to authenticated
  using (owns_wedding((select wedding_id from registry_items i where i.id = registry_gifts.item_id)))
  with check (owns_wedding((select wedding_id from registry_items i where i.id = registry_gifts.item_id)));

drop policy if exists "couple owns registry links" on registry_links;
create policy "couple owns registry links" on registry_links for all to authenticated
  using (owns_wedding(wedding_id)) with check (owns_wedding(wedding_id));

-- ---------- Photos ----------
-- Event and couple photos go in the public "photos" bucket, in a folder named after the
-- wedding's id. Anyone with the address can see a photo (that's how the website shows
-- them); only the couple can add, change or remove photos in their wedding's folder.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do update set public = true;

-- True when a photo's path starts with a wedding this couple owns.
create or replace function owns_photo(path text) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  return owns_wedding(split_part(path, '/', 1)::uuid);
exception when invalid_text_representation then
  return false;
end $$;
revoke all on function owns_photo(text) from public;
grant execute on function owns_photo(text) to authenticated;

drop policy if exists "couple adds photos" on storage.objects;
create policy "couple adds photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and owns_photo(name));
drop policy if exists "couple reads photos" on storage.objects;
create policy "couple reads photos" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and owns_photo(name));
drop policy if exists "couple changes photos" on storage.objects;
create policy "couple changes photos" on storage.objects for update to authenticated
  using (bucket_id = 'photos' and owns_photo(name));
drop policy if exists "couple removes photos" on storage.objects;
create policy "couple removes photos" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and owns_photo(name));

-- ---------- Guests: the only things the website can do ----------

-- Everything one guest needs, found by their invite code. Null if the code is wrong.
create or replace function guest_view(code text) returns json
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_variable
declare g guests;
begin
  select * into g from guests where invite_code = code;
  if not found then return null; end if;

  return json_build_object(
    'wedding', (select json_build_object(
        'coupleNames', w.couple_names, 'date', w.date, 'venue', w.venue,
        'hotelInfo', w.hotel_info, 'parkingInfo', w.parking_info,
        'photo', w.photo_url, 'isDemo', w.is_demo)
      from weddings w where w.id = g.wedding_id),
    'guest', json_build_object('id', g.id, 'name', g.name, 'partySize', g.party_size),
    'events', coalesce((select json_agg(json_build_object(
        'id', e.id, 'name', e.name, 'welcomeMessage', e.welcome_message,
        'day', e.day, 'start', to_char(e.start_time, 'HH24:MI'), 'end', to_char(e.end_time, 'HH24:MI'),
        'venue', e.venue, 'directions', e.directions,
        'dressCode', e.dress_code, 'dressGuidance', e.dress_guidance,
        'rsvpRequired', e.rsvp_required, 'rsvpDeadline', e.rsvp_deadline, 'photo', e.photo_url)
        order by e.day, e.start_time)
      from events e where e.wedding_id = g.wedding_id and e.status = 'published'), '[]'),
    'rsvps', coalesce((select json_object_agg(r.event_id, json_build_object(
        'attending', r.attending, 'partyCount', r.party_count, 'note', r.note))
      from rsvps r where r.guest_id = g.id), '{}'),
    'updates', coalesce((select json_agg(json_build_object('title', u.title, 'detail', u.detail)
        order by u.posted_at desc)
      from updates u where u.wedding_id = g.wedding_id), '[]'),
    -- "taken": a gift someone already bought or said they'd get. "mine": this guest's own
    -- gift, so they can see or undo it. Guests never see who else gave what.
    'registry', coalesce((select json_agg(json_build_object(
        'id', i.id, 'name', i.name, 'price', i.price, 'fund', i.is_fund, 'link', i.link, 'note', i.note,
        'taken', not i.is_fund and (i.purchased or exists (
            select 1 from registry_gifts x where x.item_id = i.id and x.guest_id is distinct from g.id)),
        'raised', (select coalesce(sum(x.amount), 0) from registry_gifts x where x.item_id = i.id),
        'mine', (select json_build_object('amount', x.amount, 'note', x.note) from registry_gifts x
                 where x.item_id = i.id and x.guest_id = g.id order by x.given_at desc limit 1))
        order by i.created_at)
      from registry_items i where i.wedding_id = g.wedding_id), '[]'),
    'registryLinks', coalesce((select json_agg(json_build_object('name', l.name, 'url', l.url) order by l.created_at)
      from registry_links l where l.wedding_id = g.wedding_id), '[]'),
    'questions', coalesce((select json_agg(json_build_object(
        'text', q.text, 'eventId', q.event_id, 'askedAt', q.asked_at, 'answer', q.answer)
        order by q.asked_at desc)
      from questions q where q.guest_id = g.id), '[]')
  );
end $$;

-- Sends or changes the guest's reply to one published event of their own wedding.
create or replace function guest_rsvp(code text, event uuid, attending boolean, party_count int, note text)
returns void language plpgsql security definer set search_path = public as $$
#variable_conflict use_variable
declare g guests;
begin
  select * into g from guests where invite_code = code;
  if not found then raise exception 'Invite not found'; end if;
  if not exists (select 1 from events e where e.id = event and e.wedding_id = g.wedding_id
                 and e.status = 'published' and e.rsvp_required) then
    raise exception 'Event not found';
  end if;

  insert into rsvps (event_id, guest_id, attending, party_count, note, updated_at)
  values (event, g.id, attending,
          case when attending then least(greatest(coalesce(party_count, 1), 1), g.party_size) else 0 end,
          left(coalesce(note, ''), 1000), now())
  on conflict (event_id, guest_id) do update
    set attending = excluded.attending, party_count = excluded.party_count,
        note = excluded.note, updated_at = now();
end $$;

-- Asks the couple a question, optionally about one of their published events.
create or replace function guest_ask(code text, question text, event uuid default null)
returns void language plpgsql security definer set search_path = public as $$
#variable_conflict use_variable
declare g guests;
begin
  select * into g from guests where invite_code = code;
  if not found then raise exception 'Invite not found'; end if;
  if char_length(trim(coalesce(question, ''))) = 0 then raise exception 'Question is empty'; end if;
  if event is not null and not exists (
       select 1 from events e where e.id = event and e.wedding_id = g.wedding_id and e.status = 'published') then
    event := null;
  end if;
  insert into questions (wedding_id, guest_id, event_id, text)
  values (g.wedding_id, g.id, event, left(trim(question), 1000));
end $$;

-- "I'll get this" for a gift, or an amount toward a cash fund. Giving again replaces the
-- guest's earlier gift to the same item.
create or replace function guest_give(code text, item uuid, amount int default null, note text default '')
returns void language plpgsql security definer set search_path = public as $$
#variable_conflict use_variable
declare g guests; i registry_items;
begin
  select * into g from guests where invite_code = code;
  if not found then raise exception 'Invite not found'; end if;
  select * into i from registry_items r where r.id = item and r.wedding_id = g.wedding_id;
  if not found then raise exception 'Gift not found'; end if;
  if not i.is_fund and (i.purchased or exists (
       select 1 from registry_gifts x where x.item_id = i.id and x.guest_id is distinct from g.id)) then
    raise exception 'Someone already got this gift';
  end if;
  if i.is_fund and (amount is null or amount < 1 or amount > 100000) then
    raise exception 'Choose an amount';
  end if;

  delete from registry_gifts x where x.item_id = i.id and x.guest_id = g.id;
  insert into registry_gifts (item_id, guest_id, amount, note)
  values (i.id, g.id, case when i.is_fund then amount else i.price end, left(coalesce(note, ''), 500));
end $$;

-- Takes back the guest's own gift ("I won't get this after all").
create or replace function guest_ungive(code text, item uuid)
returns void language plpgsql security definer set search_path = public as $$
#variable_conflict use_variable
declare g guests;
begin
  select * into g from guests where invite_code = code;
  if not found then raise exception 'Invite not found'; end if;
  delete from registry_gifts x where x.item_id = item and x.guest_id = g.id;
end $$;

-- Only these functions are reachable without signing in.
revoke all on function guest_view(text) from public;
revoke all on function guest_rsvp(text, uuid, boolean, int, text) from public;
revoke all on function guest_ask(text, text, uuid) from public;
grant execute on function guest_view(text) to anon, authenticated;
grant execute on function guest_rsvp(text, uuid, boolean, int, text) to anon, authenticated;
grant execute on function guest_ask(text, text, uuid) to anon, authenticated;
revoke all on function guest_give(text, uuid, int, text) from public;
revoke all on function guest_ungive(text, uuid) from public;
grant execute on function guest_give(text, uuid, int, text) to anon, authenticated;
grant execute on function guest_ungive(text, uuid) to anon, authenticated;
revoke all on function owns_wedding(uuid) from public;
grant execute on function owns_wedding(uuid) to authenticated;

-- ---------- Demo: Mia & Ryan's wedding, with Rosa's link at ?invite=demo-rosa ----------

-- Removes the demo wedding and everything in it, then puts it back as it started.
-- Anyone can call this, and it only ever touches the demo wedding.
create or replace function reset_demo() returns void
language plpgsql security definer set search_path = public as $$
declare w uuid; rosa uuid; engagement uuid; shower uuid; welcome uuid;
begin
  delete from weddings where is_demo;

  insert into weddings (couple_names, date, venue, hotel_info, parking_info, photo_url, is_demo)
  values ('Mia & Ryan', '2027-09-26', 'Seaport Hotel',
          'We have a room block at the Seaport Hotel until Aug 25. Mention “Mia & Ryan” when you book.',
          'Valet parking at the main entrance, or the Seaport garage across the street.',
          'images/Couple.jpg', true)
  returning id into w;

  insert into events (wedding_id, type, name, welcome_message, day, start_time, end_time, venue, directions,
                      dress_code, dress_guidance, rsvp_required, rsvp_deadline, status, photo_url)
  values (w, 'Engagement Party', 'Engagement Party', 'Come celebrate with us!', '2026-11-14', '19:00', '22:00',
          'Harbor View Terrace', 'Take the elevator to the rooftop.', 'Smart casual',
          'Whatever makes you feel good — it’s a party.', true, '2026-11-01', 'published', 'images/EventEngagementParty.jpg')
  returning id into engagement;

  insert into events (wedding_id, type, name, welcome_message, day, start_time, end_time, venue, directions,
                      dress_code, dress_guidance, rsvp_required, rsvp_deadline, status, photo_url)
  values (w, 'Bridal Shower', 'Bridal Shower', 'An afternoon of tea and games for Mia.', '2027-07-18', '13:00', '16:00',
          'Rosa’s house', 'Park on the street; the gate is on the left.', 'Garden party',
          'Light colors and flat shoes — we’ll be on the lawn.', true, '2027-07-01', 'published', 'images/EventBridalShower.jpg')
  returning id into shower;

  insert into events (wedding_id, type, name, welcome_message, day, start_time, end_time, venue, directions,
                      dress_code, dress_guidance, rsvp_required, rsvp_deadline, status, photo_url)
  values (w, 'Welcome Party', 'Welcome Party', 'Join us for drinks before the big day.', '2027-09-25', '18:00', '20:00',
          'Seaport Hotel', 'Use the main entrance and follow the Welcome Party signs.', 'Cocktail attire',
          'Dresses or suits; comfortable shoes welcome.', true, '2027-09-10', 'published', 'images/EventWelcomeParty.jpg')
  returning id into welcome;

  insert into events (wedding_id, type, name, day, start_time, end_time, dress_code, status, photo_url)
  values (w, 'Rehearsal Dinner', 'Rehearsal Dinner', '2027-09-24', '18:00', '21:00', 'Smart casual', 'draft',
          'images/EventRehearsalDinner.jpg');
  insert into events (wedding_id, type, name, welcome_message, day, venue, dress_code, status, photo_url)
  values (w, 'Ceremony & Reception', 'Wedding Day', 'We can’t wait to celebrate with you.', '2027-09-26',
          'Seaport Hotel', 'Black tie optional', 'draft', 'images/EventWeddingDay.jpg');

  insert into guests (wedding_id, name, party_size, invite_code)
  values (w, 'Rosa', 1, 'demo-rosa') returning id into rosa;
  insert into guests (wedding_id, name, party_size)
  select w, n, case when i % 3 = 0 then 2 else 1 end
  from unnest(array['Amy Adams', 'Elizabeth Atkinson', 'John Atwood', 'Jessica Avery', 'Christopher Bailey',
                    'Joseph Baker', 'James Bennett', 'Megan Berry', 'Hannah Blair', 'Patricia Brooks',
                    'Sarah Brown', 'Laura Bryant', 'Edward Burton']) with ordinality as t(n, i);

  insert into rsvps (event_id, guest_id, attending, party_count, note) values
    (engagement, rosa, true, 1, ''),
    (shower, rosa, true, 1, 'I’ll bring dessert!');
  insert into rsvps (event_id, guest_id, attending, party_count, note)
  select engagement, g.id, (row_number() over (order by g.name)) % 5 <> 0, g.party_size, ''
  from guests g where g.wedding_id = w and g.id <> rosa;

  insert into questions (wedding_id, guest_id, event_id, text)
  select w, g.id, welcome, 'Is there parking at the hotel?' from guests g where g.wedding_id = w and g.name = 'John Atwood';
  insert into questions (wedding_id, guest_id, text)
  select w, g.id, 'Can I bring my kids?' from guests g where g.wedding_id = w and g.name = 'Joseph Baker';

  insert into updates (wedding_id, title, detail, posted_at) values
    (w, 'Hotel block closes Aug 25', 'Mention “Mia & Ryan” when you book', now() - interval '1 day'),
    (w, 'Welcome Party added', 'Drinks the night before · Sep 25', now());

  insert into registry_items (wedding_id, name, price, is_fund, purchased, note, created_at) values
    (w, 'Linen sheet set', 180, false, false, 'Queen size, in oat.', now()),
    (w, 'Dutch oven', 120, false, false, '', now() + interval '1 second'),
    (w, 'Salad bowl', 45, false, false, '', now() + interval '2 seconds'),
    (w, 'Stand mixer', 449, false, false, '', now() + interval '3 seconds'),
    (w, 'Honeymoon fund', 3000, true, false, 'Two weeks in Portugal.', now() + interval '4 seconds'),
    (w, 'First home fund', 5000, true, false, '', now() + interval '5 seconds');

  -- A few gifts from other guests, so the couple's "Gifts bought" list has something in it.
  insert into registry_gifts (item_id, guest_id, amount, given_at, thank_you_sent)
  select i.id, g.id, i.price, now() - interval '20 days', true
  from registry_items i, guests g where i.wedding_id = w and i.name = 'Stand mixer' and g.wedding_id = w and g.name = 'Sarah Brown';
  insert into registry_gifts (item_id, guest_id, amount, given_at)
  select i.id, g.id, 150, now() - interval '17 days'
  from registry_items i, guests g where i.wedding_id = w and i.name = 'Honeymoon fund' and g.wedding_id = w and g.name = 'James Bennett';
  insert into registry_gifts (item_id, guest_id, amount, given_at)
  select i.id, g.id, 100, now() - interval '15 days'
  from registry_items i, guests g where i.wedding_id = w and i.name = 'First home fund' and g.wedding_id = w and g.name = 'Hannah Blair';

  insert into registry_links (wedding_id, name, url) values
    (w, 'Home store registry', 'https://example.com/registry/mia-and-ryan');
end $$;

revoke all on function reset_demo() from public;
grant execute on function reset_demo() to anon, authenticated;

select reset_demo();
