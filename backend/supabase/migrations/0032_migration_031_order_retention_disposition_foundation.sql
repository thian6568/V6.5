-- Migration 031 order retention disposition foundation.
-- Scope: backend-only order retention disposition records and event tracking after retention finalization.
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
      and t.typname = 'marketplace_order_retention_disposition_status'
  ) then
    create type public.marketplace_order_retention_disposition_status as enum (
      'pending_finalization',
      'ready_for_disposition',
      'disposed',
      'disposed_with_note',
      'disposition_blocked',
      'disposition_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_disposition_reason'
  ) then
    create type public.marketplace_order_retention_disposition_reason as enum (
      'retention_finalized',
      'retention_policy_completed',
      'admin_disposed',
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
      and t.typname = 'marketplace_order_retention_disposition_event_type'
  ) then
    create type public.marketplace_order_retention_disposition_event_type as enum (
      'disposition_created',
      'retention_attached',
      'finalization_attached',
      'disposition_ready',
      'order_disposed',
      'order_disposed_with_note',
      'disposition_blocked',
      'disposition_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_disposition_actor_role'
  ) then
    create type public.marketplace_order_retention_disposition_actor_role as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_retention_disposition_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  retention_record_id bigint,
  retention_finalization_record_id bigint,
  disposed_by_profile_id bigint,
  status public.marketplace_order_retention_disposition_status not null default 'pending_finalization',
  disposition_reason public.marketplace_order_retention_disposition_reason not null default 'retention_finalized',
  disposition_reference text not null,
  disposition_note text,
  blocker_reason text,
  ready_at timestamptz,
  disposed_at timestamptz,
  blocked_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint order_retention_disposition_records_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_retention_disposition_records_retention_id_fk
    foreign key (retention_record_id)
    references public.marketplace_order_retention_records(id)
    on delete set null,

  constraint order_retention_disposition_records_finalization_id_fk
    foreign key (retention_finalization_record_id)
    references public.marketplace_order_retention_finalization_records(id)
    on delete set null,

  constraint order_retention_disposition_records_disposed_by_id_fk
    foreign key (disposed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_retention_disposition_records_reference_nonblank_chk check (
    btrim(disposition_reference) <> ''
  ),
  constraint order_retention_disposition_records_note_nonblank_chk check (
    disposition_note is null or btrim(disposition_note) <> ''
  ),
  constraint order_retention_disposition_records_blocker_nonblank_chk check (
    blocker_reason is null or btrim(blocker_reason) <> ''
  ),
  constraint order_retention_disposition_records_blocked_reason_chk check (
    status <> 'disposition_blocked' or blocker_reason is not null
  ),
  constraint order_retention_disposition_records_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_disposition',
      'disposed',
      'disposed_with_note',
      'disposition_blocked',
      'disposition_cancelled'
    )
  ),
  constraint order_retention_disposition_records_disposed_status_chk check (
    disposed_at is null or status in ('disposed', 'disposed_with_note')
  ),
  constraint order_retention_disposition_records_blocked_status_chk check (
    blocked_at is null or status = 'disposition_blocked'
  ),
  constraint order_retention_disposition_records_cancelled_status_chk check (
    cancelled_at is null or status = 'disposition_cancelled'
  ),
  constraint order_retention_disposition_records_terminal_exclusive_chk check (
    num_nonnulls(disposed_at, blocked_at, cancelled_at) <= 1
  ),
  constraint order_retention_disposition_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index order_retention_disposition_records_reference_key
  on public.marketplace_order_retention_disposition_records(disposition_reference);

create unique index order_retention_disposition_records_one_active_per_order_idx
  on public.marketplace_order_retention_disposition_records(order_id)
  where status in (
    'pending_finalization',
    'ready_for_disposition',
    'disposition_blocked'
  );

create index order_retention_disposition_records_order_id_idx
  on public.marketplace_order_retention_disposition_records(order_id);

create index order_retention_disposition_records_retention_id_idx
  on public.marketplace_order_retention_disposition_records(retention_record_id);

create index order_retention_disposition_records_finalization_id_idx
  on public.marketplace_order_retention_disposition_records(retention_finalization_record_id);

create index order_retention_disposition_records_disposed_by_id_idx
  on public.marketplace_order_retention_disposition_records(disposed_by_profile_id);

create index order_retention_disposition_records_status_idx
  on public.marketplace_order_retention_disposition_records(status);

create index order_retention_disposition_records_reason_idx
  on public.marketplace_order_retention_disposition_records(disposition_reason);

create index order_retention_disposition_records_ready_at_idx
  on public.marketplace_order_retention_disposition_records(ready_at);

create index order_retention_disposition_records_disposed_at_idx
  on public.marketplace_order_retention_disposition_records(disposed_at);

create index order_retention_disposition_records_created_at_idx
  on public.marketplace_order_retention_disposition_records(created_at);

create table public.marketplace_order_retention_disposition_events (
  id bigint generated always as identity primary key,
  disposition_record_id bigint not null,
  order_id bigint not null,
  actor_profile_id bigint,
  actor_role public.marketplace_order_retention_disposition_actor_role not null default 'system',
  event_type public.marketplace_order_retention_disposition_event_type not null,
  previous_status public.marketplace_order_retention_disposition_status,
  new_status public.marketplace_order_retention_disposition_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint order_retention_disposition_events_record_id_fk
    foreign key (disposition_record_id)
    references public.marketplace_order_retention_disposition_records(id)
    on delete cascade,

  constraint order_retention_disposition_events_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_retention_disposition_events_actor_profile_id_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_retention_disposition_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint order_retention_disposition_events_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint order_retention_disposition_events_manual_note_required_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint order_retention_disposition_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index order_retention_disposition_events_record_id_idx
  on public.marketplace_order_retention_disposition_events(disposition_record_id);

create index order_retention_disposition_events_order_id_idx
  on public.marketplace_order_retention_disposition_events(order_id);

create index order_retention_disposition_events_actor_profile_id_idx
  on public.marketplace_order_retention_disposition_events(actor_profile_id);

create index order_retention_disposition_events_actor_role_idx
  on public.marketplace_order_retention_disposition_events(actor_role);

create index order_retention_disposition_events_event_type_idx
  on public.marketplace_order_retention_disposition_events(event_type);

create index order_retention_disposition_events_previous_status_idx
  on public.marketplace_order_retention_disposition_events(previous_status);

create index order_retention_disposition_events_new_status_idx
  on public.marketplace_order_retention_disposition_events(new_status);

create index order_retention_disposition_events_created_at_idx
  on public.marketplace_order_retention_disposition_events(created_at);
