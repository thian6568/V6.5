-- Migration 046 order retention disposition export delivery finalization approval completion approval foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion approval records and approval event tracking after finalization approval completion review.
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_app_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_status as enum (
      'pending_review',
      'ready_for_approval',
      'approval_requested',
      'approval_in_progress',
      'approved',
      'approval_failed',
      'approval_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_app_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_result as enum (
      'not_approved',
      'approved',
      'approved_with_notes',
      'blocked',
      'needs_review_update',
      'manual_approval'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_app_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_event as enum (
      'approval_created',
      'review_attached',
      'approval_ready',
      'approval_requested',
      'approval_started',
      'approval_completed',
      'approval_failed',
      'approval_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_app_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_review_record_id bigint not null,
  approval_completion_record_id bigint,
  approval_confirmation_record_id bigint,
  approval_release_record_id bigint,
  finalization_approval_record_id bigint,
  finalization_review_record_id bigint,
  finalization_record_id bigint,
  review_release_confirmation_record_id bigint,
  review_release_record_id bigint,
  approval_record_id bigint,
  review_record_id bigint,
  delivery_record_id bigint,
  export_record_id bigint,
  evidence_record_id bigint,
  requested_by_profile_id bigint,
  approved_by_profile_id bigint,
  verified_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_status not null default 'pending_review',
  approval_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_result not null default 'not_approved',
  approval_reference text not null,
  approval_summary text,
  approval_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  approved_at timestamptz,
  verified_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_capp_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_capp_comp_review_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_capp_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_approved_by_fk
    foreign key (approved_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_reference_chk check (
    btrim(approval_reference) <> ''
  ),
  constraint ord_ret_fin_app_capp_summary_chk check (
    approval_summary is null or btrim(approval_summary) <> ''
  ),
  constraint ord_ret_fin_app_capp_note_chk check (
    approval_note is null or btrim(approval_note) <> ''
  ),
  constraint ord_ret_fin_app_capp_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_capp_failed_reason_chk check (
    status <> 'approval_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_capp_result_status_chk check (
    (
      status in (
        'pending_review',
        'ready_for_approval',
        'approval_requested',
        'approval_in_progress',
        'approval_cancelled'
      )
      and approval_result = 'not_approved'
    )
    or (
      status = 'approved'
      and approval_result in (
        'approved',
        'approved_with_notes',
        'manual_approval'
      )
    )
    or (
      status = 'approval_failed'
      and approval_result in (
        'blocked',
        'needs_review_update'
      )
    )
  ),
  constraint ord_ret_fin_app_capp_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_approval',
      'approval_requested',
      'approval_in_progress',
      'approved',
      'approval_failed',
      'approval_cancelled'
    )
  ),
  constraint ord_ret_fin_app_capp_requested_status_chk check (
    requested_at is null
    or status in (
      'approval_requested',
      'approval_in_progress',
      'approved',
      'approval_failed',
      'approval_cancelled'
    )
  ),
  constraint ord_ret_fin_app_capp_started_status_chk check (
    started_at is null
    or status in (
      'approval_in_progress',
      'approved',
      'approval_failed',
      'approval_cancelled'
    )
  ),
  constraint ord_ret_fin_app_capp_approved_status_chk check (
    approved_at is null or status = 'approved'
  ),
  constraint ord_ret_fin_app_capp_verified_status_chk check (
    verified_at is null or status = 'approved'
  ),
  constraint ord_ret_fin_app_capp_failed_status_chk check (
    failed_at is null or status = 'approval_failed'
  ),
  constraint ord_ret_fin_app_capp_cancelled_status_chk check (
    cancelled_at is null or status = 'approval_cancelled'
  ),
  constraint ord_ret_fin_app_capp_terminal_one_chk check (
    num_nonnulls(approved_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_capp_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_capp_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(approval_reference);

create unique index ord_ret_fin_app_capp_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(order_id)
  where status in (
    'pending_review',
    'ready_for_approval',
    'approval_requested',
    'approval_in_progress',
    'approval_failed'
  );

create index ord_ret_fin_app_capp_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(order_id);

create index ord_ret_fin_app_capp_comp_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(completion_review_record_id);

create index ord_ret_fin_app_capp_completion_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(approval_completion_record_id);

create index ord_ret_fin_app_capp_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(approval_confirmation_record_id);

create index ord_ret_fin_app_capp_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(approval_release_record_id);

create index ord_ret_fin_app_capp_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(finalization_approval_record_id);

create index ord_ret_fin_app_capp_fin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(finalization_review_record_id);

create index ord_ret_fin_app_capp_fin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(finalization_record_id);

create index ord_ret_fin_app_capp_rel_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(review_release_confirmation_record_id);

create index ord_ret_fin_app_capp_review_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(review_release_record_id);

create index ord_ret_fin_app_capp_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(approval_record_id);

create index ord_ret_fin_app_capp_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(review_record_id);

create index ord_ret_fin_app_capp_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(delivery_record_id);

create index ord_ret_fin_app_capp_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(export_record_id);

create index ord_ret_fin_app_capp_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(evidence_record_id);

create index ord_ret_fin_app_capp_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(requested_by_profile_id);

create index ord_ret_fin_app_capp_approved_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(approved_by_profile_id);

create index ord_ret_fin_app_capp_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(verified_by_profile_id);

create index ord_ret_fin_app_capp_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(status);

create index ord_ret_fin_app_capp_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(approval_result);

create index ord_ret_fin_app_capp_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(ready_at);

create index ord_ret_fin_app_capp_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(requested_at);

create index ord_ret_fin_app_capp_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(started_at);

create index ord_ret_fin_app_capp_approved_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(approved_at);

create index ord_ret_fin_app_capp_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(verified_at);

create index ord_ret_fin_app_capp_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_events (
  id bigint generated always as identity primary key,
  completion_approval_record_id bigint not null,
  order_id bigint not null,
  completion_review_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_capp_events_record_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_capp_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_capp_events_comp_review_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_events_actor_profile_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_capp_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_capp_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_capp_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_capp_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_capp_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_events(completion_approval_record_id);

create index ord_ret_fin_app_capp_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_events(order_id);

create index ord_ret_fin_app_capp_events_comp_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_events(completion_review_record_id);

create index ord_ret_fin_app_capp_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_events(actor_profile_id);

create index ord_ret_fin_app_capp_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_events(actor_role);

create index ord_ret_fin_app_capp_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_events(event_type);

create index ord_ret_fin_app_capp_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_events(previous_status);

create index ord_ret_fin_app_capp_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_events(new_status);

create index ord_ret_fin_app_capp_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_events(created_at);
