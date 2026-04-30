-- Migration 022 order handover foundation.
-- Scope: backend-only order handover records and event tracking after fulfillment readiness.
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
      and t.typname = 'marketplace_order_handover_status'
  ) then
    create type public.marketplace_order_handover_status as enum (
      'pending_readiness',
      'ready_for_handover',
      'handover_in_progress',
      'handover_confirmed',
      'handover_blocked',
      'handover_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_handover_event_type'
  ) then
    create type public.marketplace_order_handover_event_type as enum (
      'handover_created',
      'readiness_attached',
      'handover_ready',
      'handover_started',
      'buyer_confirmed',
      'seller_confirmed',
      'handover_confirmed',
      'handover_blocked',
      'handover_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_handover_actor_role'
  ) then
    create type public.marketplace_order_handover_actor_role as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_handover_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  readiness_check_id bigint,
  initiated_by_profile_id bigint,
  status public.marketplace_order_handover_status not null default 'pending_readiness',
  handover_reference text not null,
  handover_method_note text,
  buyer_confirmed_at timestamptz,
  seller_confirmed_at timestamptz,
  ready_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  blocked_at timestamptz,
  cancelled_at timestamptz,
  blocker_reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint handover_records_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint handover_records_readiness_check_id_fk
    foreign key (readiness_check_id)
    references public.marketplace_order_fulfillment_readiness_checks(id)
    on delete set null,

  constraint handover_records_initiated_by_profile_id_fk
    foreign key (initiated_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint handover_records_reference_nonblank_chk check (
    btrim(handover_reference) <> ''
  ),
  constraint handover_records_method_note_nonblank_chk check (
    handover_method_note is null or btrim(handover_method_note) <> ''
  ),
  constraint handover_records_blocker_nonblank_chk check (
    blocker_reason is null or btrim(blocker_reason) <> ''
  ),
  constraint handover_records_blocked_reason_chk check (
    status <> 'handover_blocked' or blocker_reason is not null
  ),
  constraint handover_records_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_handover',
      'handover_in_progress',
      'handover_confirmed',
      'handover_blocked',
      'handover_cancelled'
    )
  ),
  constraint handover_records_started_status_chk check (
    started_at is null
    or status in (
      'handover_in_progress',
      'handover_confirmed',
      'handover_blocked',
      'handover_cancelled'
    )
  ),
  constraint handover_records_completed_status_chk check (
    completed_at is null or status = 'handover_confirmed'
  ),
  constraint handover_records_blocked_status_chk check (
    blocked_at is null or status = 'handover_blocked'
  ),
  constraint handover_records_cancelled_status_chk check (
    cancelled_at is null or status = 'handover_cancelled'
  ),
  constraint handover_records_terminal_exclusive_chk check (
    num_nonnulls(completed_at, blocked_at, cancelled_at) <= 1
  ),
  constraint handover_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index handover_records_reference_key
  on public.marketplace_order_handover_records(handover_reference);

create unique index handover_records_one_active_per_order_idx
  on public.marketplace_order_handover_records(order_id)
  where status in (
    'pending_readiness',
    'ready_for_handover',
    'handover_in_progress',
    'handover_blocked'
  );

create index handover_records_order_id_idx
  on public.marketplace_order_handover_records(order_id);

create index handover_records_readiness_check_id_idx
  on public.marketplace_order_handover_records(readiness_check_id);

create index handover_records_initiated_by_profile_id_idx
  on public.marketplace_order_handover_records(initiated_by_profile_id);

create index handover_records_status_idx
  on public.marketplace_order_handover_records(status);

create index handover_records_ready_at_idx
  on public.marketplace_order_handover_records(ready_at);

create index handover_records_started_at_idx
  on public.marketplace_order_handover_records(started_at);

create index handover_records_completed_at_idx
  on public.marketplace_order_handover_records(completed_at);

create index handover_records_created_at_idx
  on public.marketplace_order_handover_records(created_at);

create table public.marketplace_order_handover_events (
  id bigint generated always as identity primary key,
  handover_record_id bigint not null,
  order_id bigint not null,
  actor_profile_id bigint,
  actor_role public.marketplace_order_handover_actor_role not null default 'system',
  event_type public.marketplace_order_handover_event_type not null,
  previous_status public.marketplace_order_handover_status,
  new_status public.marketplace_order_handover_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint handover_events_handover_record_id_fk
    foreign key (handover_record_id)
    references public.marketplace_order_handover_records(id)
    on delete cascade,

  constraint handover_events_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint handover_events_actor_profile_id_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint handover_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint handover_events_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint handover_events_manual_note_required_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint handover_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index handover_events_handover_record_id_idx
  on public.marketplace_order_handover_events(handover_record_id);

create index handover_events_order_id_idx
  on public.marketplace_order_handover_events(order_id);

create index handover_events_actor_profile_id_idx
  on public.marketplace_order_handover_events(actor_profile_id);

create index handover_events_actor_role_idx
  on public.marketplace_order_handover_events(actor_role);

create index handover_events_event_type_idx
  on public.marketplace_order_handover_events(event_type);

create index handover_events_previous_status_idx
  on public.marketplace_order_handover_events(previous_status);

create index handover_events_new_status_idx
  on public.marketplace_order_handover_events(new_status);

create index handover_events_created_at_idx
  on public.marketplace_order_handover_events(created_at);
