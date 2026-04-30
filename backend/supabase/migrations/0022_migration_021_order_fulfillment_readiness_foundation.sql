-- Migration 021 order fulfillment readiness foundation.
-- Scope: backend-only fulfillment readiness checks and event tracking after order status lifecycle.
-- Guardrails:
-- - public.artworks remains the single artwork identity path.
-- - no second artwork table or upload identity path.
-- - no coupling to environments or homepage/admin content logic.
-- - backend foundation only; no frontend/UI implementation.
-- - no AI, bots, or agents.
-- - no payment capture.
-- - no payment gateway integration.
-- - no escrow release logic.
-- - no crypto.
-- - no live shipping execution.
-- - no real tax calculation execution.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_fulfillment_readiness_status'
  ) then
    create type public.marketplace_order_fulfillment_readiness_status as enum (
      'pending_review',
      'ready',
      'blocked',
      'not_required',
      'cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_fulfillment_readiness_item_type'
  ) then
    create type public.marketplace_order_fulfillment_readiness_item_type as enum (
      'order_items_verified',
      'buyer_contact_confirmed',
      'seller_confirmation',
      'delivery_preference_confirmed',
      'invoice_snapshot_confirmed',
      'payment_readiness_confirmed',
      'manual_review',
      'note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_fulfillment_readiness_event_type'
  ) then
    create type public.marketplace_order_fulfillment_readiness_event_type as enum (
      'readiness_check_created',
      'readiness_check_updated',
      'readiness_check_passed',
      'readiness_check_blocked',
      'readiness_check_cancelled',
      'blocker_added',
      'blocker_resolved',
      'manual_note_added'
    );
  end if;
end
$$;

create table public.marketplace_order_fulfillment_readiness_checks (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  order_item_id bigint,
  actor_profile_id bigint,
  item_type public.marketplace_order_fulfillment_readiness_item_type not null,
  status public.marketplace_order_fulfillment_readiness_status not null default 'pending_review',
  is_required boolean not null default true,
  check_label text not null,
  blocker_reason text,
  reviewed_at timestamptz,
  due_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint fulfillment_readiness_checks_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint fulfillment_readiness_checks_order_item_id_fk
    foreign key (order_item_id)
    references public.order_items(id)
    on delete cascade,

  constraint fulfillment_readiness_checks_actor_profile_id_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint fulfillment_readiness_checks_label_nonblank_chk check (
    btrim(check_label) <> ''
  ),
  constraint fulfillment_readiness_checks_blocker_nonblank_chk check (
    blocker_reason is null or btrim(blocker_reason) <> ''
  ),
  constraint fulfillment_readiness_checks_blocked_reason_chk check (
    status <> 'blocked' or blocker_reason is not null
  ),
  constraint fulfillment_readiness_checks_reviewed_status_chk check (
    reviewed_at is null
    or status in ('ready', 'blocked', 'not_required', 'cancelled')
  ),
  constraint fulfillment_readiness_checks_due_after_created_chk check (
    due_at is null or due_at >= created_at
  ),
  constraint fulfillment_readiness_checks_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index fulfillment_readiness_checks_active_item_idx
  on public.marketplace_order_fulfillment_readiness_checks (
    order_id,
    item_type,
    order_item_id
  )
  where order_item_id is not null
    and status in ('pending_review', 'ready', 'blocked');

create unique index fulfillment_readiness_checks_active_order_idx
  on public.marketplace_order_fulfillment_readiness_checks (
    order_id,
    item_type
  )
  where order_item_id is null
    and status in ('pending_review', 'ready', 'blocked');

create index fulfillment_readiness_checks_order_id_idx
  on public.marketplace_order_fulfillment_readiness_checks(order_id);

create index fulfillment_readiness_checks_order_item_id_idx
  on public.marketplace_order_fulfillment_readiness_checks(order_item_id);

create index fulfillment_readiness_checks_actor_profile_id_idx
  on public.marketplace_order_fulfillment_readiness_checks(actor_profile_id);

create index fulfillment_readiness_checks_item_type_idx
  on public.marketplace_order_fulfillment_readiness_checks(item_type);

create index fulfillment_readiness_checks_status_idx
  on public.marketplace_order_fulfillment_readiness_checks(status);

create index fulfillment_readiness_checks_is_required_idx
  on public.marketplace_order_fulfillment_readiness_checks(is_required);

create index fulfillment_readiness_checks_due_at_idx
  on public.marketplace_order_fulfillment_readiness_checks(due_at);

create index fulfillment_readiness_checks_created_at_idx
  on public.marketplace_order_fulfillment_readiness_checks(created_at);

create table public.marketplace_order_fulfillment_readiness_events (
  id bigint generated always as identity primary key,
  readiness_check_id bigint,
  order_id bigint not null,
  actor_profile_id bigint,
  event_type public.marketplace_order_fulfillment_readiness_event_type not null,
  previous_status public.marketplace_order_fulfillment_readiness_status,
  new_status public.marketplace_order_fulfillment_readiness_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint fulfillment_readiness_events_check_id_fk
    foreign key (readiness_check_id)
    references public.marketplace_order_fulfillment_readiness_checks(id)
    on delete cascade,

  constraint fulfillment_readiness_events_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint fulfillment_readiness_events_actor_profile_id_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint fulfillment_readiness_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint fulfillment_readiness_events_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint fulfillment_readiness_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index fulfillment_readiness_events_check_id_idx
  on public.marketplace_order_fulfillment_readiness_events(readiness_check_id);

create index fulfillment_readiness_events_order_id_idx
  on public.marketplace_order_fulfillment_readiness_events(order_id);

create index fulfillment_readiness_events_actor_profile_id_idx
  on public.marketplace_order_fulfillment_readiness_events(actor_profile_id);

create index fulfillment_readiness_events_event_type_idx
  on public.marketplace_order_fulfillment_readiness_events(event_type);

create index fulfillment_readiness_events_previous_status_idx
  on public.marketplace_order_fulfillment_readiness_events(previous_status);

create index fulfillment_readiness_events_new_status_idx
  on public.marketplace_order_fulfillment_readiness_events(new_status);

create index fulfillment_readiness_events_created_at_idx
  on public.marketplace_order_fulfillment_readiness_events(created_at);
