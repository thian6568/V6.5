-- Migration 002 shared artwork source of truth.
-- Scope: artworks, artwork_assets, artwork_authentication, certificates, ownership_history.
-- Guardrail: artworks.id is the only artwork identity referenced by related tables.

-- Enums required for Migration 002 tables.
do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'publish_status'
  ) then
    create type public.publish_status as enum ('draft', 'submitted', 'approved', 'live', 'paused', 'archived');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'visibility_mode'
  ) then
    create type public.visibility_mode as enum ('marketplace_only', 'vr_only', 'both');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'authentication_status'
  ) then
    create type public.authentication_status as enum ('pending', 'approved', 'rejected');
  end if;
end
$$;

create table public.artworks (
  id bigint generated always as identity primary key,
  artist_profile_id bigint not null references public.profiles(id) on delete restrict,
  title text not null,
  description text,
  publish_status public.publish_status not null default 'draft',
  visibility_mode public.visibility_mode not null default 'marketplace_only',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint artworks_title_nonempty_chk check (length(trim(title)) > 0)
);

create index artworks_artist_profile_id_idx on public.artworks(artist_profile_id);
create index artworks_publish_status_idx on public.artworks(publish_status);
create index artworks_visibility_mode_idx on public.artworks(visibility_mode);

create table public.artwork_assets (
  id bigint generated always as identity primary key,
  artwork_id bigint not null references public.artworks(id) on delete cascade,
  asset_type text not null,
  storage_path text not null,
  sort_order integer not null default 0,
  is_primary boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint artwork_assets_asset_type_nonempty_chk check (length(trim(asset_type)) > 0),
  constraint artwork_assets_storage_path_nonempty_chk check (length(trim(storage_path)) > 0),
  constraint artwork_assets_sort_order_nonnegative_chk check (sort_order >= 0),
  constraint artwork_assets_unique_path_per_artwork unique (artwork_id, storage_path)
);

create index artwork_assets_artwork_id_idx on public.artwork_assets(artwork_id);
create index artwork_assets_primary_idx on public.artwork_assets(artwork_id, is_primary);

create table public.artwork_authentication (
  id bigint generated always as identity primary key,
  artwork_id bigint not null unique references public.artworks(id) on delete cascade,
  status public.authentication_status not null default 'pending',
  submitted_at timestamptz,
  reviewed_at timestamptz,
  verified_by_profile_id bigint references public.profiles(id) on delete set null,
  review_notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint artwork_authentication_reviewed_after_submitted_chk check (
    reviewed_at is null or submitted_at is null or reviewed_at >= submitted_at
  )
);

create index artwork_authentication_status_idx on public.artwork_authentication(status);
create index artwork_authentication_verified_by_idx on public.artwork_authentication(verified_by_profile_id);

create table public.certificates (
  id bigint generated always as identity primary key,
  artwork_id bigint not null references public.artworks(id) on delete cascade,
  certificate_number text not null unique,
  issued_at timestamptz not null default now(),
  issued_by_profile_id bigint references public.profiles(id) on delete set null,
  revoked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint certificates_number_nonempty_chk check (length(trim(certificate_number)) > 0),
  constraint certificates_revoked_after_issued_chk check (revoked_at is null or revoked_at >= issued_at)
);

create index certificates_artwork_id_idx on public.certificates(artwork_id);

create table public.ownership_history (
  id bigint generated always as identity primary key,
  artwork_id bigint not null references public.artworks(id) on delete cascade,
  owner_profile_id bigint not null references public.profiles(id) on delete restrict,
  acquired_at timestamptz not null default now(),
  relinquished_at timestamptz,
  transfer_reference text,
  is_current boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ownership_history_dates_chk check (relinquished_at is null or relinquished_at >= acquired_at)
);

create index ownership_history_artwork_id_idx on public.ownership_history(artwork_id);
create index ownership_history_owner_profile_id_idx on public.ownership_history(owner_profile_id);
create unique index ownership_history_one_current_owner_idx
  on public.ownership_history(artwork_id)
  where is_current;
