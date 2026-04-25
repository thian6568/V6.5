-- Migration 009 marketplace navigation foundation.
-- Scope: marketplace categories, section metadata, and listing discovery controls.
-- Guardrails:
-- - artworks remains the single artwork identity path.
-- - no second artwork table or upload identity path.
-- - no coupling to environments or homepage/admin content logic.

-- Enums required for Migration 009.
do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'marketplace_section_type'
  ) then
    create type public.marketplace_section_type as enum (
      'category',
      'curated',
      'featured',
      'new_arrivals',
      'sale'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'marketplace_visibility_status'
  ) then
    create type public.marketplace_visibility_status as enum (
      'hidden',
      'visible',
      'scheduled'
    );
  end if;
end
$$;

-- Hierarchical marketplace browse categories.
create table public.marketplace_categories (
  id bigint generated always as identity primary key,
  parent_category_id bigint references public.marketplace_categories(id) on delete set null,
  slug text not null,
  name text not null,
  description text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_categories_slug_nonblank_chk check (btrim(slug) <> ''),
  constraint marketplace_categories_name_nonblank_chk check (btrim(name) <> ''),
  constraint marketplace_categories_sort_order_nonnegative_chk check (sort_order >= 0),
  constraint marketplace_categories_slug_key unique (slug)
);

create index marketplace_categories_parent_category_id_idx
  on public.marketplace_categories(parent_category_id);
create index marketplace_categories_is_active_idx
  on public.marketplace_categories(is_active);
create index marketplace_categories_is_active_sort_order_idx
  on public.marketplace_categories(is_active, sort_order);

-- Map artworks to marketplace categories (artworks stays canonical identity).
create table public.artwork_category_assignments (
  id bigint generated always as identity primary key,
  artwork_id bigint not null references public.artworks(id) on delete cascade,
  category_id bigint not null references public.marketplace_categories(id) on delete cascade,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  constraint artwork_category_assignments_artwork_id_category_id_key unique (artwork_id, category_id)
);

create index artwork_category_assignments_artwork_id_idx
  on public.artwork_category_assignments(artwork_id);
create index artwork_category_assignments_category_id_idx
  on public.artwork_category_assignments(category_id);
create unique index artwork_category_assignments_one_primary_per_artwork_idx
  on public.artwork_category_assignments(artwork_id)
  where is_primary;

-- Backend-defined marketplace sections.
create table public.marketplace_sections (
  id bigint generated always as identity primary key,
  slug text not null,
  title text not null,
  description text,
  section_type public.marketplace_section_type not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_by_profile_id bigint not null references public.profiles(id) on delete restrict,
  updated_by_profile_id bigint references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_sections_slug_nonblank_chk check (btrim(slug) <> ''),
  constraint marketplace_sections_title_nonblank_chk check (btrim(title) <> ''),
  constraint marketplace_sections_sort_order_nonnegative_chk check (sort_order >= 0),
  constraint marketplace_sections_slug_key unique (slug)
);

create index marketplace_sections_section_type_idx
  on public.marketplace_sections(section_type);
create index marketplace_sections_is_active_idx
  on public.marketplace_sections(is_active);
create index marketplace_sections_is_active_sort_order_idx
  on public.marketplace_sections(is_active, sort_order);

-- Map section items to exactly one artwork or one listing.
create table public.marketplace_section_items (
  id bigint generated always as identity primary key,
  section_id bigint not null references public.marketplace_sections(id) on delete cascade,
  artwork_id bigint references public.artworks(id) on delete cascade,
  listing_id bigint references public.listings(id) on delete cascade,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint marketplace_section_items_exactly_one_target_chk check (
    num_nonnulls(artwork_id, listing_id) = 1
  )
);

create index marketplace_section_items_section_id_idx
  on public.marketplace_section_items(section_id);
create index marketplace_section_items_artwork_id_idx
  on public.marketplace_section_items(artwork_id);
create index marketplace_section_items_listing_id_idx
  on public.marketplace_section_items(listing_id);
create index marketplace_section_items_section_id_sort_order_idx
  on public.marketplace_section_items(section_id, sort_order);

-- Listing-level marketplace discovery controls.
alter table public.listings
  add column if not exists marketplace_visibility public.marketplace_visibility_status not null default 'hidden',
  add column if not exists discovery_rank integer not null default 0,
  add column if not exists is_featured boolean not null default false,
  add column if not exists available_from timestamptz,
  add column if not exists available_until timestamptz;

alter table public.listings
  add constraint listings_discovery_rank_nonnegative_chk check (discovery_rank >= 0),
  add constraint listings_available_window_chk check (
    available_until is null
    or available_from is null
    or available_until >= available_from
  );

create index listings_marketplace_visibility_idx
  on public.listings(marketplace_visibility);
create index listings_is_featured_idx
  on public.listings(is_featured);
create index listings_discovery_rank_idx
  on public.listings(discovery_rank);
create index listings_available_from_idx
  on public.listings(available_from);
create index listings_available_until_idx
  on public.listings(available_until);
