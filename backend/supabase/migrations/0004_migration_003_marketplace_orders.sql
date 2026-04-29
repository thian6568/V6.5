-- Migration 003 marketplace/orders tables.
-- Scope: listings, orders, order_items.
-- Guardrails:
-- - artworks remains the single artwork identity path.
-- - no VR-only artwork path.
-- - no escrow fields are added to orders in this migration.

-- Enums required for Migration 003.
do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'listing_status'
  ) then
    create type public.listing_status as enum ('draft', 'submitted', 'approved', 'live', 'paused', 'archived');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'order_status'
  ) then
    create type public.order_status as enum ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded', 'disputed');
  end if;
end
$$;

create table public.listings (
  id bigint generated always as identity primary key,
  artwork_id bigint not null references public.artworks(id) on delete restrict,
  seller_profile_id bigint not null references public.profiles(id) on delete restrict,
  status public.listing_status not null default 'draft',
  ask_price numeric(12, 2) not null,
  currency_code char(3) not null default 'USD',
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint listings_ask_price_nonnegative_chk check (ask_price >= 0),
  constraint listings_currency_code_upper_chk check (currency_code = upper(currency_code))
);

create index listings_artwork_id_idx on public.listings(artwork_id);
create index listings_seller_profile_id_idx on public.listings(seller_profile_id);
create index listings_status_idx on public.listings(status);

create table public.orders (
  id bigint generated always as identity primary key,
  buyer_profile_id bigint not null references public.profiles(id) on delete restrict,
  status public.order_status not null default 'pending',
  order_number text not null unique,
  subtotal_amount numeric(12, 2) not null,
  total_amount numeric(12, 2) not null,
  currency_code char(3) not null default 'USD',
  placed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint orders_order_number_nonempty_chk check (length(trim(order_number)) > 0),
  constraint orders_subtotal_nonnegative_chk check (subtotal_amount >= 0),
  constraint orders_total_nonnegative_chk check (total_amount >= 0),
  constraint orders_total_at_least_subtotal_chk check (total_amount >= subtotal_amount),
  constraint orders_currency_code_upper_chk check (currency_code = upper(currency_code))
);

create index orders_buyer_profile_id_idx on public.orders(buyer_profile_id);
create index orders_status_idx on public.orders(status);
create index orders_placed_at_idx on public.orders(placed_at desc);

create table public.order_items (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  artwork_id bigint not null references public.artworks(id) on delete restrict,
  quantity integer not null default 1,
  unit_price numeric(12, 2) not null,
  line_total numeric(12, 2) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint order_items_quantity_positive_chk check (quantity > 0),
  constraint order_items_unit_price_nonnegative_chk check (unit_price >= 0),
  constraint order_items_line_total_nonnegative_chk check (line_total >= 0),
  constraint order_items_line_total_match_chk check (line_total = round((unit_price * quantity)::numeric, 2)),
  constraint order_items_order_id_artwork_id_key unique (order_id, artwork_id)
);

create index order_items_order_id_idx on public.order_items(order_id);
create index order_items_artwork_id_idx on public.order_items(artwork_id);
