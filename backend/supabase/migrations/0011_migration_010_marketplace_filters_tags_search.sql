-- Migration 010 marketplace filters, tags, and search metadata foundation.
-- Scope: marketplace tags, listing filter metadata, and lightweight listing search fields.
-- Guardrails:
-- - artworks remains the single artwork identity path.
-- - no second artwork table or upload identity path.
-- - no coupling to environments or homepage/admin content logic.

-- Enums required for Migration 010.
do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'marketplace_tag_type'
  ) then
    create type public.marketplace_tag_type as enum (
      'style',
      'medium',
      'subject',
      'material',
      'technique',
      'color',
      'theme',
      'custom'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'marketplace_price_bucket'
  ) then
    create type public.marketplace_price_bucket as enum (
      'budget',
      'midrange',
      'premium',
      'high_end'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'marketplace_size_bucket'
  ) then
    create type public.marketplace_size_bucket as enum (
      'small',
      'medium',
      'large',
      'oversized'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'marketplace_orientation'
  ) then
    create type public.marketplace_orientation as enum (
      'portrait',
      'landscape',
      'square',
      'panoramic'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'marketplace_availability_bucket'
  ) then
    create type public.marketplace_availability_bucket as enum (
      'available_now',
      'scheduled',
      'sold',
      'reserved'
    );
  end if;
end
$$;

create table public.marketplace_tags (
  id bigint generated always as identity primary key,
  slug text not null,
  name text not null,
  description text,
  tag_type public.marketplace_tag_type not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_tags_slug_nonblank_chk check (btrim(slug) <> ''),
  constraint marketplace_tags_name_nonblank_chk check (btrim(name) <> ''),
  constraint marketplace_tags_sort_order_nonnegative_chk check (sort_order >= 0),
  constraint marketplace_tags_slug_key unique (slug)
);

create index marketplace_tags_tag_type_idx
  on public.marketplace_tags(tag_type);
create index marketplace_tags_is_active_idx
  on public.marketplace_tags(is_active);
create index marketplace_tags_is_active_sort_order_idx
  on public.marketplace_tags(is_active, sort_order);

create table public.artwork_tag_assignments (
  id bigint generated always as identity primary key,
  artwork_id bigint not null references public.artworks(id) on delete cascade,
  tag_id bigint not null references public.marketplace_tags(id) on delete cascade,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  constraint artwork_tag_assignments_artwork_id_tag_id_key unique (artwork_id, tag_id)
);

create index artwork_tag_assignments_artwork_id_idx
  on public.artwork_tag_assignments(artwork_id);
create index artwork_tag_assignments_tag_id_idx
  on public.artwork_tag_assignments(tag_id);
create index artwork_tag_assignments_primary_artwork_idx
  on public.artwork_tag_assignments(artwork_id)
  where is_primary;

create table public.listing_filter_metadata (
  id bigint generated always as identity primary key,
  listing_id bigint not null references public.listings(id) on delete cascade,
  price_bucket public.marketplace_price_bucket,
  size_bucket public.marketplace_size_bucket,
  orientation public.marketplace_orientation,
  availability_bucket public.marketplace_availability_bucket,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint listing_filter_metadata_listing_id_key unique (listing_id)
);

create index listing_filter_metadata_price_bucket_idx
  on public.listing_filter_metadata(price_bucket);
create index listing_filter_metadata_size_bucket_idx
  on public.listing_filter_metadata(size_bucket);
create index listing_filter_metadata_orientation_idx
  on public.listing_filter_metadata(orientation);
create index listing_filter_metadata_availability_bucket_idx
  on public.listing_filter_metadata(availability_bucket);

alter table public.listings
  add column if not exists search_keywords text,
  add column if not exists search_document text,
  add column if not exists is_searchable boolean not null default true;

alter table public.listings
  add constraint listings_search_keywords_nonblank_chk check (
    search_keywords is null or btrim(search_keywords) <> ''
  ),
  add constraint listings_search_document_nonblank_chk check (
    search_document is null or btrim(search_document) <> ''
  );

create index listings_is_searchable_idx
  on public.listings(is_searchable);
