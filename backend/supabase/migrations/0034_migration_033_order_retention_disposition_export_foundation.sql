-- Migration 033 order retention disposition export foundation.
-- Scope: backend-only order retention disposition export records and export event tracking after disposition evidence.
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
      and t.typname = 'marketplace_order_retention_disposition_export_status'
  ) then
    create type public.marketplace_order_retention_disposition_export_status as enum (
      'pending_evidence',
      'ready_for_export',
      'export_requested',
      'export_generated',
      'export_verified',
      'export_blocked',
      'export_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_disposition_export_format'
  ) then
    create type public.marketplace_order_retention_disposition_export_format as enum (
      'json',
      'csv',
      'pdf',
      'zip',
      'manual_package'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_disposition_export_event_type'
  ) then
    create type public.marketplace_order_retention_disposition_export_event_type as enum (
      'export_created',
      'evidence_attached',
      'export_ready',
      'export_requested',
      'export_generated',
      'export_verified',
      'export_blocked',
      'export_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_retention_disposition_export_actor_role'
  ) then
    create type public.marketplace_order_retention_disposition_export_actor_role as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_retention_disposition_export_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  disposition_record_id bigint,
  evidence_record_id bigint,
  requested_by_profile_id bigint,
  generated_by_profile_id bigint,
  verified_by_profile_id bigint,
  status public.marketplace_order_retention_disposition_export_status not null default 'pending_evidence',
  export_format public.marketplace_order_retention_disposition_export_format not null default 'json',
  export_reference text not null,
  export_uri text,
  export_hash text,
  export_note text,
  blocker_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  generated_at timestamptz,
  verified_at timestamptz,
  blocked_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint order_ret_disp_export_records_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_ret_disp_export_records_disposition_fk
    foreign key (disposition_record_id)
    references public.marketplace_order_retention_disposition_records(id)
    on delete set null,

  constraint order_ret_disp_export_records_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint order_ret_disp_export_records_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_ret_disp_export_records_generated_by_fk
    foreign key (generated_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_ret_disp_export_records_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_ret_disp_export_records_reference_chk check (
    btrim(export_reference) <> ''
  ),
  constraint order_ret_disp_export_records_uri_chk check (
    export_uri is null or btrim(export_uri) <> ''
  ),
  constraint order_ret_disp_export_records_hash_chk check (
    export_hash is null or btrim(export_hash) <> ''
  ),
  constraint order_ret_disp_export_records_note_chk check (
    export_note is null or btrim(export_note) <> ''
  ),
  constraint order_ret_disp_export_records_blocker_chk check (
    blocker_reason is null or btrim(blocker_reason) <> ''
  ),
  constraint order_ret_disp_export_records_blocked_reason_chk check (
    status <> 'export_blocked' or blocker_reason is not null
  ),
  constraint order_ret_disp_export_records_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_export',
      'export_requested',
      'export_generated',
      'export_verified',
      'export_blocked',
      'export_cancelled'
    )
  ),
  constraint order_ret_disp_export_records_requested_status_chk check (
    requested_at is null
    or status in (
      'export_requested',
      'export_generated',
      'export_verified',
      'export_blocked',
      'export_cancelled'
    )
  ),
  constraint order_ret_disp_export_records_generated_status_chk check (
    generated_at is null
    or status in (
      'export_generated',
      'export_verified'
    )
  ),
  constraint order_ret_disp_export_records_verified_status_chk check (
    verified_at is null or status = 'export_verified'
  ),
  constraint order_ret_disp_export_records_blocked_status_chk check (
    blocked_at is null or status = 'export_blocked'
  ),
  constraint order_ret_disp_export_records_cancelled_status_chk check (
    cancelled_at is null or status = 'export_cancelled'
  ),
  constraint order_ret_disp_export_records_terminal_exclusive_chk check (
    num_nonnulls(verified_at, blocked_at, cancelled_at) <= 1
  ),
  constraint order_ret_disp_export_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index order_ret_disp_export_records_reference_key
  on public.marketplace_order_retention_disposition_export_records(export_reference);

create unique index order_ret_disp_export_records_one_active_per_order_idx
  on public.marketplace_order_retention_disposition_export_records(order_id)
  where status in (
    'pending_evidence',
    'ready_for_export',
    'export_requested',
    'export_blocked'
  );

create index order_ret_disp_export_records_order_id_idx
  on public.marketplace_order_retention_disposition_export_records(order_id);

create index order_ret_disp_export_records_disposition_id_idx
  on public.marketplace_order_retention_disposition_export_records(disposition_record_id);

create index order_ret_disp_export_records_evidence_id_idx
  on public.marketplace_order_retention_disposition_export_records(evidence_record_id);

create index order_ret_disp_export_records_requested_by_idx
  on public.marketplace_order_retention_disposition_export_records(requested_by_profile_id);

create index order_ret_disp_export_records_generated_by_idx
  on public.marketplace_order_retention_disposition_export_records(generated_by_profile_id);

create index order_ret_disp_export_records_verified_by_idx
  on public.marketplace_order_retention_disposition_export_records(verified_by_profile_id);

create index order_ret_disp_export_records_status_idx
  on public.marketplace_order_retention_disposition_export_records(status);

create index order_ret_disp_export_records_format_idx
  on public.marketplace_order_retention_disposition_export_records(export_format);

create index order_ret_disp_export_records_ready_at_idx
  on public.marketplace_order_retention_disposition_export_records(ready_at);

create index order_ret_disp_export_records_requested_at_idx
  on public.marketplace_order_retention_disposition_export_records(requested_at);

create index order_ret_disp_export_records_generated_at_idx
  on public.marketplace_order_retention_disposition_export_records(generated_at);

create index order_ret_disp_export_records_verified_at_idx
  on public.marketplace_order_retention_disposition_export_records(verified_at);

create index order_ret_disp_export_records_created_at_idx
  on public.marketplace_order_retention_disposition_export_records(created_at);

create table public.marketplace_order_retention_disposition_export_events (
  id bigint generated always as identity primary key,
  export_record_id bigint not null,
  order_id bigint not null,
  actor_profile_id bigint,
  actor_role public.marketplace_order_retention_disposition_export_actor_role not null default 'system',
  event_type public.marketplace_order_retention_disposition_export_event_type not null,
  previous_status public.marketplace_order_retention_disposition_export_status,
  new_status public.marketplace_order_retention_disposition_export_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint order_ret_disp_export_events_record_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete cascade,

  constraint order_ret_disp_export_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_ret_disp_export_events_actor_profile_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_ret_disp_export_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint order_ret_disp_export_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint order_ret_disp_export_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint order_ret_disp_export_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index order_ret_disp_export_events_record_id_idx
  on public.marketplace_order_retention_disposition_export_events(export_record_id);

create index order_ret_disp_export_events_order_id_idx
  on public.marketplace_order_retention_disposition_export_events(order_id);

create index order_ret_disp_export_events_actor_profile_id_idx
  on public.marketplace_order_retention_disposition_export_events(actor_profile_id);

create index order_ret_disp_export_events_actor_role_idx
  on public.marketplace_order_retention_disposition_export_events(actor_role);

create index order_ret_disp_export_events_event_type_idx
  on public.marketplace_order_retention_disposition_export_events(event_type);

create index order_ret_disp_export_events_previous_status_idx
  on public.marketplace_order_retention_disposition_export_events(previous_status);

create index order_ret_disp_export_events_new_status_idx
  on public.marketplace_order_retention_disposition_export_events(new_status);

create index order_ret_disp_export_events_created_at_idx
  on public.marketplace_order_retention_disposition_export_events(created_at);
