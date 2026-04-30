-- Migration 027 order archive foundation.
-- Scope: backend-only order archive records and event tracking after post-closure audit.
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
      and t.typname = 'marketplace_order_archive_status'
  ) then
    create type public.marketplace_order_archive_status as enum (
      'pending_closure',
      'ready_to_archive',
      'archived',
      'archived_with_note',
      'archive_blocked',
      'archive_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_archive_reason'
  ) then
    create type public.marketplace_order_archive_reason as enum (
      'order_closed',
      'post_closure_audit_resolved',
      'admin_archived',
      'retention_policy',
      'manual_review',
      'cancelled_order'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_archive_event_type'
  ) then
    create type public.marketplace_order_archive_event_type as enum (
      'archive_created',
      'closure_attached',
      'audit_attached',
      'archive_ready',
      'order_archived',
      'order_archived_with_note',
      'archive_blocked',
      'archive_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_archive_actor_role'
  ) then
    create type public.marketplace_order_archive_actor_role as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_archive_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  closure_record_id bigint,
  post_closure_audit_record_id bigint,
  archived_by_profile_id bigint,
  status public.marketplace_order_archive_status not null default 'pending_closure',
  archive_reason public.marketplace_order_archive_reason not null default 'order_closed',
  archive_reference text not null,
  archive_note text,
  blocker_reason text,
  ready_at timestamptz,
  archived_at timestamptz,
  blocked_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint order_archive_records_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_archive_records_closure_id_fk
    foreign key (closure_record_id)
    references public.marketplace_order_closure_records(id)
    on delete set null,

  constraint order_archive_records_post_closure_audit_id_fk
    foreign key (post_closure_audit_record_id)
    references public.marketplace_order_post_closure_audit_records(id)
    on delete set null,

  constraint order_archive_records_archived_by_id_fk
    foreign key (archived_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_archive_records_reference_nonblank_chk check (
    btrim(archive_reference) <> ''
  ),
  constraint order_archive_records_note_nonblank_chk check (
    archive_note is null or btrim(archive_note) <> ''
  ),
  constraint order_archive_records_blocker_nonblank_chk check (
    blocker_reason is null or btrim(blocker_reason) <> ''
  ),
  constraint order_archive_records_blocked_reason_chk check (
    status <> 'archive_blocked' or blocker_reason is not null
  ),
  constraint order_archive_records_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_to_archive',
      'archived',
      'archived_with_note',
      'archive_blocked',
      'archive_cancelled'
    )
  ),
  constraint order_archive_records_archived_status_chk check (
    archived_at is null or status in ('archived', 'archived_with_note')
  ),
  constraint order_archive_records_blocked_status_chk check (
    blocked_at is null or status = 'archive_blocked'
  ),
  constraint order_archive_records_cancelled_status_chk check (
    cancelled_at is null or status = 'archive_cancelled'
  ),
  constraint order_archive_records_terminal_exclusive_chk check (
    num_nonnulls(archived_at, blocked_at, cancelled_at) <= 1
  ),
  constraint order_archive_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index order_archive_records_reference_key
  on public.marketplace_order_archive_records(archive_reference);

create unique index order_archive_records_one_active_per_order_idx
  on public.marketplace_order_archive_records(order_id)
  where status in (
    'pending_closure',
    'ready_to_archive',
    'archive_blocked'
  );

create index order_archive_records_order_id_idx
  on public.marketplace_order_archive_records(order_id);

create index order_archive_records_closure_id_idx
  on public.marketplace_order_archive_records(closure_record_id);

create index order_archive_records_post_closure_audit_id_idx
  on public.marketplace_order_archive_records(post_closure_audit_record_id);

create index order_archive_records_archived_by_id_idx
  on public.marketplace_order_archive_records(archived_by_profile_id);

create index order_archive_records_status_idx
  on public.marketplace_order_archive_records(status);

create index order_archive_records_reason_idx
  on public.marketplace_order_archive_records(archive_reason);

create index order_archive_records_ready_at_idx
  on public.marketplace_order_archive_records(ready_at);

create index order_archive_records_archived_at_idx
  on public.marketplace_order_archive_records(archived_at);

create index order_archive_records_created_at_idx
  on public.marketplace_order_archive_records(created_at);

create table public.marketplace_order_archive_events (
  id bigint generated always as identity primary key,
  archive_record_id bigint not null,
  order_id bigint not null,
  actor_profile_id bigint,
  actor_role public.marketplace_order_archive_actor_role not null default 'system',
  event_type public.marketplace_order_archive_event_type not null,
  previous_status public.marketplace_order_archive_status,
  new_status public.marketplace_order_archive_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint order_archive_events_record_id_fk
    foreign key (archive_record_id)
    references public.marketplace_order_archive_records(id)
    on delete cascade,

  constraint order_archive_events_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_archive_events_actor_profile_id_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_archive_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint order_archive_events_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint order_archive_events_manual_note_required_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint order_archive_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index order_archive_events_record_id_idx
  on public.marketplace_order_archive_events(archive_record_id);

create index order_archive_events_order_id_idx
  on public.marketplace_order_archive_events(order_id);

create index order_archive_events_actor_profile_id_idx
  on public.marketplace_order_archive_events(actor_profile_id);

create index order_archive_events_actor_role_idx
  on public.marketplace_order_archive_events(actor_role);

create index order_archive_events_event_type_idx
  on public.marketplace_order_archive_events(event_type);

create index order_archive_events_previous_status_idx
  on public.marketplace_order_archive_events(previous_status);

create index order_archive_events_new_status_idx
  on public.marketplace_order_archive_events(new_status);

create index order_archive_events_created_at_idx
  on public.marketplace_order_archive_events(created_at);
