-- Migration 030 order retention finalization foundation.
-- Scope: backend-only order retention finalization records and event tracking after retention review.
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
      and t.typname = 'marketplace_order_retention_finalization_status'
  ) then
    create type public.marketplace_order_retention_finalization_status as enum (
      'pending_review',
      'ready_for_finalization',
      'finalized',
      'finalized_with_note',
      'finalization_blocked',
      'finalization_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_finalization_reason'
  ) then
    create type public.marketplace_order_retention_finalization_reason as enum (
      'retention_review_approved',
      'retention_policy_completed',
      'admin_finalized',
      'compliance_completed',
      'legal_hold_resolved',
      'manual_review'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_finalization_event_type'
  ) then
    create type public.marketplace_order_retention_finalization_event_type as enum (
      'finalization_created',
      'retention_attached',
      'review_attached',
      'finalization_ready',
      'retention_finalized',
      'retention_finalized_with_note',
      'finalization_blocked',
      'finalization_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_finalization_actor_role'
  ) then
    create type public.marketplace_order_retention_finalization_actor_role as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_retention_finalization_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  retention_record_id bigint,
  retention_review_record_id bigint,
  finalized_by_profile_id bigint,
  status public.marketplace_order_retention_finalization_status not null default 'pending_review',
  finalization_reason public.marketplace_order_retention_finalization_reason not null default 'retention_review_approved',
  finalization_reference text not null,
  finalization_note text,
  blocker_reason text,
  ready_at timestamptz,
  finalized_at timestamptz,
  blocked_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint order_retention_finalization_records_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_retention_finalization_records_retention_id_fk
    foreign key (retention_record_id)
    references public.marketplace_order_retention_records(id)
    on delete set null,

  constraint order_retention_finalization_records_review_id_fk
    foreign key (retention_review_record_id)
    references public.marketplace_order_retention_review_records(id)
    on delete set null,

  constraint order_retention_finalization_records_finalized_by_id_fk
    foreign key (finalized_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_retention_finalization_records_reference_nonblank_chk check (
    btrim(finalization_reference) <> ''
  ),
  constraint order_retention_finalization_records_note_nonblank_chk check (
    finalization_note is null or btrim(finalization_note) <> ''
  ),
  constraint order_retention_finalization_records_blocker_nonblank_chk check (
    blocker_reason is null or btrim(blocker_reason) <> ''
  ),
  constraint order_retention_finalization_records_blocked_reason_chk check (
    status <> 'finalization_blocked' or blocker_reason is not null
  ),
  constraint order_retention_finalization_records_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_finalization',
      'finalized',
      'finalized_with_note',
      'finalization_blocked',
      'finalization_cancelled'
    )
  ),
  constraint order_retention_finalization_records_finalized_status_chk check (
    finalized_at is null or status in ('finalized', 'finalized_with_note')
  ),
  constraint order_retention_finalization_records_blocked_status_chk check (
    blocked_at is null or status = 'finalization_blocked'
  ),
  constraint order_retention_finalization_records_cancelled_status_chk check (
    cancelled_at is null or status = 'finalization_cancelled'
  ),
  constraint order_retention_finalization_records_terminal_exclusive_chk check (
    num_nonnulls(finalized_at, blocked_at, cancelled_at) <= 1
  ),
  constraint order_retention_finalization_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index order_retention_finalization_records_reference_key
  on public.marketplace_order_retention_finalization_records(finalization_reference);

create unique index order_retention_finalization_records_one_active_per_order_idx
  on public.marketplace_order_retention_finalization_records(order_id)
  where status in (
    'pending_review',
    'ready_for_finalization',
    'finalization_blocked'
  );

create index order_retention_finalization_records_order_id_idx
  on public.marketplace_order_retention_finalization_records(order_id);

create index order_retention_finalization_records_retention_id_idx
  on public.marketplace_order_retention_finalization_records(retention_record_id);

create index order_retention_finalization_records_review_id_idx
  on public.marketplace_order_retention_finalization_records(retention_review_record_id);

create index order_retention_finalization_records_finalized_by_id_idx
  on public.marketplace_order_retention_finalization_records(finalized_by_profile_id);

create index order_retention_finalization_records_status_idx
  on public.marketplace_order_retention_finalization_records(status);

create index order_retention_finalization_records_reason_idx
  on public.marketplace_order_retention_finalization_records(finalization_reason);

create index order_retention_finalization_records_ready_at_idx
  on public.marketplace_order_retention_finalization_records(ready_at);

create index order_retention_finalization_records_finalized_at_idx
  on public.marketplace_order_retention_finalization_records(finalized_at);

create index order_retention_finalization_records_created_at_idx
  on public.marketplace_order_retention_finalization_records(created_at);

create table public.marketplace_order_retention_finalization_events (
  id bigint generated always as identity primary key,
  finalization_record_id bigint not null,
  order_id bigint not null,
  actor_profile_id bigint,
  actor_role public.marketplace_order_retention_finalization_actor_role not null default 'system',
  event_type public.marketplace_order_retention_finalization_event_type not null,
  previous_status public.marketplace_order_retention_finalization_status,
  new_status public.marketplace_order_retention_finalization_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint order_retention_finalization_events_record_id_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_retention_finalization_records(id)
    on delete cascade,

  constraint order_retention_finalization_events_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_retention_finalization_events_actor_profile_id_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_retention_finalization_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint order_retention_finalization_events_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint order_retention_finalization_events_manual_note_required_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint order_retention_finalization_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index order_retention_finalization_events_record_id_idx
  on public.marketplace_order_retention_finalization_events(finalization_record_id);

create index order_retention_finalization_events_order_id_idx
  on public.marketplace_order_retention_finalization_events(order_id);

create index order_retention_finalization_events_actor_profile_id_idx
  on public.marketplace_order_retention_finalization_events(actor_profile_id);

create index order_retention_finalization_events_actor_role_idx
  on public.marketplace_order_retention_finalization_events(actor_role);

create index order_retention_finalization_events_event_type_idx
  on public.marketplace_order_retention_finalization_events(event_type);

create index order_retention_finalization_events_previous_status_idx
  on public.marketplace_order_retention_finalization_events(previous_status);

create index order_retention_finalization_events_new_status_idx
  on public.marketplace_order_retention_finalization_events(new_status);

create index order_retention_finalization_events_created_at_idx
  on public.marketplace_order_retention_finalization_events(created_at);
