-- Migration 079 order retention disposition export delivery finalization approval completion acceptance completion confirmation foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion acceptance completion confirmation records and completion confirmation event tracking after completion finalization.
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
-- - completion confirmation records are administrative workflow records only; they do not transfer ownership, release funds, mint NFTs, or delete files.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_status as enum (
      'pending_completion_finalization',
      'ready_for_completion_confirmation',
      'completion_confirmation_requested',
      'completion_confirmation_in_progress',
      'completion_confirmed',
      'completion_confirmation_failed',
      'completion_confirmation_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_result as enum (
      'not_confirmed',
      'confirmed',
      'confirmed_with_notes',
      'retention_hold',
      'discrepancy_found',
      'blocked',
      'needs_completion_finalization_update',
      'manual_confirmation'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_event as enum (
      'completion_confirmation_created',
      'completion_finalization_attached',
      'completion_confirmation_ready',
      'completion_confirmation_requested',
      'completion_confirmation_started',
      'completion_confirmation_completed',
      'completion_confirmation_failed',
      'completion_confirmation_cancelled',
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_finalization_record_id bigint not null,
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
  confirmed_by_profile_id bigint,
  verified_by_profile_id bigint,
  reviewed_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_status not null default 'pending_completion_finalization',
  completion_confirmation_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_result not null default 'not_confirmed',
  completion_confirmation_reference text not null,
  completion_confirmation_summary text,
  completion_confirmation_note text,
  retention_hold_note text,
  discrepancy_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  confirmed_at timestamptz,
  verified_at timestamptz,
  reviewed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_acconf_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_acconf_acfin_fk
    foreign key (completion_finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfin_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_acconf_asfinal_fk
    foreign key (completion_acceptance_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asfinal_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_asarc_fk
    foreign key (completion_acceptance_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asarc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_asclo_fk
    foreign key (completion_acceptance_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asclo_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_asett_fk
    foreign key (completion_acceptance_settlement_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asett_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_arecon_fk
    foreign key (completion_acceptance_reconciliation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arecon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_aaud_fk
    foreign key (completion_acceptance_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aaud_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_arep_fk
    foreign key (completion_acceptance_reporting_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arep_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_aver_fk
    foreign key (completion_acceptance_verification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aver_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_acert_fk
    foreign key (completion_acceptance_certification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acert_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_acomp_fk
    foreign key (completion_acceptance_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acomp_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_afin_fk
    foreign key (completion_acceptance_finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_aarc_fk
    foreign key (completion_acceptance_archive_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aarc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_aclo_fk
    foreign key (completion_acceptance_closeout_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aclo_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_aconf_fk
    foreign key (completion_acceptance_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aconf_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_arel_fk
    foreign key (completion_acceptance_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arel_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_aapp_fk
    foreign key (completion_acceptance_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aapp_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_arev_fk
    foreign key (completion_acceptance_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arev_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_dacc_fk
    foreign key (completion_delivery_acceptance_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_cdel_fk
    foreign key (completion_confirmed_delivery_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmed_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_cert_fk
    foreign key (completion_certification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_certification_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_verify_fk
    foreign key (completion_verification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_handover_fk
    foreign key (completion_handover_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_archive_fk
    foreign key (completion_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_archive_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_settlement_fk
    foreign key (completion_settlement_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_recon_fk
    foreign key (completion_recon_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_report_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_audit_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_closeout_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_final_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_conf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_rel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_app_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_rev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_confirmed_by_fk
    foreign key (confirmed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_reviewed_by_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_reference_chk check (
    btrim(completion_confirmation_reference) <> ''
  ),
  constraint ord_ret_fin_app_acconf_summary_chk check (
    completion_confirmation_summary is null or btrim(completion_confirmation_summary) <> ''
  ),
  constraint ord_ret_fin_app_acconf_note_chk check (
    completion_confirmation_note is null or btrim(completion_confirmation_note) <> ''
  ),
  constraint ord_ret_fin_app_acconf_hold_note_chk check (
    retention_hold_note is null or btrim(retention_hold_note) <> ''
  ),
  constraint ord_ret_fin_app_acconf_discrepancy_chk check (
    discrepancy_note is null or btrim(discrepancy_note) <> ''
  ),
  constraint ord_ret_fin_app_acconf_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_acconf_failed_reason_chk check (
    status <> 'completion_confirmation_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_acconf_hold_result_chk check (
    completion_confirmation_result <> 'retention_hold' or retention_hold_note is not null
  ),
  constraint ord_ret_fin_app_acconf_discrepancy_result_chk check (
    completion_confirmation_result <> 'discrepancy_found' or discrepancy_note is not null
  ),
  constraint ord_ret_fin_app_acconf_result_status_chk check (
    (
      status in (
        'pending_completion_finalization',
        'ready_for_completion_confirmation',
        'completion_confirmation_requested',
        'completion_confirmation_in_progress',
        'completion_confirmation_cancelled'
      )
      and completion_confirmation_result = 'not_confirmed'
    )
    or (
      status = 'completion_confirmed'
      and completion_confirmation_result in (
        'confirmed',
        'confirmed_with_notes',
        'retention_hold',
        'discrepancy_found',
        'manual_confirmation'
      )
    )
    or (
      status = 'completion_confirmation_failed'
      and completion_confirmation_result in (
        'blocked',
        'needs_completion_finalization_update'
      )
    )
  ),
  constraint ord_ret_fin_app_acconf_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_completion_confirmation',
      'completion_confirmation_requested',
      'completion_confirmation_in_progress',
      'completion_confirmed',
      'completion_confirmation_failed',
      'completion_confirmation_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acconf_requested_status_chk check (
    requested_at is null
    or status in (
      'completion_confirmation_requested',
      'completion_confirmation_in_progress',
      'completion_confirmed',
      'completion_confirmation_failed',
      'completion_confirmation_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acconf_started_status_chk check (
    started_at is null
    or status in (
      'completion_confirmation_in_progress',
      'completion_confirmed',
      'completion_confirmation_failed',
      'completion_confirmation_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acconf_confirmed_status_chk check (
    confirmed_at is null or status = 'completion_confirmed'
  ),
  constraint ord_ret_fin_app_acconf_verified_status_chk check (
    verified_at is null or status = 'completion_confirmed'
  ),
  constraint ord_ret_fin_app_acconf_reviewed_status_chk check (
    reviewed_at is null or status = 'completion_confirmed'
  ),
  constraint ord_ret_fin_app_acconf_failed_status_chk check (
    failed_at is null or status = 'completion_confirmation_failed'
  ),
  constraint ord_ret_fin_app_acconf_cancelled_status_chk check (
    cancelled_at is null or status = 'completion_confirmation_cancelled'
  ),
  constraint ord_ret_fin_app_acconf_terminal_one_chk check (
    num_nonnulls(confirmed_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_acconf_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_acconf_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_confirmation_reference);

create unique index ord_ret_fin_app_acconf_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(order_id)
  where status in (
    'pending_completion_finalization',
    'ready_for_completion_confirmation',
    'completion_confirmation_requested',
    'completion_confirmation_in_progress',
    'completion_confirmation_failed'
  );

create index ord_ret_fin_app_acconf_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(order_id);

create index ord_ret_fin_app_acconf_acfin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_finalization_record_id);

create index ord_ret_fin_app_acconf_asfinal_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_final_record_id);

create index ord_ret_fin_app_acconf_asarc_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_archive_record_id);

create index ord_ret_fin_app_acconf_asclo_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_closeout_record_id);

create index ord_ret_fin_app_acconf_asett_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_settlement_record_id);

create index ord_ret_fin_app_acconf_arecon_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_reconciliation_record_id);

create index ord_ret_fin_app_acconf_aaud_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_audit_record_id);

create index ord_ret_fin_app_acconf_arep_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_reporting_record_id);

create index ord_ret_fin_app_acconf_aver_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_verification_record_id);

create index ord_ret_fin_app_acconf_acert_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_certification_record_id);

create index ord_ret_fin_app_acconf_acomp_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_completion_record_id);

create index ord_ret_fin_app_acconf_afin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_finalization_record_id);

create index ord_ret_fin_app_acconf_aarc_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_archive_prior_record_id);

create index ord_ret_fin_app_acconf_aclo_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_closeout_prior_record_id);

create index ord_ret_fin_app_acconf_aconf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_confirmation_record_id);

create index ord_ret_fin_app_acconf_arel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_release_record_id);

create index ord_ret_fin_app_acconf_aapp_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_approval_record_id);

create index ord_ret_fin_app_acconf_arev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_acceptance_review_record_id);

create index ord_ret_fin_app_acconf_dacc_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_delivery_acceptance_record_id);

create index ord_ret_fin_app_acconf_cdel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_confirmed_delivery_record_id);

create index ord_ret_fin_app_acconf_cert_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_certification_record_id);

create index ord_ret_fin_app_acconf_verify_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_verification_record_id);

create index ord_ret_fin_app_acconf_handover_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_handover_record_id);

create index ord_ret_fin_app_acconf_archive_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_archive_record_id);

create index ord_ret_fin_app_acconf_settlement_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_settlement_record_id);

create index ord_ret_fin_app_acconf_recon_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_recon_record_id);

create index ord_ret_fin_app_acconf_report_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_report_record_id);

create index ord_ret_fin_app_acconf_audit_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_audit_record_id);

create index ord_ret_fin_app_acconf_closeout_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_closeout_record_id);

create index ord_ret_fin_app_acconf_final_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_final_record_id);

create index ord_ret_fin_app_acconf_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_confirmation_record_id);

create index ord_ret_fin_app_acconf_rel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_release_record_id);

create index ord_ret_fin_app_acconf_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_approval_record_id);

create index ord_ret_fin_app_acconf_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_review_record_id);

create index ord_ret_fin_app_acconf_completion_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(approval_completion_record_id);

create index ord_ret_fin_app_acconf_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(approval_confirmation_record_id);

create index ord_ret_fin_app_acconf_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(approval_release_record_id);

create index ord_ret_fin_app_acconf_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(finalization_approval_record_id);

create index ord_ret_fin_app_acconf_fin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(finalization_review_record_id);

create index ord_ret_fin_app_acconf_fin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(finalization_record_id);

create index ord_ret_fin_app_acconf_rel_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(review_release_confirmation_record_id);

create index ord_ret_fin_app_acconf_review_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(review_release_record_id);

create index ord_ret_fin_app_acconf_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(approval_record_id);

create index ord_ret_fin_app_acconf_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(review_record_id);

create index ord_ret_fin_app_acconf_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(delivery_record_id);

create index ord_ret_fin_app_acconf_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(export_record_id);

create index ord_ret_fin_app_acconf_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(evidence_record_id);

create index ord_ret_fin_app_acconf_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(requested_by_profile_id);

create index ord_ret_fin_app_acconf_confirmed_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(confirmed_by_profile_id);

create index ord_ret_fin_app_acconf_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(verified_by_profile_id);

create index ord_ret_fin_app_acconf_reviewed_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(reviewed_by_profile_id);

create index ord_ret_fin_app_acconf_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(status);

create index ord_ret_fin_app_acconf_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(completion_confirmation_result);

create index ord_ret_fin_app_acconf_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(ready_at);

create index ord_ret_fin_app_acconf_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(requested_at);

create index ord_ret_fin_app_acconf_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(started_at);

create index ord_ret_fin_app_acconf_confirmed_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(confirmed_at);

create index ord_ret_fin_app_acconf_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(verified_at);

create index ord_ret_fin_app_acconf_reviewed_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(reviewed_at);

create index ord_ret_fin_app_acconf_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_events (
  id bigint generated always as identity primary key,
  completion_confirmation_record_id bigint not null,
  order_id bigint not null,
  completion_finalization_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_acconf_events_record_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_acconf_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_acconf_events_acfin_fk
    foreign key (completion_finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfin_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acconf_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_acconf_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_acconf_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_acconf_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_acconf_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_events(completion_confirmation_record_id);

create index ord_ret_fin_app_acconf_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_events(order_id);

create index ord_ret_fin_app_acconf_events_acfin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_events(completion_finalization_record_id);

create index ord_ret_fin_app_acconf_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_events(actor_profile_id);

create index ord_ret_fin_app_acconf_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_events(actor_role);

create index ord_ret_fin_app_acconf_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_events(event_type);

create index ord_ret_fin_app_acconf_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_events(previous_status);

create index ord_ret_fin_app_acconf_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_events(new_status);

create index ord_ret_fin_app_acconf_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_events(created_at);
