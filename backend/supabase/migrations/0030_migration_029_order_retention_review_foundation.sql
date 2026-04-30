-- Migration 029 order retention review foundation.
-- Scope: backend-only order retention review records and event tracking after order retention.
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
      and t.typname = 'marketplace_order_retention_review_status'
  ) then
    create type public.marketplace_order_retention_review_status as enum (
      'pending_retention',
      'ready_for_review',
      'in_review',
      'approved',
      'approved_with_note',
      'review_blocked',
      'review_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_review_type'
  ) then
    create type public.marketplace_order_retention_review_type as enum (
      'retention_policy_review',
      'legal_hold_review',
      'admin_review',
      'support_review',
      'compliance_review',
      'manual_review'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_review_event_type'
  ) then
    create type public.marketplace_order_retention_review_event_type as enum (
      'review_created',
      'retention_attached',
      'archive_attached',
      'review_ready',
      'review_started',
      'review_approved',
      'review_approved_with_note',
      'review_blocked',
      'review_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_review_actor_role'
  ) then
    create type public.marketplace_order_retention_review_actor_role as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_retention_review_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  retention_record_id bigint,
  archive_record_id bigint,
  reviewed_by_profile_id bigint,
  status public.marketplace_order_retention_review_status not null default 'pending_retention',
  review_type public.marketplace_order_retention_review_type not null default 'retention_policy_review',
  review_reference text not null,
  review_note text,
  blocker_reason text,
  review_due_at timestamptz,
  ready_at timestamptz,
  review_started_at timestamptz,
  approved_at timestamptz,
  blocked_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint order_retention_review_records_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_retention_review_records_retention_id_fk
    foreign key (retention_record_id)
    references public.marketplace_order_retention_records(id)
    on delete set null,

  constraint order_retention_review_records_archive_id_fk
    foreign key (archive_record_id)
    references public.marketplace_order_archive_records(id)
    on delete set null,

  constraint order_retention_review_records_reviewed_by_id_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_retention_review_records_reference_nonblank_chk check (
    btrim(review_reference) <> ''
  ),
  constraint order_retention_review_records_note_nonblank_chk check (
    review_note is null or btrim(review_note) <> ''
  ),
  constraint order_retention_review_records_blocker_nonblank_chk check (
    blocker_reason is null or btrim(blocker_reason) <> ''
  ),
  constraint order_retention_review_records_blocked_reason_chk check (
    status <> 'review_blocked' or blocker_reason is not null
  ),
  constraint order_retention_review_records_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_review',
      'in_review',
      'approved',
      'approved_with_note',
      'review_blocked',
      'review_cancelled'
    )
  ),
  constraint order_retention_review_records_started_status_chk check (
    review_started_at is null
    or status in (
      'in_review',
      'approved',
      'approved_with_note',
      'review_blocked',
      'review_cancelled'
    )
  ),
  constraint order_retention_review_records_approved_status_chk check (
    approved_at is null or status in ('approved', 'approved_with_note')
  ),
  constraint order_retention_review_records_blocked_status_chk check (
    blocked_at is null or status = 'review_blocked'
  ),
  constraint order_retention_review_records_cancelled_status_chk check (
    cancelled_at is null or status = 'review_cancelled'
  ),
  constraint order_retention_review_records_terminal_exclusive_chk check (
    num_nonnulls(approved_at, blocked_at, cancelled_at) <= 1
  ),
  constraint order_retention_review_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index order_retention_review_records_reference_key
  on public.marketplace_order_retention_review_records(review_reference);

create unique index order_retention_review_records_one_active_per_order_idx
  on public.marketplace_order_retention_review_records(order_id)
  where status in (
    'pending_retention',
    'ready_for_review',
    'in_review',
    'review_blocked'
  );

create index order_retention_review_records_order_id_idx
  on public.marketplace_order_retention_review_records(order_id);

create index order_retention_review_records_retention_id_idx
  on public.marketplace_order_retention_review_records(retention_record_id);

create index order_retention_review_records_archive_id_idx
  on public.marketplace_order_retention_review_records(archive_record_id);

create index order_retention_review_records_reviewed_by_id_idx
  on public.marketplace_order_retention_review_records(reviewed_by_profile_id);

create index order_retention_review_records_status_idx
  on public.marketplace_order_retention_review_records(status);

create index order_retention_review_records_type_idx
  on public.marketplace_order_retention_review_records(review_type);

create index order_retention_review_records_due_at_idx
  on public.marketplace_order_retention_review_records(review_due_at);

create index order_retention_review_records_ready_at_idx
  on public.marketplace_order_retention_review_records(ready_at);

create index order_retention_review_records_started_at_idx
  on public.marketplace_order_retention_review_records(review_started_at);

create index order_retention_review_records_approved_at_idx
  on public.marketplace_order_retention_review_records(approved_at);

create index order_retention_review_records_created_at_idx
  on public.marketplace_order_retention_review_records(created_at);

create table public.marketplace_order_retention_review_events (
  id bigint generated always as identity primary key,
  review_record_id bigint not null,
  order_id bigint not null,
  actor_profile_id bigint,
  actor_role public.marketplace_order_retention_review_actor_role not null default 'system',
  event_type public.marketplace_order_retention_review_event_type not null,
  previous_status public.marketplace_order_retention_review_status,
  new_status public.marketplace_order_retention_review_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint order_retention_review_events_record_id_fk
    foreign key (review_record_id)
    references public.marketplace_order_retention_review_records(id)
    on delete cascade,

  constraint order_retention_review_events_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_retention_review_events_actor_profile_id_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_retention_review_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint order_retention_review_events_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint order_retention_review_events_manual_note_required_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint order_retention_review_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index order_retention_review_events_record_id_idx
  on public.marketplace_order_retention_review_events(review_record_id);

create index order_retention_review_events_order_id_idx
  on public.marketplace_order_retention_review_events(order_id);

create index order_retention_review_events_actor_profile_id_idx
  on public.marketplace_order_retention_review_events(actor_profile_id);

create index order_retention_review_events_actor_role_idx
  on public.marketplace_order_retention_review_events(actor_role);

create index order_retention_review_events_event_type_idx
  on public.marketplace_order_retention_review_events(event_type);

create index order_retention_review_events_previous_status_idx
  on public.marketplace_order_retention_review_events(previous_status);

create index order_retention_review_events_new_status_idx
  on public.marketplace_order_retention_review_events(new_status);

create index order_retention_review_events_created_at_idx
  on public.marketplace_order_retention_review_events(created_at);
