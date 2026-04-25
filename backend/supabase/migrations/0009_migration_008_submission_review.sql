-- Migration 008 submission review, publishing, dimensions, and pricing standardization.
-- Scope: artworks, listings, review_events.
-- Guardrails:
-- - artworks remains the single artwork identity path.
-- - no second artwork table or upload identity path.
-- - no coupling to environments or homepage/admin content logic.

-- Enums required for Migration 008.
do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'submission_review_status'
  ) then
    create type public.submission_review_status as enum (
      'draft',
      'submitted',
      'changes_requested',
      'approved',
      'rejected'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'publication_status'
  ) then
    create type public.publication_status as enum (
      'hidden',
      'scheduled',
      'published',
      'unpublished'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'review_event_type'
  ) then
    create type public.review_event_type as enum (
      'submit',
      'request_changes',
      'approve',
      'reject',
      'schedule_publish',
      'publish',
      'unpublish'
    );
  end if;
end
$$;

-- Artworks: standardized dimensions + workflow states.
alter table public.artworks
  add column if not exists width_cm numeric(12,3),
  add column if not exists height_cm numeric(12,3),
  add column if not exists thickness_cm numeric(12,3),
  add column if not exists width_in numeric(12,3),
  add column if not exists height_in numeric(12,3),
  add column if not exists thickness_in numeric(12,3),
  add column if not exists review_status public.submission_review_status not null default 'draft',
  add column if not exists publication_status public.publication_status not null default 'hidden',
  add column if not exists submitted_at timestamptz,
  add column if not exists reviewed_at timestamptz,
  add column if not exists scheduled_publish_at timestamptz,
  add column if not exists published_at timestamptz;

alter table public.artworks
  add constraint artworks_width_cm_positive_chk check (width_cm is null or width_cm > 0),
  add constraint artworks_height_cm_positive_chk check (height_cm is null or height_cm > 0),
  add constraint artworks_thickness_cm_positive_chk check (thickness_cm is null or thickness_cm > 0),
  add constraint artworks_width_in_positive_chk check (width_in is null or width_in > 0),
  add constraint artworks_height_in_positive_chk check (height_in is null or height_in > 0),
  add constraint artworks_thickness_in_positive_chk check (thickness_in is null or thickness_in > 0),
  add constraint artworks_reviewed_after_submitted_chk check (
    reviewed_at is null or submitted_at is null or reviewed_at >= submitted_at
  ),
  add constraint artworks_published_after_scheduled_chk check (
    published_at is null or scheduled_publish_at is null or published_at >= scheduled_publish_at
  );

create index artworks_review_status_idx on public.artworks(review_status);
create index artworks_publication_status_idx on public.artworks(publication_status);
create index artworks_scheduled_publish_at_idx on public.artworks(scheduled_publish_at);

-- Listings: pricing standardization + workflow states.
-- Choice for existing ask_price/currency_code overlap:
-- - migrate/backfill into price_amount/price_currency.
-- - keep parity checks to avoid competing pricing systems.
alter table public.listings
  add column if not exists price_amount numeric(12,2),
  add column if not exists price_currency char(3),
  add column if not exists sale_price_amount numeric(12,2),
  add column if not exists sale_price_currency char(3),
  add column if not exists review_status public.submission_review_status not null default 'draft',
  add column if not exists publication_status public.publication_status not null default 'hidden',
  add column if not exists submitted_at timestamptz,
  add column if not exists reviewed_at timestamptz,
  add column if not exists scheduled_publish_at timestamptz,
  add column if not exists published_at timestamptz;

update public.listings
set
  price_amount = coalesce(price_amount, ask_price),
  price_currency = upper(
    coalesce(
      nullif(btrim(price_currency), ''),
      nullif(btrim(currency_code), '')
    )
  )
where price_amount is null
   or price_currency is null
   or btrim(price_currency) = '';

alter table public.listings
  alter column price_currency set default 'USD';

update public.listings
set price_currency = 'USD'
where price_currency is null
   or btrim(price_currency) = '';

do $$
begin
  if exists (
    select 1
    from public.listings
    where price_amount is null
  ) then
    raise exception
      'Migration 008 aborted: listings contain rows with neither price_amount nor ask_price; clean legacy pricing data before re-running.';
  end if;
end
$$;

alter table public.listings
  alter column price_currency set not null;

alter table public.listings
  alter column price_amount set not null;

update public.listings
set
  ask_price = price_amount,
  currency_code = coalesce(
    upper(nullif(btrim(currency_code), '')),
    price_currency
  )
where ask_price is distinct from price_amount
   or currency_code is distinct from price_currency;

alter table public.listings
  add constraint listings_price_amount_nonnegative_chk check (price_amount >= 0),
  add constraint listings_price_currency_upper_chk check (price_currency = upper(price_currency)),
  add constraint listings_sale_price_amount_nonnegative_chk check (
    sale_price_amount is null or sale_price_amount >= 0
  ),
  add constraint listings_sale_price_currency_upper_chk check (
    sale_price_currency is null or sale_price_currency = upper(sale_price_currency)
  ),
  add constraint listings_sale_price_not_above_price_chk check (
    sale_price_amount is null or sale_price_amount <= price_amount
  ),
  add constraint listings_sale_currency_requires_sale_price_chk check (
    sale_price_currency is null or sale_price_amount is not null
  ),
  add constraint listings_reviewed_after_submitted_chk check (
    reviewed_at is null or submitted_at is null or reviewed_at >= submitted_at
  ),
  add constraint listings_published_after_scheduled_chk check (
    published_at is null or scheduled_publish_at is null or published_at >= scheduled_publish_at
  ),
  add constraint listings_price_parity_with_legacy_chk check (
    ask_price is not distinct from price_amount
    and currency_code is not distinct from price_currency
  );

create index listings_review_status_idx on public.listings(review_status);
create index listings_publication_status_idx on public.listings(publication_status);
create index listings_scheduled_publish_at_idx on public.listings(scheduled_publish_at);

-- Review/audit events for artworks or listings.
create table public.review_events (
  id bigint generated always as identity primary key,
  actor_profile_id bigint not null references public.profiles(id) on delete restrict,
  artwork_id bigint references public.artworks(id) on delete cascade,
  listing_id bigint references public.listings(id) on delete cascade,
  event_type public.review_event_type not null,
  note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint review_events_exactly_one_target_chk check (
    num_nonnulls(artwork_id, listing_id) = 1
  )
);

create index review_events_actor_profile_id_idx on public.review_events(actor_profile_id);
create index review_events_artwork_id_idx on public.review_events(artwork_id);
create index review_events_listing_id_idx on public.review_events(listing_id);
create index review_events_event_type_idx on public.review_events(event_type);
