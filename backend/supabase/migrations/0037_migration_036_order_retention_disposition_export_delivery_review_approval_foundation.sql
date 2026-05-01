-- Migration 036 order retention disposition export delivery review approval foundation.
-- Scope: backend-only order retention disposition export delivery review approval records and approval event tracking after export delivery review.
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_review_approval_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_review_approval_status as enum (
      'pending_review',
      'ready_for_approval',
      'approval_requested',
      'approval_in_progress',
      'approval_approved',
      'approval_rejected',
      'approval_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_review_approval_decision'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_review_approval_decision as enum (
      'not_decided',
      'approved',
      'approved_with_notes',
      'rejected',
      'needs_review_update',
      'manual_approval'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_review_approval_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_review_approval_event as enum (
      'approval_created',
      'review_attached',
      'approval_ready',
      'approval_requested',
      'approval_started',
      'approval_granted',
      'approval_rejected',
      'approval_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_review_approval_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_review_approval_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_review_approval_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  review_record_id bigint,
  delivery_record_id bigint,
  export_record_id bigint,
  evidence_record_id bigint,
  requested_by_profile_id bigint,
  approver_profile_id bigint,
  secondary_approver_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_review_approval_status not null default 'pending_review',
  approval_decision public.marketplace_order_ret_disp_exp_del_review_approval_decision not null default 'not_decided',
  approval_reference text not null,
  approval_summary text,
  approval_note text,
  rejection_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  approved_at timestamptz,
  rejected_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_disp_exp_del_rev_app_records_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_disp_exp_del_rev_app_records_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_app_records_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_app_records_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_app_records_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_app_records_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_app_records_approver_fk
    foreign key (approver_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_app_records_secondary_fk
    foreign key (secondary_approver_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_app_records_reference_chk check (
    btrim(approval_reference) <> ''
  ),
  constraint ord_ret_disp_exp_del_rev_app_records_summary_chk check (
    approval_summary is null or btrim(approval_summary) <> ''
  ),
  constraint ord_ret_disp_exp_del_rev_app_records_note_chk check (
    approval_note is null or btrim(approval_note) <> ''
  ),
  constraint ord_ret_disp_exp_del_rev_app_records_rejection_chk check (
    rejection_reason is null or btrim(rejection_reason) <> ''
  ),
  constraint ord_ret_disp_exp_del_rev_app_records_rejected_reason_chk check (
    status <> 'approval_rejected' or rejection_reason is not null
  ),
  constraint ord_ret_disp_exp_del_rev_app_records_decision_status_chk check (
    (
      status in (
        'pending_review',
        'ready_for_approval',
        'approval_requested',
        'approval_in_progress',
        'approval_cancelled'
      )
      and approval_decision in (
        'not_decided',
        'manual_approval'
      )
    )
    or (
      status = 'approval_approved'
      and approval_decision in (
        'approved',
        'approved_with_notes'
      )
    )
    or (
      status = 'approval_rejected'
      and approval_decision in (
        'rejected',
        'needs_review_update'
      )
    )
  ),
  constraint ord_ret_disp_exp_del_rev_app_records_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_approval',
      'approval_requested',
      'approval_in_progress',
      'approval_approved',
      'approval_rejected',
      'approval_cancelled'
    )
  ),
  constraint ord_ret_disp_exp_del_rev_app_records_requested_status_chk check (
    requested_at is null
    or status in (
      'approval_requested',
      'approval_in_progress',
      'approval_approved',
      'approval_rejected',
      'approval_cancelled'
    )
  ),
  constraint ord_ret_disp_exp_del_rev_app_records_started_status_chk check (
    started_at is null
    or status in (
      'approval_in_progress',
      'approval_approved',
      'approval_rejected',
      'approval_cancelled'
    )
  ),
  constraint ord_ret_disp_exp_del_rev_app_records_approved_status_chk check (
    approved_at is null or status = 'approval_approved'
  ),
  constraint ord_ret_disp_exp_del_rev_app_records_rejected_status_chk check (
    rejected_at is null or status = 'approval_rejected'
  ),
  constraint ord_ret_disp_exp_del_rev_app_records_cancelled_status_chk check (
    cancelled_at is null or status = 'approval_cancelled'
  ),
  constraint ord_ret_disp_exp_del_rev_app_records_terminal_exclusive_chk check (
    num_nonnulls(approved_at, rejected_at, cancelled_at) <= 1
  ),
  constraint ord_ret_disp_exp_del_rev_app_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_disp_exp_del_rev_app_records_reference_key
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(approval_reference);

create unique index ord_ret_disp_exp_del_rev_app_records_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(order_id)
  where status in (
    'pending_review',
    'ready_for_approval',
    'approval_requested',
    'approval_in_progress',
    'approval_rejected'
  );

create index ord_ret_disp_exp_del_rev_app_records_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(order_id);

create index ord_ret_disp_exp_del_rev_app_records_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(review_record_id);

create index ord_ret_disp_exp_del_rev_app_records_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(delivery_record_id);

create index ord_ret_disp_exp_del_rev_app_records_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(export_record_id);

create index ord_ret_disp_exp_del_rev_app_records_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(evidence_record_id);

create index ord_ret_disp_exp_del_rev_app_records_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(requested_by_profile_id);

create index ord_ret_disp_exp_del_rev_app_records_approver_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(approver_profile_id);

create index ord_ret_disp_exp_del_rev_app_records_secondary_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(secondary_approver_profile_id);

create index ord_ret_disp_exp_del_rev_app_records_status_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(status);

create index ord_ret_disp_exp_del_rev_app_records_decision_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(approval_decision);

create index ord_ret_disp_exp_del_rev_app_records_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(ready_at);

create index ord_ret_disp_exp_del_rev_app_records_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(requested_at);

create index ord_ret_disp_exp_del_rev_app_records_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(started_at);

create index ord_ret_disp_exp_del_rev_app_records_approved_at_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(approved_at);

create index ord_ret_disp_exp_del_rev_app_records_rejected_at_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(rejected_at);

create index ord_ret_disp_exp_del_rev_app_records_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_review_approval_events (
  id bigint generated always as identity primary key,
  approval_record_id bigint not null,
  order_id bigint not null,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_review_approval_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_review_approval_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_review_approval_status,
  new_status public.marketplace_order_ret_disp_exp_del_review_approval_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_disp_exp_del_rev_app_events_record_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete cascade,

  constraint ord_ret_disp_exp_del_rev_app_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_disp_exp_del_rev_app_events_actor_profile_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_app_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_disp_exp_del_rev_app_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_disp_exp_del_rev_app_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_disp_exp_del_rev_app_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_disp_exp_del_rev_app_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_events(approval_record_id);

create index ord_ret_disp_exp_del_rev_app_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_events(order_id);

create index ord_ret_disp_exp_del_rev_app_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_events(actor_profile_id);

create index ord_ret_disp_exp_del_rev_app_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_events(actor_role);

create index ord_ret_disp_exp_del_rev_app_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_events(event_type);

create index ord_ret_disp_exp_del_rev_app_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_events(previous_status);

create index ord_ret_disp_exp_del_rev_app_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_events(new_status);

create index ord_ret_disp_exp_del_rev_app_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_review_approval_events(created_at);
