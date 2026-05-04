-- Migration 084 order retention disposition export delivery finalization approval completion acceptance completion report foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion acceptance completion report records and completion report event tracking after completion audit.
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
-- - completion report records are administrative workflow records only; they do not transfer ownership, release funds, mint NFTs, or delete files.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_status as enum (
      'pending_completion_audit',
      'ready_for_completion_report',
      'completion_report_requested',
      'completion_report_in_progress',
      'completion_reported',
      'completion_report_failed',
      'completion_report_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_result as enum (
      'not_reported',
      'reported',
      'reported_with_notes',
      'retention_hold',
      'discrepancy_found',
      'blocked',
      'needs_completion_audit_update',
      'manual_report'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_event as enum (
      'completion_report_created',
      'completion_audit_attached',
      'completion_report_ready',
      'completion_report_requested',
      'completion_report_started',
      'completion_report_completed',
      'completion_report_failed',
      'completion_report_cancelled',
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_audit_record_id bigint not null,
  completion_approval_record_id bigint,
  completion_review_record_id bigint,
  completion_release_record_id bigint,
  completion_confirmation_record_id bigint,
  completion_finalization_record_id bigint,
  completion_acceptance_final_record_id bigint,
  completion_acceptance_archive_record_id bigint,
  completion_acceptance_closeout_record_id bigint,
  completion_acceptance_settlement_record_id bigint,
  completion_acceptance_reconciliation_record_id bigint,
  completion_acceptance_audit_record_id bigint,
  completion_acceptance_reporting_record_id bigint,
  completion_acceptance_verification_record_id bigint,
  completion_acceptance_certification_record_id bigint,
  completion_acceptance_completion_record_id bigint,
  completion_acceptance_finalization_record_id bigint,
  completion_acceptance_archive_prior_record_id bigint,
  completion_acceptance_closeout_prior_record_id bigint,
  completion_acceptance_confirmation_record_id bigint,
  completion_acceptance_release_record_id bigint,
  completion_acceptance_approval_record_id bigint,
  completion_acceptance_review_record_id bigint,
  completion_delivery_acceptance_record_id bigint,
  completion_confirmed_delivery_record_id bigint,
  completion_certification_record_id bigint,
  completion_verification_record_id bigint,
  completion_handover_record_id bigint,
  completion_archive_record_id bigint,
  completion_settlement_record_id bigint,
  completion_recon_record_id bigint,
  completion_report_prior_record_id bigint,
  completion_audit_prior_record_id bigint,
  completion_closeout_record_id bigint,
  completion_final_record_id bigint,
  completion_confirmation_prior_record_id bigint,
  completion_release_prior_record_id bigint,
  completion_approval_prior_record_id bigint,
  completion_review_prior_record_id bigint,
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
  reported_by_profile_id bigint,
  verified_by_profile_id bigint,
  reviewed_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_status not null default 'pending_completion_audit',
  completion_report_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_result not null default 'not_reported',
  completion_report_reference text not null,
  completion_report_summary text,
  completion_report_note text,
  retention_hold_note text,
  discrepancy_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  reported_at timestamptz,
  verified_at timestamptz,
  reviewed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_acrep_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrep_acaud_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acaud_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrep_acapp_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_acrev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_acrel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrel_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_acconf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_acfin_fk
    foreign key (completion_finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfin_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_asfinal_fk
    foreign key (completion_acceptance_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asfinal_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_asarc_fk
    foreign key (completion_acceptance_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asarc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_asclo_fk
    foreign key (completion_acceptance_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asclo_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_asett_fk
    foreign key (completion_acceptance_settlement_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asett_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_arecon_fk
    foreign key (completion_acceptance_reconciliation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arecon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_aaud_fk
    foreign key (completion_acceptance_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aaud_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_arep_fk
    foreign key (completion_acceptance_reporting_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arep_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_aver_fk
    foreign key (completion_acceptance_verification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aver_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_acert_fk
    foreign key (completion_acceptance_certification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acert_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_acomp_fk
    foreign key (completion_acceptance_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acomp_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_afin_fk
    foreign key (completion_acceptance_finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_aarc_fk
    foreign key (completion_acceptance_archive_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aarc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_aclo_fk
    foreign key (completion_acceptance_closeout_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aclo_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_aconf_fk
    foreign key (completion_acceptance_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aconf_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_arel_fk
    foreign key (completion_acceptance_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arel_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_aapp_fk
    foreign key (completion_acceptance_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aapp_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_arev_fk
    foreign key (completion_acceptance_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arev_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_dacc_fk
    foreign key (completion_delivery_acceptance_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_cdel_fk
    foreign key (completion_confirmed_delivery_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmed_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_cert_fk
    foreign key (completion_certification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_certification_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_verify_fk
    foreign key (completion_verification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_handover_fk
    foreign key (completion_handover_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_archive_fk
    foreign key (completion_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_archive_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_settlement_fk
    foreign key (completion_settlement_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_recon_fk
    foreign key (completion_recon_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_report_prior_fk
    foreign key (completion_report_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_audit_prior_fk
    foreign key (completion_audit_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_closeout_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_final_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_conf_fk
    foreign key (completion_confirmation_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_rel_fk
    foreign key (completion_release_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_app_fk
    foreign key (completion_approval_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_rev_fk
    foreign key (completion_review_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_reported_by_fk
    foreign key (reported_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_reviewed_by_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_reference_chk check (
    btrim(completion_report_reference) <> ''
  ),
  constraint ord_ret_fin_app_acrep_summary_chk check (
    completion_report_summary is null or btrim(completion_report_summary) <> ''
  ),
  constraint ord_ret_fin_app_acrep_note_chk check (
    completion_report_note is null or btrim(completion_report_note) <> ''
  ),
  constraint ord_ret_fin_app_acrep_hold_note_chk check (
    retention_hold_note is null or btrim(retention_hold_note) <> ''
  ),
  constraint ord_ret_fin_app_acrep_discrepancy_chk check (
    discrepancy_note is null or btrim(discrepancy_note) <> ''
  ),
  constraint ord_ret_fin_app_acrep_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_acrep_failed_reason_chk check (
    status <> 'completion_report_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_acrep_hold_result_chk check (
    completion_report_result <> 'retention_hold' or retention_hold_note is not null
  ),
  constraint ord_ret_fin_app_acrep_discrepancy_result_chk check (
    completion_report_result <> 'discrepancy_found' or discrepancy_note is not null
  ),
  constraint ord_ret_fin_app_acrep_result_status_chk check (
    (
      status in (
        'pending_completion_audit',
        'ready_for_completion_report',
        'completion_report_requested',
        'completion_report_in_progress',
        'completion_report_cancelled'
      )
      and completion_report_result = 'not_reported'
    )
    or (
      status = 'completion_reported'
      and completion_report_result in (
        'reported',
        'reported_with_notes',
        'retention_hold',
        'discrepancy_found',
        'manual_report'
      )
    )
    or (
      status = 'completion_report_failed'
      and completion_report_result in (
        'blocked',
        'needs_completion_audit_update'
      )
    )
  ),
  constraint ord_ret_fin_app_acrep_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_completion_report',
      'completion_report_requested',
      'completion_report_in_progress',
      'completion_reported',
      'completion_report_failed',
      'completion_report_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acrep_requested_status_chk check (
    requested_at is null
    or status in (
      'completion_report_requested',
      'completion_report_in_progress',
      'completion_reported',
      'completion_report_failed',
      'completion_report_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acrep_started_status_chk check (
    started_at is null
    or status in (
      'completion_report_in_progress',
      'completion_reported',
      'completion_report_failed',
      'completion_report_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acrep_reported_status_chk check (
    reported_at is null or status = 'completion_reported'
  ),
  constraint ord_ret_fin_app_acrep_verified_status_chk check (
    verified_at is null or status = 'completion_reported'
  ),
  constraint ord_ret_fin_app_acrep_reviewed_status_chk check (
    reviewed_at is null or status = 'completion_reported'
  ),
  constraint ord_ret_fin_app_acrep_failed_status_chk check (
    failed_at is null or status = 'completion_report_failed'
  ),
  constraint ord_ret_fin_app_acrep_cancelled_status_chk check (
    cancelled_at is null or status = 'completion_report_cancelled'
  ),
  constraint ord_ret_fin_app_acrep_terminal_one_chk check (
    num_nonnulls(reported_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_acrep_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_acrep_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(completion_report_reference);

create unique index ord_ret_fin_app_acrep_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(order_id)
  where status in (
    'pending_completion_audit',
    'ready_for_completion_report',
    'completion_report_requested',
    'completion_report_in_progress',
    'completion_report_failed'
  );

create index ord_ret_fin_app_acrep_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(order_id);

create index ord_ret_fin_app_acrep_acaud_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(completion_audit_record_id);

create index ord_ret_fin_app_acrep_acapp_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(completion_approval_record_id);

create index ord_ret_fin_app_acrep_acrev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(completion_review_record_id);

create index ord_ret_fin_app_acrep_acrel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(completion_release_record_id);

create index ord_ret_fin_app_acrep_acconf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(completion_confirmation_record_id);

create index ord_ret_fin_app_acrep_acfin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(completion_finalization_record_id);

create index ord_ret_fin_app_acrep_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(status);

create index ord_ret_fin_app_acrep_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(completion_report_result);

create index ord_ret_fin_app_acrep_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(ready_at);

create index ord_ret_fin_app_acrep_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(requested_at);

create index ord_ret_fin_app_acrep_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(started_at);

create index ord_ret_fin_app_acrep_reported_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(reported_at);

create index ord_ret_fin_app_acrep_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(verified_at);

create index ord_ret_fin_app_acrep_reviewed_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(reviewed_at);

create index ord_ret_fin_app_acrep_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_events (
  id bigint generated always as identity primary key,
  completion_report_record_id bigint not null,
  order_id bigint not null,
  completion_audit_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_acrep_events_record_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrep_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrep_events_acaud_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acaud_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrep_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_acrep_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_acrep_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_acrep_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_acrep_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_events(completion_report_record_id);

create index ord_ret_fin_app_acrep_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_events(order_id);

create index ord_ret_fin_app_acrep_events_acaud_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_events(completion_audit_record_id);

create index ord_ret_fin_app_acrep_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_events(actor_profile_id);

create index ord_ret_fin_app_acrep_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_events(actor_role);

create index ord_ret_fin_app_acrep_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_events(event_type);

create index ord_ret_fin_app_acrep_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_events(previous_status);

create index ord_ret_fin_app_acrep_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_events(new_status);

create index ord_ret_fin_app_acrep_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_events(created_at);
