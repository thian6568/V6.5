-- Migration 016 marketplace cart and checkout intent foundation.
-- Scope: buyer cart items and checkout intent preparation before payment.
-- Guardrails:
-- - artworks remains the single artwork identity path.
-- - no second artwork table or upload identity path.
-- - no coupling to environments or homepage/admin content logic.
-- - backend foundation only; no frontend/UI implementation.
-- - no AI, bots, or agents.
-- - no payment capture.
-- - no escrow release logic.
-- - no crypto.
-- - no shipping execution.
-- - no tax calculation execution.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_checkout_intent_status'
  ) then
    create type public.marketplace_checkout_intent_status as enum (
      'draft',
      'ready',
      'submitted',
      'expired',
      'cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_checkout_item_source_type'
  ) then
    create type public.marketplace_checkout_item_source_type as enum (
      'cart_item',
      'listing',
      'artwork',
      'accepted_offer'
    );
  end if;
end
$$;

create table public.marketplace_carts (
  id bigint generated always as identity primary key,
  buyer_profile_id bigint not null references public.profiles(id),
  name text not null default 'Default Cart',
  is_active boolean not null default true,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_carts_name_nonblank_chk check (
    btrim(name) <> ''
  )
);

create index marketplace_carts_buyer_profile_id_idx
  on public.marketplace_carts(buyer_profile_id);

create index marketplace_carts_buyer_profile_id_is_active_idx
  on public.marketplace_carts(buyer_profile_id, is_active);

create unique index marketplace_carts_one_default_per_buyer_idx
  on public.marketplace_carts(buyer_profile_id)
  where is_default = true;

create table public.marketplace_cart_items (
  id bigint generated always as identity primary key,
  cart_id bigint not null references public.marketplace_carts(id) on delete cascade,
  artwork_id bigint references public.artworks(id),
  listing_id bigint references public.listings(id),
  quantity integer not null default 1,
  added_from_offer_id bigint references public.marketplace_offers(id),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_cart_items_exactly_one_target_chk check (
    num_nonnulls(artwork_id, listing_id) = 1
  ),
  constraint marketplace_cart_items_quantity_positive_chk check (
    quantity > 0
  ),
  constraint marketplace_cart_items_note_nonblank_chk check (
    note is null or btrim(note) <> ''
  )
);

create index marketplace_cart_items_cart_id_idx
  on public.marketplace_cart_items(cart_id);

create index marketplace_cart_items_artwork_id_idx
  on public.marketplace_cart_items(artwork_id);

create index marketplace_cart_items_listing_id_idx
  on public.marketplace_cart_items(listing_id);

create index marketplace_cart_items_added_from_offer_id_idx
  on public.marketplace_cart_items(added_from_offer_id);

create table public.marketplace_checkout_intents (
  id bigint generated always as identity primary key,
  buyer_profile_id bigint not null references public.profiles(id),
  cart_id bigint references public.marketplace_carts(id),
  status public.marketplace_checkout_intent_status not null default 'draft',
  currency_code text not null,
  subtotal_amount numeric(12,2) not null default 0,
  discount_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null default 0,
  expires_at timestamptz,
  submitted_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_checkout_intents_currency_code_chk check (
    currency_code ~ '^[A-Z]{3}$'
  ),
  constraint marketplace_checkout_intents_subtotal_nonnegative_chk check (
    subtotal_amount >= 0
  ),
  constraint marketplace_checkout_intents_discount_nonnegative_chk check (
    discount_amount >= 0
  ),
  constraint marketplace_checkout_intents_total_nonnegative_chk check (
    total_amount >= 0
  ),
  constraint marketplace_checkout_intents_discount_not_above_subtotal_chk check (
    discount_amount <= subtotal_amount
  ),
  constraint marketplace_checkout_intents_total_amount_consistency_chk check (
    total_amount = subtotal_amount - discount_amount
  ),
  constraint marketplace_checkout_intents_submitted_status_timestamp_chk check (
    submitted_at is null or status = 'submitted'
  ),
  constraint marketplace_checkout_intents_cancelled_status_timestamp_chk check (
    cancelled_at is null or status = 'cancelled'
  ),
  constraint marketplace_checkout_intents_terminal_timestamps_exclusive_chk check (
    num_nonnulls(submitted_at, cancelled_at) <= 1
  ),
  constraint marketplace_checkout_intents_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index marketplace_checkout_intents_buyer_profile_id_idx
  on public.marketplace_checkout_intents(buyer_profile_id);

create index marketplace_checkout_intents_cart_id_idx
  on public.marketplace_checkout_intents(cart_id);

create index marketplace_checkout_intents_status_idx
  on public.marketplace_checkout_intents(status);

create index marketplace_checkout_intents_expires_at_idx
  on public.marketplace_checkout_intents(expires_at);

create index marketplace_checkout_intents_created_at_idx
  on public.marketplace_checkout_intents(created_at);

create table public.marketplace_checkout_intent_items (
  id bigint generated always as identity primary key,
  checkout_intent_id bigint not null references public.marketplace_checkout_intents(id) on delete cascade,
  source_type public.marketplace_checkout_item_source_type not null,
  cart_item_id bigint references public.marketplace_cart_items(id),
  artwork_id bigint references public.artworks(id),
  listing_id bigint references public.listings(id),
  offer_id bigint references public.marketplace_offers(id),
  unit_amount numeric(12,2) not null,
  quantity integer not null default 1,
  line_subtotal_amount numeric(12,2) not null,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  constraint marketplace_checkout_intent_items_unit_amount_nonnegative_chk check (
    unit_amount >= 0
  ),
  constraint marketplace_checkout_intent_items_quantity_positive_chk check (
    quantity > 0
  ),
  constraint marketplace_checkout_intent_items_line_subtotal_nonnegative_chk check (
    line_subtotal_amount >= 0
  ),
  constraint marketplace_checkout_intent_items_line_subtotal_consistency_chk check (
    line_subtotal_amount = unit_amount * quantity
  ),
  constraint marketplace_checkout_intent_items_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  ),
  constraint marketplace_checkout_intent_items_source_link_chk check (
    (
      source_type = 'cart_item'
      and cart_item_id is not null
      and artwork_id is null
      and listing_id is null
      and offer_id is null
    )
    or
    (
      source_type = 'listing'
      and cart_item_id is null
      and artwork_id is null
      and listing_id is not null
      and offer_id is null
    )
    or
    (
      source_type = 'artwork'
      and cart_item_id is null
      and artwork_id is not null
      and listing_id is null
      and offer_id is null
    )
    or
    (
      source_type = 'accepted_offer'
      and cart_item_id is null
      and artwork_id is null
      and listing_id is null
      and offer_id is not null
    )
  )
);

create index marketplace_checkout_intent_items_checkout_intent_id_idx
  on public.marketplace_checkout_intent_items(checkout_intent_id);

create index marketplace_checkout_intent_items_cart_item_id_idx
  on public.marketplace_checkout_intent_items(cart_item_id);

create index marketplace_checkout_intent_items_artwork_id_idx
  on public.marketplace_checkout_intent_items(artwork_id);

create index marketplace_checkout_intent_items_listing_id_idx
  on public.marketplace_checkout_intent_items(listing_id);

create index marketplace_checkout_intent_items_offer_id_idx
  on public.marketplace_checkout_intent_items(offer_id);

create index marketplace_checkout_intent_items_source_type_idx
  on public.marketplace_checkout_intent_items(source_type);
