-- Migration 081 order retention disposition export delivery finalization approval completion acceptance completion review foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion acceptance completion review records and completion review event tracking after completion release.
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
-- - completion review records are administrative workflow records only; they do not transfer ownership, release funds, mint NFTs, or delete files.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_status as enum (
      'pending_completion_release',
      'ready_for_completion_review',
      'completion_review_requested',
      'completion_review_in_progress',
      'completion_reviewed',
      'completion_review_failed',
      'completion_review_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_result as enum (
      'not_reviewed',
      'reviewed',
      'reviewed_with_notes',
      'retention_hold',
      'discrepancy_found',
      'blocked',
      'needs_completion_release_update',
      'manual_review'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_event as enum (
      'completion_review_created',
      'completion_release_attached',
      'completion_review_ready',
      'completion_review_requested',
      'completion_review_started',
      'completion_review_completed',
      'completion_review_failed',
      'completion_review_cancelled',
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_release_record_id bigint not null,
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
  completion_report_record_id bigint,
  completion_audit_record_id bigint,
  completion_closeout_record_id bigint,
  completion_final_record_id bigint,
  completion_confirmation_prior_record_id bigint,
  completion_release_prior_record_id bigint,
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
  reviewed_by_profile_id bigint,
  verified_by_profile_id bigint,
  approved_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_status not null default 'pending_completion_release',
  completion_review_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_result not null default 'not_reviewed',
  completion_review_reference text not null,
  completion_review_summary text,
  completion_review_note text,
  retention_hold_note text,
  discrepancy_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  reviewed_at timestamptz,
  verified_at timestamptz,
  approved_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_acrev_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrev_acrel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrel_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrev_acconf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_acfin_fk
    foreign key (completion_finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfin_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_asfinal_fk
    foreign key (completion_acceptance_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asfinal_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_asarc_fk
    foreign key (completion_acceptance_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asarc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_asclo_fk
    foreign key (completion_acceptance_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asclo_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_asett_fk
    foreign key (completion_acceptance_settlement_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asett_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_arecon_fk
    foreign key (completion_acceptance_reconciliation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arecon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_aaud_fk
    foreign key (completion_acceptance_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aaud_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_arep_fk
    foreign key (completion_acceptance_reporting_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arep_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_aver_fk
    foreign key (completion_acceptance_verification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aver_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_acert_fk
    foreign key (completion_acceptance_certification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acert_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_acomp_fk
    foreign key (completion_acceptance_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acomp_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_afin_fk
    foreign key (completion_acceptance_finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_aarc_fk
    foreign key (completion_acceptance_archive_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aarc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_aclo_fk
    foreign key (completion_acceptance_closeout_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aclo_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_aconf_fk
    foreign key (completion_acceptance_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aconf_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_arel_fk
    foreign key (completion_acceptance_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arel_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_aapp_fk
    foreign key (completion_acceptance_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aapp_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_arev_fk
    foreign key (completion_acceptance_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arev_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_dacc_fk
    foreign key (completion_delivery_acceptance_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_cdel_fk
    foreign key (completion_confirmed_delivery_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmed_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_cert_fk
    foreign key (completion_certification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_certification_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_verify_fk
    foreign key (completion_verification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_handover_fk
    foreign key (completion_handover_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_archive_fk
    foreign key (completion_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_archive_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_settlement_fk
    foreign key (completion_settlement_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_recon_fk
    foreign key (completion_recon_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_report_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_audit_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_closeout_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_final_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_conf_fk
    foreign key (completion_confirmation_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_rel_fk
    foreign key (completion_release_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_app_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_rev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_reviewed_by_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_approved_by_fk
    foreign key (approved_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_reference_chk check (
    btrim(completion_review_reference) <> ''
  ),
  constraint ord_ret_fin_app_acrev_summary_chk check (
    completion_review_summary is null or btrim(completion_review_summary) <> ''
  ),
  constraint ord_ret_fin_app_acrev_note_chk check (
    completion_review_note is null or btrim(completion_review_note) <> ''
  ),
  constraint ord_ret_fin_app_acrev_hold_note_chk check (
    retention_hold_note is null or btrim(retention_hold_note) <> ''
  ),
  constraint ord_ret_fin_app_acrev_discrepancy_chk check (
    discrepancy_note is null or btrim(discrepancy_note) <> ''
  ),
  constraint ord_ret_fin_app_acrev_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_acrev_failed_reason_chk check (
    status <> 'completion_review_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_acrev_hold_result_chk check (
    completion_review_result <> 'retention_hold' or retention_hold_note is not null
  ),
  constraint ord_ret_fin_app_acrev_discrepancy_result_chk check (
    completion_review_result <> 'discrepancy_found' or discrepancy_note is not null
  ),
  constraint ord_ret_fin_app_acrev_result_status_chk check (
    (
      status in (
        'pending_completion_release',
        'ready_for_completion_review',
        'completion_review_requested',
        'completion_review_in_progress',
        'completion_review_cancelled'
      )
      and completion_review_result = 'not_reviewed'
    )
    or (
      status = 'completion_reviewed'
      and completion_review_result in (
        'reviewed',
        'reviewed_with_notes',
        'retention_hold',
        'discrepancy_found',
        'manual_review'
      )
    )
    or (
      status = 'completion_review_failed'
      and completion_review_result in (
        'blocked',
        'needs_completion_release_update'
      )
    )
  ),
  constraint ord_ret_fin_app_acrev_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_completion_review',
      'completion_review_requested',
      'completion_review_in_progress',
      'completion_reviewed',
      'completion_review_failed',
      'completion_review_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acrev_requested_status_chk check (
    requested_at is null
    or status in (
      'completion_review_requested',
      'completion_review_in_progress',
      'completion_reviewed',
      'completion_review_failed',
      'completion_review_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acrev_started_status_chk check (
    started_at is null
    or status in (
      'completion_review_in_progress',
      'completion_reviewed',
      'completion_review_failed',
      'completion_review_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acrev_reviewed_status_chk check (
    reviewed_at is null or status = 'completion_reviewed'
  ),
  constraint ord_ret_fin_app_acrev_verified_status_chk check (
    verified_at is null or status = 'completion_reviewed'
  ),
  constraint ord_ret_fin_app_acrev_approved_status_chk check (
    approved_at is null or status = 'completion_reviewed'
  ),
  constraint ord_ret_fin_app_acrev_failed_status_chk check (
    failed_at is null or status = 'completion_review_failed'
  ),
  constraint ord_ret_fin_app_acrev_cancelled_status_chk check (
    cancelled_at is null or status = 'completion_review_cancelled'
  ),
  constraint ord_ret_fin_app_acrev_terminal_one_chk check (
    num_nonnulls(reviewed_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_acrev_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_acrev_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_review_reference);

create unique index ord_ret_fin_app_acrev_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(order_id)
  where status in (
    'pending_completion_release',
    'ready_for_completion_review',
    'completion_review_requested',
    'completion_review_in_progress',
    'completion_review_failed'
  );

create index ord_ret_fin_app_acrev_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(order_id);

create index ord_ret_fin_app_acrev_acrel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_release_record_id);

create index ord_ret_fin_app_acrev_acconf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_confirmation_record_id);

create index ord_ret_fin_app_acrev_acfin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_finalization_record_id);

create index ord_ret_fin_app_acrev_asfinal_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_final_record_id);

create index ord_ret_fin_app_acrev_asarc_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_archive_record_id);

create index ord_ret_fin_app_acrev_asclo_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_closeout_record_id);

create index ord_ret_fin_app_acrev_asett_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_settlement_record_id);

create index ord_ret_fin_app_acrev_arecon_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_reconciliation_record_id);

create index ord_ret_fin_app_acrev_aaud_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_audit_record_id);

create index ord_ret_fin_app_acrev_arep_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_reporting_record_id);

create index ord_ret_fin_app_acrev_aver_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_verification_record_id);

create index ord_ret_fin_app_acrev_acert_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_certification_record_id);

create index ord_ret_fin_app_acrev_acomp_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_completion_record_id);

create index ord_ret_fin_app_acrev_afin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_finalization_record_id);

create index ord_ret_fin_app_acrev_aarc_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_archive_prior_record_id);

create index ord_ret_fin_app_acrev_aclo_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_closeout_prior_record_id);

create index ord_ret_fin_app_acrev_aconf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_confirmation_record_id);

create index ord_ret_fin_app_acrev_arel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_release_record_id);

create index ord_ret_fin_app_acrev_aapp_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_approval_record_id);

create index ord_ret_fin_app_acrev_arev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_acceptance_review_record_id);

create index ord_ret_fin_app_acrev_dacc_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_delivery_acceptance_record_id);

create index ord_ret_fin_app_acrev_cdel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_confirmed_delivery_record_id);

create index ord_ret_fin_app_acrev_cert_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_certification_record_id);

create index ord_ret_fin_app_acrev_verify_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_verification_record_id);

create index ord_ret_fin_app_acrev_handover_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_handover_record_id);

create index ord_ret_fin_app_acrev_archive_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_archive_record_id);

create index ord_ret_fin_app_acrev_settlement_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_settlement_record_id);

create index ord_ret_fin_app_acrev_recon_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_recon_record_id);

create index ord_ret_fin_app_acrev_report_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_report_record_id);

create index ord_ret_fin_app_acrev_audit_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_audit_record_id);

create index ord_ret_fin_app_acrev_closeout_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_closeout_record_id);

create index ord_ret_fin_app_acrev_final_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_final_record_id);

create index ord_ret_fin_app_acrev_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_confirmation_prior_record_id);

create index ord_ret_fin_app_acrev_rel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_release_prior_record_id);

create index ord_ret_fin_app_acrev_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_approval_record_id);

create index ord_ret_fin_app_acrev_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_review_record_id);

create index ord_ret_fin_app_acrev_completion_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(approval_completion_record_id);

create index ord_ret_fin_app_acrev_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(approval_confirmation_record_id);

create index ord_ret_fin_app_acrev_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(approval_release_record_id);

create index ord_ret_fin_app_acrev_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(finalization_approval_record_id);

create index ord_ret_fin_app_acrev_fin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(finalization_review_record_id);

create index ord_ret_fin_app_acrev_fin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(finalization_record_id);

create index ord_ret_fin_app_acrev_rel_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(review_release_confirmation_record_id);

create index ord_ret_fin_app_acrev_review_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(review_release_record_id);

create index ord_ret_fin_app_acrev_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(approval_record_id);

create index ord_ret_fin_app_acrev_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(review_record_id);

create index ord_ret_fin_app_acrev_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(delivery_record_id);

create index ord_ret_fin_app_acrev_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(export_record_id);

create index ord_ret_fin_app_acrev_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(evidence_record_id);

create index ord_ret_fin_app_acrev_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(requested_by_profile_id);

create index ord_ret_fin_app_acrev_reviewed_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(reviewed_by_profile_id);

create index ord_ret_fin_app_acrev_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(verified_by_profile_id);

create index ord_ret_fin_app_acrev_approved_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(approved_by_profile_id);

create index ord_ret_fin_app_acrev_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(status);

create index ord_ret_fin_app_acrev_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(completion_review_result);

create index ord_ret_fin_app_acrev_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(ready_at);

create index ord_ret_fin_app_acrev_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(requested_at);

create index ord_ret_fin_app_acrev_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(started_at);

create index ord_ret_fin_app_acrev_reviewed_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(reviewed_at);

create index ord_ret_fin_app_acrev_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(verified_at);

create index ord_ret_fin_app_acrev_approved_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(approved_at);

create index ord_ret_fin_app_acrev_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_events (
  id bigint generated always as identity primary key,
  completion_review_record_id bigint not null,
  order_id bigint not null,
  completion_release_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_acrev_events_record_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrev_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrev_events_acrel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrel_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrev_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_acrev_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_acrev_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_acrev_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_acrev_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_events(completion_review_record_id);

create index ord_ret_fin_app_acrev_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_events(order_id);

create index ord_ret_fin_app_acrev_events_acrel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_events(completion_release_record_id);

create index ord_ret_fin_app_acrev_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_events(actor_profile_id);

create index ord_ret_fin_app_acrev_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_events(actor_role);

create index ord_ret_fin_app_acrev_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_events(event_type);

create index ord_ret_fin_app_acrev_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_events(previous_status);

create index ord_ret_fin_app_acrev_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_events(new_status);

create index ord_ret_fin_app_acrev_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_events(created_at);
