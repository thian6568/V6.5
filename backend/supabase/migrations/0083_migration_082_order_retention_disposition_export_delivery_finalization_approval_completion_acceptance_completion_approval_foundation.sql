-- Migration 082 order retention disposition export delivery finalization approval completion acceptance completion approval foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion acceptance completion approval records and completion approval event tracking after completion review.
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
-- - completion approval records are administrative workflow records only; they do not transfer ownership, release funds, mint NFTs, or delete files.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_status as enum (
      'pending_completion_review',
      'ready_for_completion_approval',
      'completion_approval_requested',
      'completion_approval_in_progress',
      'completion_approved',
      'completion_approval_failed',
      'completion_approval_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_result as enum (
      'not_approved',
      'approved',
      'approved_with_notes',
      'retention_hold',
      'discrepancy_found',
      'blocked',
      'needs_completion_review_update',
      'manual_approval'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_event as enum (
      'completion_approval_created',
      'completion_review_attached',
      'completion_approval_ready',
      'completion_approval_requested',
      'completion_approval_started',
      'completion_approval_completed',
      'completion_approval_failed',
      'completion_approval_cancelled',
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_review_record_id bigint not null,
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
  completion_report_record_id bigint,
  completion_audit_record_id bigint,
  completion_closeout_record_id bigint,
  completion_final_record_id bigint,
  completion_confirmation_prior_record_id bigint,
  completion_release_prior_record_id bigint,
  completion_approval_record_id bigint,
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
  approved_by_profile_id bigint,
  verified_by_profile_id bigint,
  reviewed_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_status not null default 'pending_completion_review',
  completion_approval_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_result not null default 'not_approved',
  completion_approval_reference text not null,
  completion_approval_summary text,
  completion_approval_note text,
  retention_hold_note text,
  discrepancy_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  approved_at timestamptz,
  verified_at timestamptz,
  reviewed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_acapp_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_acapp_acrev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_acapp_acrel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrel_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_acconf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_acfin_fk
    foreign key (completion_finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfin_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_asfinal_fk
    foreign key (completion_acceptance_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asfinal_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_asarc_fk
    foreign key (completion_acceptance_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asarc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_asclo_fk
    foreign key (completion_acceptance_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asclo_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_asett_fk
    foreign key (completion_acceptance_settlement_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asett_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_arecon_fk
    foreign key (completion_acceptance_reconciliation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arecon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_aaud_fk
    foreign key (completion_acceptance_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aaud_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_arep_fk
    foreign key (completion_acceptance_reporting_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arep_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_aver_fk
    foreign key (completion_acceptance_verification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aver_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_acert_fk
    foreign key (completion_acceptance_certification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acert_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_acomp_fk
    foreign key (completion_acceptance_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acomp_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_afin_fk
    foreign key (completion_acceptance_finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_aarc_fk
    foreign key (completion_acceptance_archive_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aarc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_aclo_fk
    foreign key (completion_acceptance_closeout_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aclo_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_aconf_fk
    foreign key (completion_acceptance_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aconf_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_arel_fk
    foreign key (completion_acceptance_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arel_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_aapp_fk
    foreign key (completion_acceptance_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aapp_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_arev_fk
    foreign key (completion_acceptance_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arev_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_dacc_fk
    foreign key (completion_delivery_acceptance_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_cdel_fk
    foreign key (completion_confirmed_delivery_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmed_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_cert_fk
    foreign key (completion_certification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_certification_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_verify_fk
    foreign key (completion_verification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_handover_fk
    foreign key (completion_handover_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_archive_fk
    foreign key (completion_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_archive_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_settlement_fk
    foreign key (completion_settlement_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_recon_fk
    foreign key (completion_recon_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_report_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_audit_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_closeout_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_final_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_conf_fk
    foreign key (completion_confirmation_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_rel_fk
    foreign key (completion_release_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_app_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_rev_fk
    foreign key (completion_review_prior_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_approved_by_fk
    foreign key (approved_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_reviewed_by_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_reference_chk check (
    btrim(completion_approval_reference) <> ''
  ),
  constraint ord_ret_fin_app_acapp_summary_chk check (
    completion_approval_summary is null or btrim(completion_approval_summary) <> ''
  ),
  constraint ord_ret_fin_app_acapp_note_chk check (
    completion_approval_note is null or btrim(completion_approval_note) <> ''
  ),
  constraint ord_ret_fin_app_acapp_hold_note_chk check (
    retention_hold_note is null or btrim(retention_hold_note) <> ''
  ),
  constraint ord_ret_fin_app_acapp_discrepancy_chk check (
    discrepancy_note is null or btrim(discrepancy_note) <> ''
  ),
  constraint ord_ret_fin_app_acapp_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_acapp_failed_reason_chk check (
    status <> 'completion_approval_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_acapp_hold_result_chk check (
    completion_approval_result <> 'retention_hold' or retention_hold_note is not null
  ),
  constraint ord_ret_fin_app_acapp_discrepancy_result_chk check (
    completion_approval_result <> 'discrepancy_found' or discrepancy_note is not null
  ),
  constraint ord_ret_fin_app_acapp_result_status_chk check (
    (
      status in (
        'pending_completion_review',
        'ready_for_completion_approval',
        'completion_approval_requested',
        'completion_approval_in_progress',
        'completion_approval_cancelled'
      )
      and completion_approval_result = 'not_approved'
    )
    or (
      status = 'completion_approved'
      and completion_approval_result in (
        'approved',
        'approved_with_notes',
        'retention_hold',
        'discrepancy_found',
        'manual_approval'
      )
    )
    or (
      status = 'completion_approval_failed'
      and completion_approval_result in (
        'blocked',
        'needs_completion_review_update'
      )
    )
  ),
  constraint ord_ret_fin_app_acapp_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_completion_approval',
      'completion_approval_requested',
      'completion_approval_in_progress',
      'completion_approved',
      'completion_approval_failed',
      'completion_approval_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acapp_requested_status_chk check (
    requested_at is null
    or status in (
      'completion_approval_requested',
      'completion_approval_in_progress',
      'completion_approved',
      'completion_approval_failed',
      'completion_approval_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acapp_started_status_chk check (
    started_at is null
    or status in (
      'completion_approval_in_progress',
      'completion_approved',
      'completion_approval_failed',
      'completion_approval_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acapp_approved_status_chk check (
    approved_at is null or status = 'completion_approved'
  ),
  constraint ord_ret_fin_app_acapp_verified_status_chk check (
    verified_at is null or status = 'completion_approved'
  ),
  constraint ord_ret_fin_app_acapp_reviewed_status_chk check (
    reviewed_at is null or status = 'completion_approved'
  ),
  constraint ord_ret_fin_app_acapp_failed_status_chk check (
    failed_at is null or status = 'completion_approval_failed'
  ),
  constraint ord_ret_fin_app_acapp_cancelled_status_chk check (
    cancelled_at is null or status = 'completion_approval_cancelled'
  ),
  constraint ord_ret_fin_app_acapp_terminal_one_chk check (
    num_nonnulls(approved_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_acapp_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_acapp_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(completion_approval_reference);

create unique index ord_ret_fin_app_acapp_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(order_id)
  where status in (
    'pending_completion_review',
    'ready_for_completion_approval',
    'completion_approval_requested',
    'completion_approval_in_progress',
    'completion_approval_failed'
  );

create index ord_ret_fin_app_acapp_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(order_id);

create index ord_ret_fin_app_acapp_acrev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(completion_review_record_id);

create index ord_ret_fin_app_acapp_acrel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(completion_release_record_id);

create index ord_ret_fin_app_acapp_acconf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(completion_confirmation_record_id);

create index ord_ret_fin_app_acapp_acfin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(completion_finalization_record_id);

create index ord_ret_fin_app_acapp_asfinal_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(completion_acceptance_final_record_id);

create index ord_ret_fin_app_acapp_asarc_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(completion_acceptance_archive_record_id);

create index ord_ret_fin_app_acapp_asclo_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(completion_acceptance_closeout_record_id);

create index ord_ret_fin_app_acapp_asett_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(completion_acceptance_settlement_record_id);

create index ord_ret_fin_app_acapp_arecon_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(completion_acceptance_reconciliation_record_id);

create index ord_ret_fin_app_acapp_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(status);

create index ord_ret_fin_app_acapp_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(completion_approval_result);

create index ord_ret_fin_app_acapp_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(ready_at);

create index ord_ret_fin_app_acapp_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(requested_at);

create index ord_ret_fin_app_acapp_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(started_at);

create index ord_ret_fin_app_acapp_approved_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(approved_at);

create index ord_ret_fin_app_acapp_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(verified_at);

create index ord_ret_fin_app_acapp_reviewed_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(reviewed_at);

create index ord_ret_fin_app_acapp_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_events (
  id bigint generated always as identity primary key,
  completion_approval_record_id bigint not null,
  order_id bigint not null,
  completion_review_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_acapp_events_record_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_acapp_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_acapp_events_acrev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acapp_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_acapp_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_acapp_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_acapp_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_acapp_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_events(completion_approval_record_id);

create index ord_ret_fin_app_acapp_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_events(order_id);

create index ord_ret_fin_app_acapp_events_acrev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_events(completion_review_record_id);

create index ord_ret_fin_app_acapp_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_events(actor_profile_id);

create index ord_ret_fin_app_acapp_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_events(actor_role);

create index ord_ret_fin_app_acapp_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_events(event_type);

create index ord_ret_fin_app_acapp_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_events(previous_status);

create index ord_ret_fin_app_acapp_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_events(new_status);

create index ord_ret_fin_app_acapp_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_events(created_at);
