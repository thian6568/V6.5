-- Migration 060 order retention disposition export delivery finalization approval completion delivery acceptance foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion delivery acceptance records and delivery acceptance event tracking after finalization approval completion confirmed delivery.
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
-- - delivery acceptance records are administrative workflow records only; they do not transfer ownership, release funds, mint NFTs, or delete files.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_status as enum (
      'pending_confirmed_delivery',
      'ready_for_delivery_acceptance',
      'delivery_acceptance_requested',
      'delivery_acceptance_in_progress',
      'delivery_accepted',
      'delivery_acceptance_failed',
      'delivery_acceptance_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_result as enum (
      'not_accepted',
      'accepted',
      'accepted_with_notes',
      'retention_hold',
      'discrepancy_found',
      'blocked',
      'needs_confirmed_delivery_update',
      'manual_acceptance'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_event as enum (
      'delivery_acceptance_created',
      'confirmed_delivery_attached',
      'delivery_acceptance_ready',
      'delivery_acceptance_requested',
      'delivery_acceptance_started',
      'delivery_acceptance_completed',
      'delivery_acceptance_failed',
      'delivery_acceptance_cancelled',
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_confirmed_delivery_record_id bigint not null,
  completion_certification_record_id bigint,
  completion_verification_record_id bigint,
  completion_handover_record_id bigint,
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
  accepted_by_profile_id bigint,
  verified_by_profile_id bigint,
  reviewed_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_status not null default 'pending_confirmed_delivery',
  delivery_acceptance_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_result not null default 'not_accepted',
  delivery_acceptance_reference text not null,
  delivery_acceptance_summary text,
  delivery_acceptance_note text,
  retention_hold_note text,
  discrepancy_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  accepted_at timestamptz,
  verified_at timestamptz,
  reviewed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_dacc_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_dacc_cdel_fk
    foreign key (completion_confirmed_delivery_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmed_delivery_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_dacc_cert_fk
    foreign key (completion_certification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_certification_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_verify_fk
    foreign key (completion_verification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_handover_fk
    foreign key (completion_handover_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_archive_fk
    foreign key (completion_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_archive_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_settlement_fk
    foreign key (completion_settlement_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_recon_fk
    foreign key (completion_recon_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_report_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_audit_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_closeout_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_final_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_conf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_rel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_app_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_rev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_accepted_by_fk
    foreign key (accepted_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_reviewed_by_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_reference_chk check (
    btrim(delivery_acceptance_reference) <> ''
  ),
  constraint ord_ret_fin_app_dacc_summary_chk check (
    delivery_acceptance_summary is null or btrim(delivery_acceptance_summary) <> ''
  ),
  constraint ord_ret_fin_app_dacc_note_chk check (
    delivery_acceptance_note is null or btrim(delivery_acceptance_note) <> ''
  ),
  constraint ord_ret_fin_app_dacc_hold_note_chk check (
    retention_hold_note is null or btrim(retention_hold_note) <> ''
  ),
  constraint ord_ret_fin_app_dacc_discrepancy_chk check (
    discrepancy_note is null or btrim(discrepancy_note) <> ''
  ),
  constraint ord_ret_fin_app_dacc_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_dacc_failed_reason_chk check (
    status <> 'delivery_acceptance_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_dacc_hold_result_chk check (
    delivery_acceptance_result <> 'retention_hold' or retention_hold_note is not null
  ),
  constraint ord_ret_fin_app_dacc_discrepancy_result_chk check (
    delivery_acceptance_result <> 'discrepancy_found' or discrepancy_note is not null
  ),
  constraint ord_ret_fin_app_dacc_result_status_chk check (
    (
      status in (
        'pending_confirmed_delivery',
        'ready_for_delivery_acceptance',
        'delivery_acceptance_requested',
        'delivery_acceptance_in_progress',
        'delivery_acceptance_cancelled'
      )
      and delivery_acceptance_result = 'not_accepted'
    )
    or (
      status = 'delivery_accepted'
      and delivery_acceptance_result in (
        'accepted',
        'accepted_with_notes',
        'retention_hold',
        'discrepancy_found',
        'manual_acceptance'
      )
    )
    or (
      status = 'delivery_acceptance_failed'
      and delivery_acceptance_result in (
        'blocked',
        'needs_confirmed_delivery_update'
      )
    )
  ),
  constraint ord_ret_fin_app_dacc_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_delivery_acceptance',
      'delivery_acceptance_requested',
      'delivery_acceptance_in_progress',
      'delivery_accepted',
      'delivery_acceptance_failed',
      'delivery_acceptance_cancelled'
    )
  ),
  constraint ord_ret_fin_app_dacc_requested_status_chk check (
    requested_at is null
    or status in (
      'delivery_acceptance_requested',
      'delivery_acceptance_in_progress',
      'delivery_accepted',
      'delivery_acceptance_failed',
      'delivery_acceptance_cancelled'
    )
  ),
  constraint ord_ret_fin_app_dacc_started_status_chk check (
    started_at is null
    or status in (
      'delivery_acceptance_in_progress',
      'delivery_accepted',
      'delivery_acceptance_failed',
      'delivery_acceptance_cancelled'
    )
  ),
  constraint ord_ret_fin_app_dacc_accepted_status_chk check (
    accepted_at is null or status = 'delivery_accepted'
  ),
  constraint ord_ret_fin_app_dacc_verified_status_chk check (
    verified_at is null or status = 'delivery_accepted'
  ),
  constraint ord_ret_fin_app_dacc_reviewed_status_chk check (
    reviewed_at is null or status = 'delivery_accepted'
  ),
  constraint ord_ret_fin_app_dacc_failed_status_chk check (
    failed_at is null or status = 'delivery_acceptance_failed'
  ),
  constraint ord_ret_fin_app_dacc_cancelled_status_chk check (
    cancelled_at is null or status = 'delivery_acceptance_cancelled'
  ),
  constraint ord_ret_fin_app_dacc_terminal_one_chk check (
    num_nonnulls(accepted_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_dacc_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_dacc_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(delivery_acceptance_reference);

create unique index ord_ret_fin_app_dacc_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(order_id)
  where status in (
    'pending_confirmed_delivery',
    'ready_for_delivery_acceptance',
    'delivery_acceptance_requested',
    'delivery_acceptance_in_progress',
    'delivery_acceptance_failed'
  );

create index ord_ret_fin_app_dacc_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(order_id);

create index ord_ret_fin_app_dacc_cdel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_confirmed_delivery_record_id);

create index ord_ret_fin_app_dacc_cert_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_certification_record_id);

create index ord_ret_fin_app_dacc_verify_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_verification_record_id);

create index ord_ret_fin_app_dacc_handover_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_handover_record_id);

create index ord_ret_fin_app_dacc_archive_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_archive_record_id);

create index ord_ret_fin_app_dacc_settlement_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_settlement_record_id);

create index ord_ret_fin_app_dacc_recon_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_recon_record_id);

create index ord_ret_fin_app_dacc_report_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_report_record_id);

create index ord_ret_fin_app_dacc_audit_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_audit_record_id);

create index ord_ret_fin_app_dacc_closeout_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_closeout_record_id);

create index ord_ret_fin_app_dacc_final_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_final_record_id);

create index ord_ret_fin_app_dacc_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_confirmation_record_id);

create index ord_ret_fin_app_dacc_rel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_release_record_id);

create index ord_ret_fin_app_dacc_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_approval_record_id);

create index ord_ret_fin_app_dacc_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(completion_review_record_id);

create index ord_ret_fin_app_dacc_completion_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(approval_completion_record_id);

create index ord_ret_fin_app_dacc_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(approval_confirmation_record_id);

create index ord_ret_fin_app_dacc_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(approval_release_record_id);

create index ord_ret_fin_app_dacc_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(finalization_approval_record_id);

create index ord_ret_fin_app_dacc_fin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(finalization_review_record_id);

create index ord_ret_fin_app_dacc_fin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(finalization_record_id);

create index ord_ret_fin_app_dacc_rel_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(review_release_confirmation_record_id);

create index ord_ret_fin_app_dacc_review_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(review_release_record_id);

create index ord_ret_fin_app_dacc_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(approval_record_id);

create index ord_ret_fin_app_dacc_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(review_record_id);

create index ord_ret_fin_app_dacc_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(delivery_record_id);

create index ord_ret_fin_app_dacc_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(export_record_id);

create index ord_ret_fin_app_dacc_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(evidence_record_id);

create index ord_ret_fin_app_dacc_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(requested_by_profile_id);

create index ord_ret_fin_app_dacc_accepted_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(accepted_by_profile_id);

create index ord_ret_fin_app_dacc_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(verified_by_profile_id);

create index ord_ret_fin_app_dacc_reviewed_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(reviewed_by_profile_id);

create index ord_ret_fin_app_dacc_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(status);

create index ord_ret_fin_app_dacc_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(delivery_acceptance_result);

create index ord_ret_fin_app_dacc_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(ready_at);

create index ord_ret_fin_app_dacc_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(requested_at);

create index ord_ret_fin_app_dacc_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(started_at);

create index ord_ret_fin_app_dacc_accepted_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(accepted_at);

create index ord_ret_fin_app_dacc_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(verified_at);

create index ord_ret_fin_app_dacc_reviewed_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(reviewed_at);

create index ord_ret_fin_app_dacc_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_events (
  id bigint generated always as identity primary key,
  completion_delivery_acceptance_record_id bigint not null,
  order_id bigint not null,
  completion_confirmed_delivery_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_dacc_events_record_fk
    foreign key (completion_delivery_acceptance_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_dacc_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_dacc_events_cdel_fk
    foreign key (completion_confirmed_delivery_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmed_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_dacc_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_dacc_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_dacc_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_dacc_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_dacc_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_events(completion_delivery_acceptance_record_id);

create index ord_ret_fin_app_dacc_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_events(order_id);

create index ord_ret_fin_app_dacc_events_cdel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_events(completion_confirmed_delivery_record_id);

create index ord_ret_fin_app_dacc_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_events(actor_profile_id);

create index ord_ret_fin_app_dacc_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_events(actor_role);

create index ord_ret_fin_app_dacc_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_events(event_type);

create index ord_ret_fin_app_dacc_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_events(previous_status);

create index ord_ret_fin_app_dacc_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_events(new_status);

create index ord_ret_fin_app_dacc_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_events(created_at);
