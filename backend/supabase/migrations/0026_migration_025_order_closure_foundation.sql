-- Migration 025 order closure foundation.
-- Scope: backend-only order closure records and event tracking after completion evidence.
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
      and t.typname = 'marketplace_order_closure_status'
  ) then
    create type public.marketplace_order_closure_status as enum (
      'pending_completion_acceptance',
      'ready_to_close',
      'closed',
      'closed_with_note',
      'closure_blocked',
      'closure_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_closure_reason'
  ) then
    create type public.marketplace_order_closure_reason as enum (
      'completion_accepted',
      'buyer_confirmed',
      'seller_confirmed',
      'admin_closed',
      'manual_review',
      'cancelled_order'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_closure_event_type'
  ) then
    create type public.marketplace_order_closure_event_type as enum (
      'closure_created',
      'acceptance_attached',
      'evidence_attached',
      'closure_ready',
      'order_closed',
      'order_closed_with_note',
      'closure_blocked',
      'closure_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_closure_actor_role'
  ) then
    create type public.marketplace_order_closure_actor_role as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_closure_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  acceptance_record_id bigint,
  evidence_record_id bigint,
  closed_by_profile_id bigint,
  status public.marketplace_order_closure_status not null default 'pending_completion_acceptance',
  closure_reason public.marketplace_order_closure_reason not null default 'completion_accepted',
  closure_reference text not null,
  closure_note text,
  blocker_reason text,
  ready_at timestamptz,
  closed_at timestamptz,
  blocked_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint order_closure_records_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_closure_records_acceptance_id_fk
    foreign key (acceptance_record_id)
    references public.marketplace_order_completion_acceptance_records(id)
    on delete set null,

  constraint order_closure_records_evidence_id_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_completion_evidence_records(id)
    on delete set null,

  constraint order_closure_records_closed_by_id_fk
    foreign key (closed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_closure_records_reference_nonblank_chk check (
    btrim(closure_reference) <> ''
  ),
  constraint order_closure_records_note_nonblank_chk check (
    closure_note is null or btrim(closure_note) <> ''
  ),
  constraint order_closure_records_blocker_nonblank_chk check (
    blocker_reason is null or btrim(blocker_reason) <> ''
  ),
  constraint order_closure_records_blocked_reason_chk check (
    status <> 'closure_blocked' or blocker_reason is not null
  ),
  constraint order_closure_records_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_to_close',
      'closed',
      'closed_with_note',
      'closure_blocked',
      'closure_cancelled'
    )
  ),
  constraint order_closure_records_closed_status_chk check (
    closed_at is null or status in ('closed', 'closed_with_note')
  ),
  constraint order_closure_records_blocked_status_chk check (
    blocked_at is null or status = 'closure_blocked'
  ),
  constraint order_closure_records_cancelled_status_chk check (
    cancelled_at is null or status = 'closure_cancelled'
  ),
  constraint order_closure_records_terminal_exclusive_chk check (
    num_nonnulls(closed_at, blocked_at, cancelled_at) <= 1
  ),
  constraint order_closure_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index order_closure_records_reference_key
  on public.marketplace_order_closure_records(closure_reference);

create unique index order_closure_records_one_active_per_order_idx
  on public.marketplace_order_closure_records(order_id)
  where status in (
    'pending_completion_acceptance',
    'ready_to_close',
    'closure_blocked'
  );

create index order_closure_records_order_id_idx
  on public.marketplace_order_closure_records(order_id);

create index order_closure_records_acceptance_id_idx
  on public.marketplace_order_closure_records(acceptance_record_id);

create index order_closure_records_evidence_id_idx
  on public.marketplace_order_closure_records(evidence_record_id);

create index order_closure_records_closed_by_id_idx
  on public.marketplace_order_closure_records(closed_by_profile_id);

create index order_closure_records_status_idx
  on public.marketplace_order_closure_records(status);

create index order_closure_records_reason_idx
  on public.marketplace_order_closure_records(closure_reason);

create index order_closure_records_ready_at_idx
  on public.marketplace_order_closure_records(ready_at);

create index order_closure_records_closed_at_idx
  on public.marketplace_order_closure_records(closed_at);

create index order_closure_records_created_at_idx
  on public.marketplace_order_closure_records(created_at);

create table public.marketplace_order_closure_events (
  id bigint generated always as identity primary key,
  closure_record_id bigint not null,
  order_id bigint not null,
  actor_profile_id bigint,
  actor_role public.marketplace_order_closure_actor_role not null default 'system',
  event_type public.marketplace_order_closure_event_type not null,
  previous_status public.marketplace_order_closure_status,
  new_status public.marketplace_order_closure_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint order_closure_events_record_id_fk
    foreign key (closure_record_id)
    references public.marketplace_order_closure_records(id)
    on delete cascade,

  constraint order_closure_events_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_closure_events_actor_profile_id_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_closure_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint order_closure_events_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint order_closure_events_manual_note_required_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint order_closure_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index order_closure_events_record_id_idx
  on public.marketplace_order_closure_events(closure_record_id);

create index order_closure_events_order_id_idx
  on public.marketplace_order_closure_events(order_id);

create index order_closure_events_actor_profile_id_idx
  on public.marketplace_order_closure_events(actor_profile_id);

create index order_closure_events_actor_role_idx
  on public.marketplace_order_closure_events(actor_role);

create index order_closure_events_event_type_idx
  on public.marketplace_order_closure_events(event_type);

create index order_closure_events_previous_status_idx
  on public.marketplace_order_closure_events(previous_status);

create index order_closure_events_new_status_idx
  on public.marketplace_order_closure_events(new_status);

create index order_closure_events_created_at_idx
  on public.marketplace_order_closure_events(created_at);
