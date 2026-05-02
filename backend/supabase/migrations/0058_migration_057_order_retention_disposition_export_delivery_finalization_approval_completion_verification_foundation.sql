-- Migration 057 order retention disposition export delivery finalization approval completion verification foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion verification records and verification event tracking after finalization approval completion handover.
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
-- - verification records are administrative workflow records only; they do not transfer ownership, release funds, or delete files.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_verify_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_verify_status as enum (
      'pending_handover',
      'ready_for_verification',
      'verification_requested',
      'verification_in_progress',
      'verified',
      'verification_failed',
      'verification_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_verify_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_verify_result as enum (
      'not_verified',
      'verified',
      'verified_with_notes',
      'retention_hold',
      'discrepancy_found',
      'blocked',
      'needs_handover_update',
      'manual_verification'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_verify_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_verify_event as enum (
      'verification_created',
      'handover_attached',
      'verification_ready',
      'verification_requested',
      'verification_started',
      'verification_completed',
      'verification_failed',
      'verification_cancelled',
      'retention_hold_recorded',
      'discrepancy_recorded',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_verify_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_verify_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_handover_record_id bigint not null,
  completion_archive_record_id bigint,
  completion_settlement_record_id bigint,
  completion_recon_record_id bigint,
  completion_report_record_id bigint,
  completion_audit_record_id bigint,
  completion_closeout_record_id bigint,
  completion_final_record_id bigint,
  completion_confirmation_record_id bigint,
  completion_release_record_id bigint,
  completion_approval_record_id bigint,
  completion_review_record_id bigint,
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
  verified_by_profile_id bigint,
  reviewed_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_verify_status not null default 'pending_handover',
  verification_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_verify_result not null default 'not_verified',
  verification_reference text not null,
  verification_summary text,
  verification_note text,
  retention_hold_note text,
  discrepancy_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  verified_at timestamptz,
  reviewed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_verify_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_verify_handover_fk
    foreign key (completion_handover_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_verify_archive_fk
    foreign key (completion_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_archive_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_settlement_fk
    foreign key (completion_settlement_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_recon_fk
    foreign key (completion_recon_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_report_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_audit_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_closeout_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_final_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_conf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_rel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_app_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_rev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_reviewed_by_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_reference_chk check (
    btrim(verification_reference) <> ''
  ),
  constraint ord_ret_fin_app_verify_summary_chk check (
    verification_summary is null or btrim(verification_summary) <> ''
  ),
  constraint ord_ret_fin_app_verify_note_chk check (
    verification_note is null or btrim(verification_note) <> ''
  ),
  constraint ord_ret_fin_app_verify_hold_note_chk check (
    retention_hold_note is null or btrim(retention_hold_note) <> ''
  ),
  constraint ord_ret_fin_app_verify_discrepancy_chk check (
    discrepancy_note is null or btrim(discrepancy_note) <> ''
  ),
  constraint ord_ret_fin_app_verify_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_verify_failed_reason_chk check (
    status <> 'verification_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_verify_hold_result_chk check (
    verification_result <> 'retention_hold' or retention_hold_note is not null
  ),
  constraint ord_ret_fin_app_verify_discrepancy_result_chk check (
    verification_result <> 'discrepancy_found' or discrepancy_note is not null
  ),
  constraint ord_ret_fin_app_verify_result_status_chk check (
    (
      status in (
        'pending_handover',
        'ready_for_verification',
        'verification_requested',
        'verification_in_progress',
        'verification_cancelled'
      )
      and verification_result = 'not_verified'
    )
    or (
      status = 'verified'
      and verification_result in (
        'verified',
        'verified_with_notes',
        'retention_hold',
        'discrepancy_found',
        'manual_verification'
      )
    )
    or (
      status = 'verification_failed'
      and verification_result in (
        'blocked',
        'needs_handover_update'
      )
    )
  ),
  constraint ord_ret_fin_app_verify_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_verification',
      'verification_requested',
      'verification_in_progress',
      'verified',
      'verification_failed',
      'verification_cancelled'
    )
  ),
  constraint ord_ret_fin_app_verify_requested_status_chk check (
    requested_at is null
    or status in (
      'verification_requested',
      'verification_in_progress',
      'verified',
      'verification_failed',
      'verification_cancelled'
    )
  ),
  constraint ord_ret_fin_app_verify_started_status_chk check (
    started_at is null
    or status in (
      'verification_in_progress',
      'verified',
      'verification_failed',
      'verification_cancelled'
    )
  ),
  constraint ord_ret_fin_app_verify_verified_status_chk check (
    verified_at is null or status = 'verified'
  ),
  constraint ord_ret_fin_app_verify_reviewed_status_chk check (
    reviewed_at is null or status = 'verified'
  ),
  constraint ord_ret_fin_app_verify_failed_status_chk check (
    failed_at is null or status = 'verification_failed'
  ),
  constraint ord_ret_fin_app_verify_cancelled_status_chk check (
    cancelled_at is null or status = 'verification_cancelled'
  ),
  constraint ord_ret_fin_app_verify_terminal_one_chk check (
    num_nonnulls(verified_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_verify_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_verify_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(verification_reference);

create unique index ord_ret_fin_app_verify_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(order_id)
  where status in (
    'pending_handover',
    'ready_for_verification',
    'verification_requested',
    'verification_in_progress',
    'verification_failed'
  );

create index ord_ret_fin_app_verify_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(order_id);

create index ord_ret_fin_app_verify_handover_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(completion_handover_record_id);

create index ord_ret_fin_app_verify_archive_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(completion_archive_record_id);

create index ord_ret_fin_app_verify_settlement_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(completion_settlement_record_id);

create index ord_ret_fin_app_verify_recon_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(completion_recon_record_id);

create index ord_ret_fin_app_verify_report_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(completion_report_record_id);

create index ord_ret_fin_app_verify_audit_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(completion_audit_record_id);

create index ord_ret_fin_app_verify_closeout_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(completion_closeout_record_id);

create index ord_ret_fin_app_verify_final_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(completion_final_record_id);

create index ord_ret_fin_app_verify_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(completion_confirmation_record_id);

create index ord_ret_fin_app_verify_rel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(completion_release_record_id);

create index ord_ret_fin_app_verify_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(completion_approval_record_id);

create index ord_ret_fin_app_verify_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(completion_review_record_id);

create index ord_ret_fin_app_verify_completion_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(approval_completion_record_id);

create index ord_ret_fin_app_verify_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(approval_confirmation_record_id);

create index ord_ret_fin_app_verify_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(approval_release_record_id);

create index ord_ret_fin_app_verify_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(finalization_approval_record_id);

create index ord_ret_fin_app_verify_fin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(finalization_review_record_id);

create index ord_ret_fin_app_verify_fin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(finalization_record_id);

create index ord_ret_fin_app_verify_rel_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(review_release_confirmation_record_id);

create index ord_ret_fin_app_verify_review_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(review_release_record_id);

create index ord_ret_fin_app_verify_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(approval_record_id);

create index ord_ret_fin_app_verify_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(review_record_id);

create index ord_ret_fin_app_verify_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(delivery_record_id);

create index ord_ret_fin_app_verify_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(export_record_id);

create index ord_ret_fin_app_verify_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(evidence_record_id);

create index ord_ret_fin_app_verify_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(requested_by_profile_id);

create index ord_ret_fin_app_verify_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(verified_by_profile_id);

create index ord_ret_fin_app_verify_reviewed_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(reviewed_by_profile_id);

create index ord_ret_fin_app_verify_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(status);

create index ord_ret_fin_app_verify_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(verification_result);

create index ord_ret_fin_app_verify_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(ready_at);

create index ord_ret_fin_app_verify_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(requested_at);

create index ord_ret_fin_app_verify_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(started_at);

create index ord_ret_fin_app_verify_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(verified_at);

create index ord_ret_fin_app_verify_reviewed_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(reviewed_at);

create index ord_ret_fin_app_verify_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_events (
  id bigint generated always as identity primary key,
  completion_verification_record_id bigint not null,
  order_id bigint not null,
  completion_handover_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_verify_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_verify_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_verify_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_verify_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_verify_events_record_fk
    foreign key (completion_verification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_verify_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_verify_events_handover_fk
    foreign key (completion_handover_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_verify_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_verify_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_verify_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_verify_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_verify_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_events(completion_verification_record_id);

create index ord_ret_fin_app_verify_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_events(order_id);

create index ord_ret_fin_app_verify_events_handover_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_events(completion_handover_record_id);

create index ord_ret_fin_app_verify_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_events(actor_profile_id);

create index ord_ret_fin_app_verify_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_events(actor_role);

create index ord_ret_fin_app_verify_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_events(event_type);

create index ord_ret_fin_app_verify_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_events(previous_status);

create index ord_ret_fin_app_verify_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_events(new_status);

create index ord_ret_fin_app_verify_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_events(created_at);
