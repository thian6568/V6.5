-- Migration 024 order completion evidence foundation.
-- Scope: backend-only order completion evidence records and event tracking after completion acceptance.
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
      and t.typname = 'marketplace_order_completion_evidence_status'
  ) then
    create type public.marketplace_order_completion_evidence_status as enum (
      'pending_review',
      'accepted',
      'rejected',
      'superseded',
      'cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_completion_evidence_type'
  ) then
    create type public.marketplace_order_completion_evidence_type as enum (
      'buyer_confirmation',
      'seller_confirmation',
      'handover_note',
      'condition_note',
      'invoice_snapshot',
      'acceptance_note',
      'manual_record',
      'system_record'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_completion_evidence_event_type'
  ) then
    create type public.marketplace_order_completion_evidence_event_type as enum (
      'evidence_created',
      'evidence_updated',
      'evidence_accepted',
      'evidence_rejected',
      'evidence_superseded',
      'evidence_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_completion_evidence_actor_role'
  ) then
    create type public.marketplace_order_completion_evidence_actor_role as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_completion_evidence_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  acceptance_record_id bigint,
  handover_record_id bigint,
  created_by_profile_id bigint,
  status public.marketplace_order_completion_evidence_status not null default 'pending_review',
  evidence_type public.marketplace_order_completion_evidence_type not null,
  evidence_reference text not null,
  evidence_summary text,
  reviewed_by_profile_id bigint,
  reviewed_at timestamptz,
  rejection_reason text,
  superseded_by_record_id bigint,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint completion_evidence_records_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint completion_evidence_records_acceptance_id_fk
    foreign key (acceptance_record_id)
    references public.marketplace_order_completion_acceptance_records(id)
    on delete set null,

  constraint completion_evidence_records_handover_id_fk
    foreign key (handover_record_id)
    references public.marketplace_order_handover_records(id)
    on delete set null,

  constraint completion_evidence_records_created_by_id_fk
    foreign key (created_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint completion_evidence_records_reviewed_by_id_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint completion_evidence_records_superseded_by_id_fk
    foreign key (superseded_by_record_id)
    references public.marketplace_order_completion_evidence_records(id)
    on delete set null,

  constraint completion_evidence_records_reference_nonblank_chk check (
    btrim(evidence_reference) <> ''
  ),
  constraint completion_evidence_records_summary_nonblank_chk check (
    evidence_summary is null or btrim(evidence_summary) <> ''
  ),
  constraint completion_evidence_records_rejection_nonblank_chk check (
    rejection_reason is null or btrim(rejection_reason) <> ''
  ),
  constraint completion_evidence_records_rejected_reason_chk check (
    status <> 'rejected' or rejection_reason is not null
  ),
  constraint completion_evidence_records_reviewed_status_chk check (
    reviewed_at is null or status in ('accepted', 'rejected', 'superseded', 'cancelled')
  ),
  constraint completion_evidence_records_superseded_chk check (
    status <> 'superseded' or superseded_by_record_id is not null
  ),
  constraint completion_evidence_records_not_self_superseded_chk check (
    superseded_by_record_id is null or superseded_by_record_id <> id
  ),
  constraint completion_evidence_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index completion_evidence_records_reference_key
  on public.marketplace_order_completion_evidence_records(evidence_reference);

create index completion_evidence_records_order_id_idx
  on public.marketplace_order_completion_evidence_records(order_id);

create index completion_evidence_records_acceptance_id_idx
  on public.marketplace_order_completion_evidence_records(acceptance_record_id);

create index completion_evidence_records_handover_id_idx
  on public.marketplace_order_completion_evidence_records(handover_record_id);

create index completion_evidence_records_created_by_id_idx
  on public.marketplace_order_completion_evidence_records(created_by_profile_id);

create index completion_evidence_records_reviewed_by_id_idx
  on public.marketplace_order_completion_evidence_records(reviewed_by_profile_id);

create index completion_evidence_records_superseded_by_id_idx
  on public.marketplace_order_completion_evidence_records(superseded_by_record_id);

create index completion_evidence_records_status_idx
  on public.marketplace_order_completion_evidence_records(status);

create index completion_evidence_records_type_idx
  on public.marketplace_order_completion_evidence_records(evidence_type);

create index completion_evidence_records_reviewed_at_idx
  on public.marketplace_order_completion_evidence_records(reviewed_at);

create index completion_evidence_records_created_at_idx
  on public.marketplace_order_completion_evidence_records(created_at);

create table public.marketplace_order_completion_evidence_events (
  id bigint generated always as identity primary key,
  evidence_record_id bigint not null,
  order_id bigint not null,
  actor_profile_id bigint,
  actor_role public.marketplace_order_completion_evidence_actor_role not null default 'system',
  event_type public.marketplace_order_completion_evidence_event_type not null,
  previous_status public.marketplace_order_completion_evidence_status,
  new_status public.marketplace_order_completion_evidence_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint completion_evidence_events_record_id_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_completion_evidence_records(id)
    on delete cascade,

  constraint completion_evidence_events_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint completion_evidence_events_actor_profile_id_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint completion_evidence_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint completion_evidence_events_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint completion_evidence_events_manual_note_required_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint completion_evidence_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index completion_evidence_events_record_id_idx
  on public.marketplace_order_completion_evidence_events(evidence_record_id);

create index completion_evidence_events_order_id_idx
  on public.marketplace_order_completion_evidence_events(order_id);

create index completion_evidence_events_actor_profile_id_idx
  on public.marketplace_order_completion_evidence_events(actor_profile_id);

create index completion_evidence_events_actor_role_idx
  on public.marketplace_order_completion_evidence_events(actor_role);

create index completion_evidence_events_event_type_idx
  on public.marketplace_order_completion_evidence_events(event_type);

create index completion_evidence_events_previous_status_idx
  on public.marketplace_order_completion_evidence_events(previous_status);

create index completion_evidence_events_new_status_idx
  on public.marketplace_order_completion_evidence_events(new_status);

create index completion_evidence_events_created_at_idx
  on public.marketplace_order_completion_evidence_events(created_at);
