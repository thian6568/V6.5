-- Migration 012 marketplace collections and wishlist foundation.
-- Scope: marketplace collections, collection items, wishlists, and wishlist items.
-- Guardrails:
-- - artworks remains the single artwork identity path.
-- - no second artwork table or upload identity path.
-- - no coupling to environments or homepage/admin content logic.
-- - backend foundation only; no frontend/UI implementation.

create table public.marketplace_collections (
  id bigint generated always as identity primary key,
  slug text not null,
  title text not null,
  description text,
  created_by_profile_id bigint references public.profiles(id) on delete set null,
  updated_by_profile_id bigint references public.profiles(id) on delete set null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_collections_slug_nonblank_chk check (btrim(slug) <> ''),
  constraint marketplace_collections_title_nonblank_chk check (btrim(title) <> ''),
  constraint marketplace_collections_sort_order_nonnegative_chk check (sort_order >= 0),
  constraint marketplace_collections_slug_key unique (slug)
);

create index marketplace_collections_created_by_profile_id_idx
  on public.marketplace_collections(created_by_profile_id);

create index marketplace_collections_updated_by_profile_id_idx
  on public.marketplace_collections(updated_by_profile_id);

create index marketplace_collections_is_active_idx
  on public.marketplace_collections(is_active);

create index marketplace_collections_is_active_sort_order_idx
  on public.marketplace_collections(is_active, sort_order);

create table public.marketplace_collection_items (
  id bigint generated always as identity primary key,
  collection_id bigint not null references public.marketplace_collections(id) on delete cascade,
  artwork_id bigint references public.artworks(id) on delete cascade,
  listing_id bigint references public.listings(id) on delete cascade,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint marketplace_collection_items_sort_order_nonnegative_chk check (sort_order >= 0),
  constraint marketplace_collection_items_exactly_one_target_chk check (
    num_nonnulls(artwork_id, listing_id) = 1
  )
);

create index marketplace_collection_items_collection_id_idx
  on public.marketplace_collection_items(collection_id);

create index marketplace_collection_items_artwork_id_idx
  on public.marketplace_collection_items(artwork_id);

create index marketplace_collection_items_listing_id_idx
  on public.marketplace_collection_items(listing_id);

create index marketplace_collection_items_collection_id_sort_order_idx
  on public.marketplace_collection_items(collection_id, sort_order);

create unique index marketplace_collection_items_collection_artwork_unique_idx
  on public.marketplace_collection_items(collection_id, artwork_id)
  where artwork_id is not null;

create unique index marketplace_collection_items_collection_listing_unique_idx
  on public.marketplace_collection_items(collection_id, listing_id)
  where listing_id is not null;

create table public.wishlists (
  id bigint generated always as identity primary key,
  profile_id bigint not null references public.profiles(id) on delete cascade,
  name text not null default 'Default Wishlist',
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint wishlists_name_nonblank_chk check (btrim(name) <> '')
);

create index wishlists_profile_id_idx
  on public.wishlists(profile_id);

create index wishlists_profile_id_is_active_idx
  on public.wishlists(profile_id, is_active);

create unique index wishlists_one_default_per_profile_idx
  on public.wishlists(profile_id)
  where is_default = true;

create table public.wishlist_items (
  id bigint generated always as identity primary key,
  wishlist_id bigint not null references public.wishlists(id) on delete cascade,
  artwork_id bigint references public.artworks(id) on delete cascade,
  listing_id bigint references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint wishlist_items_exactly_one_target_chk check (
    num_nonnulls(artwork_id, listing_id) = 1
  )
);

create index wishlist_items_wishlist_id_idx
  on public.wishlist_items(wishlist_id);

create index wishlist_items_artwork_id_idx
  on public.wishlist_items(artwork_id);

create index wishlist_items_listing_id_idx
  on public.wishlist_items(listing_id);

create unique index wishlist_items_wishlist_artwork_unique_idx
  on public.wishlist_items(wishlist_id, artwork_id)
  where artwork_id is not null;

create unique index wishlist_items_wishlist_listing_unique_idx
  on public.wishlist_items(wishlist_id, listing_id)
  where listing_id is not null;
