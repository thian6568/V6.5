-- Migration 014 marketplace inquiries and contact foundation.
-- Scope: buyer/seller marketplace inquiries and inquiry message history.
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
      and t.typname = 'marketplace_inquiry_status'
  ) then
    create type public.marketplace_inquiry_status as enum (
      'open',
      'seller_replied',
      'buyer_replied',
      'closed',
      'archived'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_inquiry_sender_role'
  ) then
    create type public.marketplace_inquiry_sender_role as enum (
      'buyer',
      'seller',
      'admin',
      'system'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_contact_request_type'
  ) then
    create type public.marketplace_contact_request_type as enum (
      'general_question',
      'availability',
      'pricing',
      'commission_request',
      'shipping_question',
      'other'
    );
  end if;
end
$$;

create table public.marketplace_inquiries (
  id bigint generated always as identity primary key,
  buyer_profile_id bigint not null references public.profiles(id),
  seller_profile_id bigint not null references public.profiles(id),
  artwork_id bigint references public.artworks(id),
  listing_id bigint references public.listings(id),
  contact_request_type public.marketplace_contact_request_type not null default 'general_question',
  subject text not null,
  initial_message text not null,
  status public.marketplace_inquiry_status not null default 'open',
  is_active boolean not null default true,
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_inquiries_exactly_one_target_chk check (
    num_nonnulls(artwork_id, listing_id) = 1
  ),
  constraint marketplace_inquiries_buyer_seller_different_chk check (
    buyer_profile_id <> seller_profile_id
  ),
  constraint marketplace_inquiries_subject_nonblank_chk check (
    btrim(subject) <> ''
  ),
  constraint marketplace_inquiries_initial_message_nonblank_chk check (
    btrim(initial_message) <> ''
  )
);

create index marketplace_inquiries_buyer_profile_id_idx
  on public.marketplace_inquiries(buyer_profile_id);

create index marketplace_inquiries_seller_profile_id_idx
  on public.marketplace_inquiries(seller_profile_id);

create index marketplace_inquiries_artwork_id_idx
  on public.marketplace_inquiries(artwork_id);

create index marketplace_inquiries_listing_id_idx
  on public.marketplace_inquiries(listing_id);

create index marketplace_inquiries_status_idx
  on public.marketplace_inquiries(status);

create index marketplace_inquiries_is_active_idx
  on public.marketplace_inquiries(is_active);

create index marketplace_inquiries_last_message_at_idx
  on public.marketplace_inquiries(last_message_at);

create index marketplace_inquiries_created_at_idx
  on public.marketplace_inquiries(created_at);

create table public.marketplace_inquiry_messages (
  id bigint generated always as identity primary key,
  inquiry_id bigint not null references public.marketplace_inquiries(id) on delete cascade,
  sender_profile_id bigint references public.profiles(id) on delete set null,
  sender_role public.marketplace_inquiry_sender_role not null,
  message_body text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint marketplace_inquiry_messages_message_body_nonblank_chk check (
    btrim(message_body) <> ''
  ),
  constraint marketplace_inquiry_messages_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index marketplace_inquiry_messages_inquiry_id_idx
  on public.marketplace_inquiry_messages(inquiry_id);

create index marketplace_inquiry_messages_sender_profile_id_idx
  on public.marketplace_inquiry_messages(sender_profile_id);

create index marketplace_inquiry_messages_sender_role_idx
  on public.marketplace_inquiry_messages(sender_role);

create index marketplace_inquiry_messages_created_at_idx
  on public.marketplace_inquiry_messages(created_at);
