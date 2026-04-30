-- Migration 026 order post-closure audit foundation.
-- Scope: backend-only post-closure audit records and event tracking after order closure.
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
      and t.typname = 'marketplace_order_post_closure_audit_status'
  ) then
    create type public.marketplace_order_post_closure_audit_status as enum (
      'pending_review',
      'in_review',
      'resolved',
      'closed_no_action',
      'action_required',
      'cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_post_closure_audit_type'
  ) then
    create type public.marketplace_order_post_closure_audit_type as enum (
      'post_closure_review',
      'buyer_follow_up',
      'seller_follow_up',
      'support_review',
      'admin_review',
      'system_review',
      'manual_record'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_post_closure_audit_event_type'
  ) then
    create type public.marketplace_order_post_closure_audit_event_type as enum (
      'audit_created',
      'audit_started',
      'audit_resolved',
      'audit_closed_no_action',
      'action_required',
      'audit_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_post_closure_audit_actor_role'
  ) then
    create type public.marketplace_order_post_closure_audit_actor_role as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_post_closure_audit_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  closure_record_id bigint,
  evidence_record_id bigint,
  initiated_by_profile_id bigint,
  reviewed_by_profile_id bigint,
  status public.marketplace_order_post_closure_audit_status not null default 'pending_review',
  audit_type public.marketplace_order_post_closure_audit_type not null default 'post_closure_review',
  audit_reference text not null,
  audit_summary text,
  resolution_note text,
  action_required_note text,
  cancellation_reason text,
  review_started_at timestamptz,
  resolved_at timestamptz,
  closed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint post_closure_audit_records_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint post_closure_audit_records_closure_id_fk
    foreign key (closure_record_id)
    references public.marketplace_order_closure_records(id)
    on delete set null,

  constraint post_closure_audit_records_evidence_id_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_completion_evidence_records(id)
    on delete set null,

  constraint post_closure_audit_records_initiated_by_id_fk
    foreign key (initiated_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint post_closure_audit_records_reviewed_by_id_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint post_closure_audit_records_reference_nonblank_chk check (
    btrim(audit_reference) <> ''
  ),
  constraint post_closure_audit_records_summary_nonblank_chk check (
    audit_summary is null or btrim(audit_summary) <> ''
  ),
  constraint post_closure_audit_records_resolution_nonblank_chk check (
    resolution_note is null or btrim(resolution_note) <> ''
  ),
  constraint post_closure_audit_records_action_note_nonblank_chk check (
    action_required_note is null or btrim(action_required_note) <> ''
  ),
  constraint post_closure_audit_records_cancellation_nonblank_chk check (
    cancellation_reason is null or btrim(cancellation_reason) <> ''
  ),
  constraint post_closure_audit_records_action_required_note_chk check (
    status <> 'action_required' or action_required_note is not null
  ),
  constraint post_closure_audit_records_cancelled_reason_chk check (
    status <> 'cancelled' or cancellation_reason is not null
  ),
  constraint post_closure_audit_records_started_status_chk check (
    review_started_at is null
    or status in (
      'in_review',
      'resolved',
      'closed_no_action',
      'action_required',
      'cancelled'
    )
  ),
  constraint post_closure_audit_records_resolved_status_chk check (
    resolved_at is null or status = 'resolved'
  ),
  constraint post_closure_audit_records_closed_status_chk check (
    closed_at is null or status = 'closed_no_action'
  ),
  constraint post_closure_audit_records_cancelled_status_chk check (
    cancelled_at is null or status = 'cancelled'
  ),
  constraint post_closure_audit_records_terminal_exclusive_chk check (
    num_nonnulls(resolved_at, closed_at, cancelled_at) <= 1
  ),
  constraint post_closure_audit_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index post_closure_audit_records_reference_key
  on public.marketplace_order_post_closure_audit_records(audit_reference);

create unique index post_closure_audit_records_one_active_per_order_idx
  on public.marketplace_order_post_closure_audit_records(order_id)
  where status in (
    'pending_review',
    'in_review',
    'action_required'
  );

create index post_closure_audit_records_order_id_idx
  on public.marketplace_order_post_closure_audit_records(order_id);

create index post_closure_audit_records_closure_id_idx
  on public.marketplace_order_post_closure_audit_records(closure_record_id);

create index post_closure_audit_records_evidence_id_idx
  on public.marketplace_order_post_closure_audit_records(evidence_record_id);

create index post_closure_audit_records_initiated_by_id_idx
  on public.marketplace_order_post_closure_audit_records(initiated_by_profile_id);

create index post_closure_audit_records_reviewed_by_id_idx
  on public.marketplace_order_post_closure_audit_records(reviewed_by_profile_id);

create index post_closure_audit_records_status_idx
  on public.marketplace_order_post_closure_audit_records(status);

create index post_closure_audit_records_type_idx
  on public.marketplace_order_post_closure_audit_records(audit_type);

create index post_closure_audit_records_review_started_at_idx
  on public.marketplace_order_post_closure_audit_records(review_started_at);

create index post_closure_audit_records_resolved_at_idx
  on public.marketplace_order_post_closure_audit_records(resolved_at);

create index post_closure_audit_records_created_at_idx
  on public.marketplace_order_post_closure_audit_records(created_at);

create table public.marketplace_order_post_closure_audit_events (
  id bigint generated always as identity primary key,
  audit_record_id bigint not null,
  order_id bigint not null,
  actor_profile_id bigint,
  actor_role public.marketplace_order_post_closure_audit_actor_role not null default 'system',
  event_type public.marketplace_order_post_closure_audit_event_type not null,
  previous_status public.marketplace_order_post_closure_audit_status,
  new_status public.marketplace_order_post_closure_audit_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint post_closure_audit_events_record_id_fk
    foreign key (audit_record_id)
    references public.marketplace_order_post_closure_audit_records(id)
    on delete cascade,

  constraint post_closure_audit_events_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint post_closure_audit_events_actor_profile_id_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint post_closure_audit_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint post_closure_audit_events_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint post_closure_audit_events_manual_note_required_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint post_closure_audit_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index post_closure_audit_events_record_id_idx
  on public.marketplace_order_post_closure_audit_events(audit_record_id);

create index post_closure_audit_events_order_id_idx
  on public.marketplace_order_post_closure_audit_events(order_id);

create index post_closure_audit_events_actor_profile_id_idx
  on public.marketplace_order_post_closure_audit_events(actor_profile_id);

create index post_closure_audit_events_actor_role_idx
  on public.marketplace_order_post_closure_audit_events(actor_role);

create index post_closure_audit_events_event_type_idx
  on public.marketplace_order_post_closure_audit_events(event_type);

create index post_closure_audit_events_previous_status_idx
  on public.marketplace_order_post_closure_audit_events(previous_status);

create index post_closure_audit_events_new_status_idx
  on public.marketplace_order_post_closure_audit_events(new_status);

create index post_closure_audit_events_created_at_idx
  on public.marketplace_order_post_closure_audit_events(created_at);
