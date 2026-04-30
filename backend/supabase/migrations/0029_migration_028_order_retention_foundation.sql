-- Migration 028 order retention foundation.
-- Scope: backend-only order retention records and event tracking after order archive.
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
      and t.typname = 'marketplace_order_retention_status'
  ) then
    create type public.marketplace_order_retention_status as enum (
      'pending_archive',
      'ready_for_retention',
      'retained',
      'retained_with_note',
      'retention_blocked',
      'retention_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_reason'
  ) then
    create type public.marketplace_order_retention_reason as enum (
      'archive_completed',
      'retention_policy',
      'admin_retained',
      'legal_hold',
      'manual_review',
      'cancelled_order'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_event_type'
  ) then
    create type public.marketplace_order_retention_event_type as enum (
      'retention_created',
      'archive_attached',
      'retention_ready',
      'order_retained',
      'order_retained_with_note',
      'retention_blocked',
      'retention_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_actor_role'
  ) then
    create type public.marketplace_order_retention_actor_role as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_retention_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  archive_record_id bigint,
  closure_record_id bigint,
  retained_by_profile_id bigint,
  status public.marketplace_order_retention_status not null default 'pending_archive',
  retention_reason public.marketplace_order_retention_reason not null default 'archive_completed',
  retention_reference text not null,
  retention_note text,
  blocker_reason text,
  retention_period_days integer,
  ready_at timestamptz,
  retained_at timestamptz,
  blocked_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint order_retention_records_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_retention_records_archive_id_fk
    foreign key (archive_record_id)
    references public.marketplace_order_archive_records(id)
    on delete set null,

  constraint order_retention_records_closure_id_fk
    foreign key (closure_record_id)
    references public.marketplace_order_closure_records(id)
    on delete set null,

  constraint order_retention_records_retained_by_id_fk
    foreign key (retained_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_retention_records_reference_nonblank_chk check (
    btrim(retention_reference) <> ''
  ),
  constraint order_retention_records_note_nonblank_chk check (
    retention_note is null or btrim(retention_note) <> ''
  ),
  constraint order_retention_records_blocker_nonblank_chk check (
    blocker_reason is null or btrim(blocker_reason) <> ''
  ),
  constraint order_retention_records_period_nonnegative_chk check (
    retention_period_days is null or retention_period_days >= 0
  ),
  constraint order_retention_records_blocked_reason_chk check (
    status <> 'retention_blocked' or blocker_reason is not null
  ),
  constraint order_retention_records_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_retention',
      'retained',
      'retained_with_note',
      'retention_blocked',
      'retention_cancelled'
    )
  ),
  constraint order_retention_records_retained_status_chk check (
    retained_at is null or status in ('retained', 'retained_with_note')
  ),
  constraint order_retention_records_blocked_status_chk check (
    blocked_at is null or status = 'retention_blocked'
  ),
  constraint order_retention_records_cancelled_status_chk check (
    cancelled_at is null or status = 'retention_cancelled'
  ),
  constraint order_retention_records_terminal_exclusive_chk check (
    num_nonnulls(retained_at, blocked_at, cancelled_at) <= 1
  ),
  constraint order_retention_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index order_retention_records_reference_key
  on public.marketplace_order_retention_records(retention_reference);

create unique index order_retention_records_one_active_per_order_idx
  on public.marketplace_order_retention_records(order_id)
  where status in (
    'pending_archive',
    'ready_for_retention',
    'retention_blocked'
  );

create index order_retention_records_order_id_idx
  on public.marketplace_order_retention_records(order_id);

create index order_retention_records_archive_id_idx
  on public.marketplace_order_retention_records(archive_record_id);

create index order_retention_records_closure_id_idx
  on public.marketplace_order_retention_records(closure_record_id);

create index order_retention_records_retained_by_id_idx
  on public.marketplace_order_retention_records(retained_by_profile_id);

create index order_retention_records_status_idx
  on public.marketplace_order_retention_records(status);

create index order_retention_records_reason_idx
  on public.marketplace_order_retention_records(retention_reason);

create index order_retention_records_ready_at_idx
  on public.marketplace_order_retention_records(ready_at);

create index order_retention_records_retained_at_idx
  on public.marketplace_order_retention_records(retained_at);

create index order_retention_records_created_at_idx
  on public.marketplace_order_retention_records(created_at);

create table public.marketplace_order_retention_events (
  id bigint generated always as identity primary key,
  retention_record_id bigint not null,
  order_id bigint not null,
  actor_profile_id bigint,
  actor_role public.marketplace_order_retention_actor_role not null default 'system',
  event_type public.marketplace_order_retention_event_type not null,
  previous_status public.marketplace_order_retention_status,
  new_status public.marketplace_order_retention_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint order_retention_events_record_id_fk
    foreign key (retention_record_id)
    references public.marketplace_order_retention_records(id)
    on delete cascade,

  constraint order_retention_events_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_retention_events_actor_profile_id_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_retention_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint order_retention_events_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint order_retention_events_manual_note_required_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint order_retention_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index order_retention_events_record_id_idx
  on public.marketplace_order_retention_events(retention_record_id);

create index order_retention_events_order_id_idx
  on public.marketplace_order_retention_events(order_id);

create index order_retention_events_actor_profile_id_idx
  on public.marketplace_order_retention_events(actor_profile_id);

create index order_retention_events_actor_role_idx
  on public.marketplace_order_retention_events(actor_role);

create index order_retention_events_event_type_idx
  on public.marketplace_order_retention_events(event_type);

create index order_retention_events_previous_status_idx
  on public.marketplace_order_retention_events(previous_status);

create index order_retention_events_new_status_idx
  on public.marketplace_order_retention_events(new_status);

create index order_retention_events_created_at_idx
  on public.marketplace_order_retention_events(created_at);
