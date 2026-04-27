-- Migration 015 marketplace offers and negotiations foundation.
-- Scope: buyer offers, seller counter-offers, and immutable offer event history.
-- Guardrails:
-- - artworks remains the single artwork identity path.
-- - no second artwork table or upload identity path.
-- - no coupling to environments or homepage/admin content logic.
-- - backend foundation only; no frontend/UI implementation.
-- - no AI, bots, or agents.
-- - no payment capture.
-- - no escrow release logic.
-- - no crypto.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_offer_status'
  ) then
    create type public.marketplace_offer_status as enum (
      'open',
      'countered',
      'accepted',
      'declined',
      'expired',
      'cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_offer_event_type'
  ) then
    create type public.marketplace_offer_event_type as enum (
      'offer_created',
      'counter_offer_created',
      'accepted',
      'declined',
      'expired',
      'cancelled',
      'note_added'
    );
  end if;
end
$$;

create table public.marketplace_offers (
  id bigint generated always as identity primary key,
  buyer_profile_id bigint not null references public.profiles(id),
  seller_profile_id bigint not null references public.profiles(id),
  artwork_id bigint references public.artworks(id),
  listing_id bigint references public.listings(id),
  inquiry_id bigint references public.marketplace_inquiries(id),
  status public.marketplace_offer_status not null default 'open',
  offer_amount numeric(12,2) not null,
  offer_currency text not null,
  expires_at timestamptz,
  accepted_at timestamptz,
  declined_at timestamptz,
  cancelled_at timestamptz,
  last_event_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_offers_exactly_one_target_chk check (
    num_nonnulls(artwork_id, listing_id) = 1
  ),
  constraint marketplace_offers_buyer_seller_different_chk check (
    buyer_profile_id <> seller_profile_id
  ),
  constraint marketplace_offers_offer_amount_positive_chk check (
    offer_amount > 0
  ),
  constraint marketplace_offers_offer_currency_code_chk check (
    offer_currency ~ '^[A-Z]{3}$'
  ),
  constraint marketplace_offers_terminal_timestamps_exclusive_chk check (
    num_nonnulls(accepted_at, declined_at, cancelled_at) <= 1
  ),
  constraint marketplace_offers_accepted_status_timestamp_chk check (
    accepted_at is null or status = 'accepted'
  ),
  constraint marketplace_offers_declined_status_timestamp_chk check (
    declined_at is null or status = 'declined'
  ),
  constraint marketplace_offers_cancelled_status_timestamp_chk check (
    cancelled_at is null or status = 'cancelled'
  )
);

create index marketplace_offers_buyer_profile_id_idx
  on public.marketplace_offers(buyer_profile_id);

create index marketplace_offers_seller_profile_id_idx
  on public.marketplace_offers(seller_profile_id);

create index marketplace_offers_artwork_id_idx
  on public.marketplace_offers(artwork_id);

create index marketplace_offers_listing_id_idx
  on public.marketplace_offers(listing_id);

create index marketplace_offers_inquiry_id_idx
  on public.marketplace_offers(inquiry_id);

create index marketplace_offers_status_idx
  on public.marketplace_offers(status);

create index marketplace_offers_expires_at_idx
  on public.marketplace_offers(expires_at);

create index marketplace_offers_last_event_at_idx
  on public.marketplace_offers(last_event_at);

create index marketplace_offers_created_at_idx
  on public.marketplace_offers(created_at);

create table public.marketplace_offer_events (
  id bigint generated always as identity primary key,
  offer_id bigint not null references public.marketplace_offers(id) on delete cascade,
  actor_profile_id bigint references public.profiles(id) on delete set null,
  event_type public.marketplace_offer_event_type not null,
  event_amount numeric(12,2),
  event_currency text,
  note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint marketplace_offer_events_event_amount_positive_chk check (
    event_amount is null or event_amount > 0
  ),
  constraint marketplace_offer_events_event_currency_code_chk check (
    event_currency is null or event_currency ~ '^[A-Z]{3}$'
  ),
  constraint marketplace_offer_events_note_nonblank_chk check (
    note is null or btrim(note) <> ''
  ),
  constraint marketplace_offer_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index marketplace_offer_events_offer_id_idx
  on public.marketplace_offer_events(offer_id);

create index marketplace_offer_events_actor_profile_id_idx
  on public.marketplace_offer_events(actor_profile_id);

create index marketplace_offer_events_event_type_idx
  on public.marketplace_offer_events(event_type);

create index marketplace_offer_events_created_at_idx
  on public.marketplace_offer_events(created_at);
