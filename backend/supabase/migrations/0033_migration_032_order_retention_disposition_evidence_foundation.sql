-- Migration 032 order retention disposition evidence foundation.
-- Scope: backend-only order retention disposition evidence records and event tracking after retention disposition.
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
      and t.typname = 'marketplace_order_retention_disposition_evidence_status'
  ) then
    create type public.marketplace_order_retention_disposition_evidence_status as enum (
      'pending_disposition',
      'ready_for_evidence',
      'evidence_recorded',
      'evidence_recorded_with_note',
      'evidence_blocked',
      'evidence_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_disposition_evidence_type'
  ) then
    create type public.marketplace_order_retention_disposition_evidence_type as enum (
      'disposition_summary',
      'retention_record',
      'compliance_note',
      'admin_certificate',
      'legal_document',
      'manual_evidence'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_disposition_evidence_event_type'
  ) then
    create type public.marketplace_order_retention_disposition_evidence_event_type as enum (
      'evidence_created',
      'disposition_attached',
      'retention_attached',
      'evidence_ready',
      'evidence_recorded',
      'evidence_recorded_with_note',
      'evidence_blocked',
      'evidence_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_disposition_evidence_actor_role'
  ) then
    create type public.marketplace_order_retention_disposition_evidence_actor_role as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_retention_disposition_evidence_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  disposition_record_id bigint,
  retention_record_id bigint,
  recorded_by_profile_id bigint,
  status public.marketplace_order_retention_disposition_evidence_status not null default 'pending_disposition',
  evidence_type public.marketplace_order_retention_disposition_evidence_type not null default 'disposition_summary',
  evidence_reference text not null,
  evidence_uri text,
  evidence_hash text,
  evidence_note text,
  blocker_reason text,
  ready_at timestamptz,
  recorded_at timestamptz,
  blocked_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint order_retention_disposition_evidence_records_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_retention_disposition_evidence_records_disposition_id_fk
    foreign key (disposition_record_id)
    references public.marketplace_order_retention_disposition_records(id)
    on delete set null,

  constraint order_retention_disposition_evidence_records_retention_id_fk
    foreign key (retention_record_id)
    references public.marketplace_order_retention_records(id)
    on delete set null,

  constraint order_retention_disposition_evidence_records_recorded_by_id_fk
    foreign key (recorded_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_retention_disposition_evidence_records_reference_nonblank_chk check (
    btrim(evidence_reference) <> ''
  ),
  constraint order_retention_disposition_evidence_records_uri_nonblank_chk check (
    evidence_uri is null or btrim(evidence_uri) <> ''
  ),
  constraint order_retention_disposition_evidence_records_hash_nonblank_chk check (
    evidence_hash is null or btrim(evidence_hash) <> ''
  ),
  constraint order_retention_disposition_evidence_records_note_nonblank_chk check (
    evidence_note is null or btrim(evidence_note) <> ''
  ),
  constraint order_retention_disposition_evidence_records_blocker_nonblank_chk check (
    blocker_reason is null or btrim(blocker_reason) <> ''
  ),
  constraint order_retention_disposition_evidence_records_blocked_reason_chk check (
    status <> 'evidence_blocked' or blocker_reason is not null
  ),
  constraint order_retention_disposition_evidence_records_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_evidence',
      'evidence_recorded',
      'evidence_recorded_with_note',
      'evidence_blocked',
      'evidence_cancelled'
    )
  ),
  constraint order_retention_disposition_evidence_records_recorded_status_chk check (
    recorded_at is null or status in ('evidence_recorded', 'evidence_recorded_with_note')
  ),
  constraint order_retention_disposition_evidence_records_blocked_status_chk check (
    blocked_at is null or status = 'evidence_blocked'
  ),
  constraint order_retention_disposition_evidence_records_cancelled_status_chk check (
    cancelled_at is null or status = 'evidence_cancelled'
  ),
  constraint order_retention_disposition_evidence_records_terminal_exclusive_chk check (
    num_nonnulls(recorded_at, blocked_at, cancelled_at) <= 1
  ),
  constraint order_retention_disposition_evidence_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index order_retention_disposition_evidence_records_reference_key
  on public.marketplace_order_retention_disposition_evidence_records(evidence_reference);

create unique index order_retention_disposition_evidence_records_one_active_per_order_idx
  on public.marketplace_order_retention_disposition_evidence_records(order_id)
  where status in (
    'pending_disposition',
    'ready_for_evidence',
    'evidence_blocked'
  );

create index order_retention_disposition_evidence_records_order_id_idx
  on public.marketplace_order_retention_disposition_evidence_records(order_id);

create index order_retention_disposition_evidence_records_disposition_id_idx
  on public.marketplace_order_retention_disposition_evidence_records(disposition_record_id);

create index order_retention_disposition_evidence_records_retention_id_idx
  on public.marketplace_order_retention_disposition_evidence_records(retention_record_id);

create index order_retention_disposition_evidence_records_recorded_by_id_idx
  on public.marketplace_order_retention_disposition_evidence_records(recorded_by_profile_id);

create index order_retention_disposition_evidence_records_status_idx
  on public.marketplace_order_retention_disposition_evidence_records(status);

create index order_retention_disposition_evidence_records_type_idx
  on public.marketplace_order_retention_disposition_evidence_records(evidence_type);

create index order_retention_disposition_evidence_records_ready_at_idx
  on public.marketplace_order_retention_disposition_evidence_records(ready_at);

create index order_retention_disposition_evidence_records_recorded_at_idx
  on public.marketplace_order_retention_disposition_evidence_records(recorded_at);

create index order_retention_disposition_evidence_records_created_at_idx
  on public.marketplace_order_retention_disposition_evidence_records(created_at);

create table public.marketplace_order_retention_disposition_evidence_events (
  id bigint generated always as identity primary key,
  evidence_record_id bigint not null,
  order_id bigint not null,
  actor_profile_id bigint,
  actor_role public.marketplace_order_retention_disposition_evidence_actor_role not null default 'system',
  event_type public.marketplace_order_retention_disposition_evidence_event_type not null,
  previous_status public.marketplace_order_retention_disposition_evidence_status,
  new_status public.marketplace_order_retention_disposition_evidence_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint order_retention_disposition_evidence_events_record_id_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete cascade,

  constraint order_retention_disposition_evidence_events_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_retention_disposition_evidence_events_actor_profile_id_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_retention_disposition_evidence_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint order_retention_disposition_evidence_events_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint order_retention_disposition_evidence_events_manual_note_required_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint order_retention_disposition_evidence_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index order_retention_disposition_evidence_events_record_id_idx
  on public.marketplace_order_retention_disposition_evidence_events(evidence_record_id);

create index order_retention_disposition_evidence_events_order_id_idx
  on public.marketplace_order_retention_disposition_evidence_events(order_id);

create index order_retention_disposition_evidence_events_actor_profile_id_idx
  on public.marketplace_order_retention_disposition_evidence_events(actor_profile_id);

create index order_retention_disposition_evidence_events_actor_role_idx
  on public.marketplace_order_retention_disposition_evidence_events(actor_role);

create index order_retention_disposition_evidence_events_event_type_idx
  on public.marketplace_order_retention_disposition_evidence_events(event_type);

create index order_retention_disposition_evidence_events_previous_status_idx
  on public.marketplace_order_retention_disposition_evidence_events(previous_status);

create index order_retention_disposition_evidence_events_new_status_idx
  on public.marketplace_order_retention_disposition_evidence_events(new_status);

create index order_retention_disposition_evidence_events_created_at_idx
  on public.marketplace_order_retention_disposition_evidence_events(created_at);
