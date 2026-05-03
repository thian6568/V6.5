-- Migration 067 order retention disposition export delivery finalization approval completion acceptance finalization foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion acceptance finalization records and acceptance finalization event tracking after finalization approval completion acceptance archive.
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
-- - acceptance finalization records are administrative workflow records only; they do not transfer ownership, release funds, mint NFTs, or delete files.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_afin_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_status as enum (
      'pending_acceptance_archive',
      'ready_for_acceptance_finalization',
      'acceptance_finalization_requested',
      'acceptance_finalization_in_progress',
      'acceptance_finalized',
      'acceptance_finalization_failed',
      'acceptance_finalization_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_afin_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_result as enum (
      'not_finalized',
      'finalized',
      'finalized_with_notes',
      'retention_hold',
      'discrepancy_found',
      'blocked',
      'needs_acceptance_archive_update',
      'manual_finalization'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_afin_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_event as enum (
      'acceptance_finalization_created',
      'acceptance_archive_attached',
      'acceptance_finalization_ready',
      'acceptance_finalization_requested',
      'acceptance_finalization_started',
      'acceptance_finalization_completed',
      'acceptance_finalization_failed',
      'acceptance_finalization_cancelled',
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_afin_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_acceptance_archive_record_id bigint not null,
  completion_acceptance_closeout_record_id bigint,
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
  finalized_by_profile_id bigint,
  verified_by_profile_id bigint,
  reviewed_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_status not null default 'pending_acceptance_archive',
  acceptance_finalization_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_result not null default 'not_finalized',
  acceptance_finalization_reference text not null,
  acceptance_finalization_summary text,
  acceptance_finalization_note text,
  retention_hold_note text,
  discrepancy_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  finalized_at timestamptz,
  verified_at timestamptz,
  reviewed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_afin_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_afin_aarc_fk
    foreign key (completion_acceptance_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aarc_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_afin_aclo_fk
    foreign key (completion_acceptance_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aclo_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_aconf_fk
    foreign key (completion_acceptance_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aconf_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_arel_fk
    foreign key (completion_acceptance_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arel_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_aapp_fk
    foreign key (completion_acceptance_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aapp_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_arev_fk
    foreign key (completion_acceptance_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_arev_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_dacc_fk
    foreign key (completion_delivery_acceptance_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_dacc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_cdel_fk
    foreign key (completion_confirmed_delivery_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmed_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_cert_fk
    foreign key (completion_certification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_certification_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_verify_fk
    foreign key (completion_verification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_verification_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_handover_fk
    foreign key (completion_handover_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_archive_fk
    foreign key (completion_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_archive_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_settlement_fk
    foreign key (completion_settlement_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_recon_fk
    foreign key (completion_recon_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_report_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_audit_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_closeout_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_final_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_conf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_rel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_app_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_rev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_finalized_by_fk
    foreign key (finalized_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_reviewed_by_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_reference_chk check (
    btrim(acceptance_finalization_reference) <> ''
  ),
  constraint ord_ret_fin_app_afin_summary_chk check (
    acceptance_finalization_summary is null or btrim(acceptance_finalization_summary) <> ''
  ),
  constraint ord_ret_fin_app_afin_note_chk check (
    acceptance_finalization_note is null or btrim(acceptance_finalization_note) <> ''
  ),
  constraint ord_ret_fin_app_afin_hold_note_chk check (
    retention_hold_note is null or btrim(retention_hold_note) <> ''
  ),
  constraint ord_ret_fin_app_afin_discrepancy_chk check (
    discrepancy_note is null or btrim(discrepancy_note) <> ''
  ),
  constraint ord_ret_fin_app_afin_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_afin_failed_reason_chk check (
    status <> 'acceptance_finalization_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_afin_hold_result_chk check (
    acceptance_finalization_result <> 'retention_hold' or retention_hold_note is not null
  ),
  constraint ord_ret_fin_app_afin_discrepancy_result_chk check (
    acceptance_finalization_result <> 'discrepancy_found' or discrepancy_note is not null
  ),
  constraint ord_ret_fin_app_afin_result_status_chk check (
    (
      status in (
        'pending_acceptance_archive',
        'ready_for_acceptance_finalization',
        'acceptance_finalization_requested',
        'acceptance_finalization_in_progress',
        'acceptance_finalization_cancelled'
      )
      and acceptance_finalization_result = 'not_finalized'
    )
    or (
      status = 'acceptance_finalized'
      and acceptance_finalization_result in (
        'finalized',
        'finalized_with_notes',
        'retention_hold',
        'discrepancy_found',
        'manual_finalization'
      )
    )
    or (
      status = 'acceptance_finalization_failed'
      and acceptance_finalization_result in (
        'blocked',
        'needs_acceptance_archive_update'
      )
    )
  ),
  constraint ord_ret_fin_app_afin_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_acceptance_finalization',
      'acceptance_finalization_requested',
      'acceptance_finalization_in_progress',
      'acceptance_finalized',
      'acceptance_finalization_failed',
      'acceptance_finalization_cancelled'
    )
  ),
  constraint ord_ret_fin_app_afin_requested_status_chk check (
    requested_at is null
    or status in (
      'acceptance_finalization_requested',
      'acceptance_finalization_in_progress',
      'acceptance_finalized',
      'acceptance_finalization_failed',
      'acceptance_finalization_cancelled'
    )
  ),
  constraint ord_ret_fin_app_afin_started_status_chk check (
    started_at is null
    or status in (
      'acceptance_finalization_in_progress',
      'acceptance_finalized',
      'acceptance_finalization_failed',
      'acceptance_finalization_cancelled'
    )
  ),
  constraint ord_ret_fin_app_afin_finalized_status_chk check (
    finalized_at is null or status = 'acceptance_finalized'
  ),
  constraint ord_ret_fin_app_afin_verified_status_chk check (
    verified_at is null or status = 'acceptance_finalized'
  ),
  constraint ord_ret_fin_app_afin_reviewed_status_chk check (
    reviewed_at is null or status = 'acceptance_finalized'
  ),
  constraint ord_ret_fin_app_afin_failed_status_chk check (
    failed_at is null or status = 'acceptance_finalization_failed'
  ),
  constraint ord_ret_fin_app_afin_cancelled_status_chk check (
    cancelled_at is null or status = 'acceptance_finalization_cancelled'
  ),
  constraint ord_ret_fin_app_afin_terminal_one_chk check (
    num_nonnulls(finalized_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_afin_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_afin_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(acceptance_finalization_reference);

create unique index ord_ret_fin_app_afin_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(order_id)
  where status in (
    'pending_acceptance_archive',
    'ready_for_acceptance_finalization',
    'acceptance_finalization_requested',
    'acceptance_finalization_in_progress',
    'acceptance_finalization_failed'
  );

create index ord_ret_fin_app_afin_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(order_id);

create index ord_ret_fin_app_afin_aarc_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_acceptance_archive_record_id);

create index ord_ret_fin_app_afin_aclo_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_acceptance_closeout_record_id);

create index ord_ret_fin_app_afin_aconf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_acceptance_confirmation_record_id);

create index ord_ret_fin_app_afin_arel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_acceptance_release_record_id);

create index ord_ret_fin_app_afin_aapp_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_acceptance_approval_record_id);

create index ord_ret_fin_app_afin_arev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_acceptance_review_record_id);

create index ord_ret_fin_app_afin_dacc_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_delivery_acceptance_record_id);

create index ord_ret_fin_app_afin_cdel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_confirmed_delivery_record_id);

create index ord_ret_fin_app_afin_cert_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_certification_record_id);

create index ord_ret_fin_app_afin_verify_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_verification_record_id);

create index ord_ret_fin_app_afin_handover_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_handover_record_id);

create index ord_ret_fin_app_afin_archive_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_archive_record_id);

create index ord_ret_fin_app_afin_settlement_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_settlement_record_id);

create index ord_ret_fin_app_afin_recon_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_recon_record_id);

create index ord_ret_fin_app_afin_report_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_report_record_id);

create index ord_ret_fin_app_afin_audit_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_audit_record_id);

create index ord_ret_fin_app_afin_closeout_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_closeout_record_id);

create index ord_ret_fin_app_afin_final_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_final_record_id);

create index ord_ret_fin_app_afin_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_confirmation_record_id);

create index ord_ret_fin_app_afin_rel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_release_record_id);

create index ord_ret_fin_app_afin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_approval_record_id);

create index ord_ret_fin_app_afin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(completion_review_record_id);

create index ord_ret_fin_app_afin_completion_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(approval_completion_record_id);

create index ord_ret_fin_app_afin_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(approval_confirmation_record_id);

create index ord_ret_fin_app_afin_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(approval_release_record_id);

create index ord_ret_fin_app_afin_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(finalization_approval_record_id);

create index ord_ret_fin_app_afin_fin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(finalization_review_record_id);

create index ord_ret_fin_app_afin_fin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(finalization_record_id);

create index ord_ret_fin_app_afin_rel_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(review_release_confirmation_record_id);

create index ord_ret_fin_app_afin_review_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(review_release_record_id);

create index ord_ret_fin_app_afin_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(approval_record_id);

create index ord_ret_fin_app_afin_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(review_record_id);

create index ord_ret_fin_app_afin_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(delivery_record_id);

create index ord_ret_fin_app_afin_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(export_record_id);

create index ord_ret_fin_app_afin_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(evidence_record_id);

create index ord_ret_fin_app_afin_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(requested_by_profile_id);

create index ord_ret_fin_app_afin_finalized_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(finalized_by_profile_id);

create index ord_ret_fin_app_afin_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(verified_by_profile_id);

create index ord_ret_fin_app_afin_reviewed_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(reviewed_by_profile_id);

create index ord_ret_fin_app_afin_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(status);

create index ord_ret_fin_app_afin_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(acceptance_finalization_result);

create index ord_ret_fin_app_afin_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(ready_at);

create index ord_ret_fin_app_afin_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(requested_at);

create index ord_ret_fin_app_afin_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(started_at);

create index ord_ret_fin_app_afin_finalized_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(finalized_at);

create index ord_ret_fin_app_afin_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(verified_at);

create index ord_ret_fin_app_afin_reviewed_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(reviewed_at);

create index ord_ret_fin_app_afin_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_events (
  id bigint generated always as identity primary key,
  completion_acceptance_finalization_record_id bigint not null,
  order_id bigint not null,
  completion_acceptance_archive_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_afin_events_record_fk
    foreign key (completion_acceptance_finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_afin_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_afin_events_aarc_fk
    foreign key (completion_acceptance_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_aarc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_afin_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_afin_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_afin_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_afin_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_afin_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_events(completion_acceptance_finalization_record_id);

create index ord_ret_fin_app_afin_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_events(order_id);

create index ord_ret_fin_app_afin_events_aarc_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_events(completion_acceptance_archive_record_id);

create index ord_ret_fin_app_afin_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_events(actor_profile_id);

create index ord_ret_fin_app_afin_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_events(actor_role);

create index ord_ret_fin_app_afin_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_events(event_type);

create index ord_ret_fin_app_afin_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_events(previous_status);

create index ord_ret_fin_app_afin_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_events(new_status);

create index ord_ret_fin_app_afin_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_afin_events(created_at);
