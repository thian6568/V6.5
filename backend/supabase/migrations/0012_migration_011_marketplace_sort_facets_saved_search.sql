-- Migration 011 marketplace sort, facets, and saved search foundation.
-- Scope: marketplace sort configuration, facet configuration, and saved searches.
-- Guardrails:
-- - artworks remains the single artwork identity path.
-- - no second artwork table or upload identity path.
-- - no coupling to environments or homepage/admin content logic.

-- Enums required for Migration 011.
do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'marketplace_sort_direction'
  ) then
    create type public.marketplace_sort_direction as enum (
      'asc',
      'desc'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'marketplace_sort_key'
  ) then
    create type public.marketplace_sort_key as enum (
      'price',
      'created_at',
      'discovery_rank',
      'available_from'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'marketplace_facet_source_type'
  ) then
    create type public.marketplace_facet_source_type as enum (
      'listing_filter_metadata',
      'marketplace_tags',
      'listings'
    );
  end if;
end
$$;

create table public.marketplace_sort_options (
  id bigint generated always as identity primary key,
  slug text not null,
  name text not null,
  description text,
  sort_key public.marketplace_sort_key not null,
  sort_direction public.marketplace_sort_direction not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_sort_options_slug_nonblank_chk check (btrim(slug) <> ''),
  constraint marketplace_sort_options_name_nonblank_chk check (btrim(name) <> ''),
  constraint marketplace_sort_options_sort_order_nonnegative_chk check (sort_order >= 0),
  constraint marketplace_sort_options_slug_key unique (slug)
);

create index marketplace_sort_options_is_active_idx
  on public.marketplace_sort_options(is_active);
create index marketplace_sort_options_is_active_sort_order_idx
  on public.marketplace_sort_options(is_active, sort_order);
create index marketplace_sort_options_sort_key_idx
  on public.marketplace_sort_options(sort_key);

create table public.marketplace_facet_configs (
  id bigint generated always as identity primary key,
  facet_key text not null,
  label text not null,
  source_type public.marketplace_facet_source_type not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  is_multiselect boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_facet_configs_facet_key_nonblank_chk check (btrim(facet_key) <> ''),
  constraint marketplace_facet_configs_label_nonblank_chk check (btrim(label) <> ''),
  constraint marketplace_facet_configs_sort_order_nonnegative_chk check (sort_order >= 0),
  constraint marketplace_facet_configs_facet_key_key unique (facet_key)
);

create index marketplace_facet_configs_source_type_idx
  on public.marketplace_facet_configs(source_type);
create index marketplace_facet_configs_is_active_idx
  on public.marketplace_facet_configs(is_active);
create index marketplace_facet_configs_is_active_sort_order_idx
  on public.marketplace_facet_configs(is_active, sort_order);

create table public.saved_searches (
  id bigint generated always as identity primary key,
  profile_id bigint not null references public.profiles(id) on delete cascade,
  name text not null,
  query_text text,
  sort_option_id bigint references public.marketplace_sort_options(id) on delete set null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint saved_searches_name_nonblank_chk check (btrim(name) <> ''),
  constraint saved_searches_query_text_nonblank_chk check (
    query_text is null or btrim(query_text) <> ''
  )
);

create index saved_searches_profile_id_idx
  on public.saved_searches(profile_id);
create index saved_searches_sort_option_id_idx
  on public.saved_searches(sort_option_id);
create index saved_searches_profile_id_is_active_idx
  on public.saved_searches(profile_id, is_active);

create table public.saved_search_filters (
  id bigint generated always as identity primary key,
  saved_search_id bigint not null references public.saved_searches(id) on delete cascade,
  filter_key text not null,
  filter_value text not null,
  created_at timestamptz not null default now(),
  constraint saved_search_filters_filter_key_nonblank_chk check (btrim(filter_key) <> ''),
  constraint saved_search_filters_filter_value_nonblank_chk check (btrim(filter_value) <> '')
);

create index saved_search_filters_saved_search_id_idx
  on public.saved_search_filters(saved_search_id);
create index saved_search_filters_filter_key_idx
  on public.saved_search_filters(filter_key);
create index saved_search_filters_saved_search_id_filter_key_idx
  on public.saved_search_filters(saved_search_id, filter_key);
