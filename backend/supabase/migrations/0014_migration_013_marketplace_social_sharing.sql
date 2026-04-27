-- Migration 013 marketplace social sharing foundation.
-- Scope: marketplace share links and share event tracking.
-- Guardrails:
-- - artworks remains the single artwork identity path.
-- - no second artwork table or upload identity path.
-- - no coupling to environments or homepage/admin content logic.
-- - backend foundation only; no frontend/UI implementation.
-- - no AI, bots, or agents.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_share_channel'
  ) then
    create type public.marketplace_share_channel as enum (
      'direct_link',
      'email',
      'whatsapp',
      'facebook',
      'instagram',
      'x',
      'linkedin',
      'pinterest',
      'other'
    );
  end if;
end
$$;

create table public.marketplace_share_links (
  id bigint generated always as identity primary key,
  profile_id bigint references public.profiles(id) on delete set null,
  artwork_id bigint references public.artworks(id) on delete cascade,
  listing_id bigint references public.listings(id) on delete cascade,
  share_token text not null,
  share_channel public.marketplace_share_channel not null default 'direct_link',
  destination_url text,
  expires_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_share_links_exactly_one_target_chk check (
    num_nonnulls(artwork_id, listing_id) = 1
  ),
  constraint marketplace_share_links_share_token_nonblank_chk check (
    btrim(share_token) <> ''
  ),
  constraint marketplace_share_links_destination_url_nonblank_chk check (
    destination_url is null or btrim(destination_url) <> ''
  ),
  constraint marketplace_share_links_share_token_key unique (share_token)
);

create index marketplace_share_links_profile_id_idx
  on public.marketplace_share_links(profile_id);

create index marketplace_share_links_artwork_id_idx
  on public.marketplace_share_links(artwork_id);

create index marketplace_share_links_listing_id_idx
  on public.marketplace_share_links(listing_id);

create index marketplace_share_links_share_channel_idx
  on public.marketplace_share_links(share_channel);

create index marketplace_share_links_is_active_idx
  on public.marketplace_share_links(is_active);

create index marketplace_share_links_expires_at_idx
  on public.marketplace_share_links(expires_at);

create table public.marketplace_share_events (
  id bigint generated always as identity primary key,
  share_link_id bigint not null references public.marketplace_share_links(id) on delete cascade,
  viewer_profile_id bigint references public.profiles(id) on delete set null,
  event_type text not null default 'view',
  referrer text,
  user_agent text,
  ip_hash text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint marketplace_share_events_event_type_nonblank_chk check (
    btrim(event_type) <> ''
  ),
  constraint marketplace_share_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index marketplace_share_events_share_link_id_idx
  on public.marketplace_share_events(share_link_id);

create index marketplace_share_events_viewer_profile_id_idx
  on public.marketplace_share_events(viewer_profile_id);

create index marketplace_share_events_event_type_idx
  on public.marketplace_share_events(event_type);

create index marketplace_share_events_created_at_idx
  on public.marketplace_share_events(created_at);
