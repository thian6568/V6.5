-- Migration 053 order retention disposition export delivery finalization approval completion reconciliation foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion reconciliation records and reconciliation event tracking after finalization approval completion reporting.
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_recon_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_status as enum (
      'pending_reporting',
      'ready_for_reconciliation',
      'reconciliation_requested',
      'reconciliation_in_progress',
      'reconciled',
      'reconciliation_failed',
      'reconciliation_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_recon_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_result as enum (
      'not_reconciled',
      'reconciled',
      'reconciled_with_notes',
      'discrepancy_found',
      'blocked',
      'needs_reporting_update',
      'manual_reconciliation'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_recon_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_event as enum (
      'reconciliation_created',
      'reporting_attached',
      'reconciliation_ready',
      'reconciliation_requested',
      'reconciliation_started',
      'reconciliation_completed',
      'reconciliation_failed',
      'reconciliation_cancelled',
      'discrepancy_recorded',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_recon_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_report_record_id bigint not null,
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
  reconciled_by_profile_id bigint,
  verified_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_status not null default 'pending_reporting',
  reconciliation_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_result not null default 'not_reconciled',
  reconciliation_reference text not null,
  reconciliation_summary text,
  reconciliation_note text,
  discrepancy_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  reconciled_at timestamptz,
  verified_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_recon_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_recon_report_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_recon_audit_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_closeout_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_final_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_conf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_rel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_app_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_rev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_reconciled_by_fk
    foreign key (reconciled_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_reference_chk check (
    btrim(reconciliation_reference) <> ''
  ),
  constraint ord_ret_fin_app_recon_summary_chk check (
    reconciliation_summary is null or btrim(reconciliation_summary) <> ''
  ),
  constraint ord_ret_fin_app_recon_note_chk check (
    reconciliation_note is null or btrim(reconciliation_note) <> ''
  ),
  constraint ord_ret_fin_app_recon_discrepancy_chk check (
    discrepancy_note is null or btrim(discrepancy_note) <> ''
  ),
  constraint ord_ret_fin_app_recon_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_recon_failed_reason_chk check (
    status <> 'reconciliation_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_recon_discrepancy_result_chk check (
    reconciliation_result <> 'discrepancy_found' or discrepancy_note is not null
  ),
  constraint ord_ret_fin_app_recon_result_status_chk check (
    (
      status in (
        'pending_reporting',
        'ready_for_reconciliation',
        'reconciliation_requested',
        'reconciliation_in_progress',
        'reconciliation_cancelled'
      )
      and reconciliation_result = 'not_reconciled'
    )
    or (
      status = 'reconciled'
      and reconciliation_result in (
        'reconciled',
        'reconciled_with_notes',
        'discrepancy_found',
        'manual_reconciliation'
      )
    )
    or (
      status = 'reconciliation_failed'
      and reconciliation_result in (
        'blocked',
        'needs_reporting_update'
      )
    )
  ),
  constraint ord_ret_fin_app_recon_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_reconciliation',
      'reconciliation_requested',
      'reconciliation_in_progress',
      'reconciled',
      'reconciliation_failed',
      'reconciliation_cancelled'
    )
  ),
  constraint ord_ret_fin_app_recon_requested_status_chk check (
    requested_at is null
    or status in (
      'reconciliation_requested',
      'reconciliation_in_progress',
      'reconciled',
      'reconciliation_failed',
      'reconciliation_cancelled'
    )
  ),
  constraint ord_ret_fin_app_recon_started_status_chk check (
    started_at is null
    or status in (
      'reconciliation_in_progress',
      'reconciled',
      'reconciliation_failed',
      'reconciliation_cancelled'
    )
  ),
  constraint ord_ret_fin_app_recon_reconciled_status_chk check (
    reconciled_at is null or status = 'reconciled'
  ),
  constraint ord_ret_fin_app_recon_verified_status_chk check (
    verified_at is null or status = 'reconciled'
  ),
  constraint ord_ret_fin_app_recon_failed_status_chk check (
    failed_at is null or status = 'reconciliation_failed'
  ),
  constraint ord_ret_fin_app_recon_cancelled_status_chk check (
    cancelled_at is null or status = 'reconciliation_cancelled'
  ),
  constraint ord_ret_fin_app_recon_terminal_one_chk check (
    num_nonnulls(reconciled_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_recon_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_recon_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(reconciliation_reference);

create unique index ord_ret_fin_app_recon_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(order_id)
  where status in (
    'pending_reporting',
    'ready_for_reconciliation',
    'reconciliation_requested',
    'reconciliation_in_progress',
    'reconciliation_failed'
  );

create index ord_ret_fin_app_recon_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(order_id);

create index ord_ret_fin_app_recon_report_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(completion_report_record_id);

create index ord_ret_fin_app_recon_audit_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(completion_audit_record_id);

create index ord_ret_fin_app_recon_closeout_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(completion_closeout_record_id);

create index ord_ret_fin_app_recon_final_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(completion_final_record_id);

create index ord_ret_fin_app_recon_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(completion_confirmation_record_id);

create index ord_ret_fin_app_recon_rel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(completion_release_record_id);

create index ord_ret_fin_app_recon_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(completion_approval_record_id);

create index ord_ret_fin_app_recon_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(completion_review_record_id);

create index ord_ret_fin_app_recon_completion_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(approval_completion_record_id);

create index ord_ret_fin_app_recon_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(approval_confirmation_record_id);

create index ord_ret_fin_app_recon_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(approval_release_record_id);

create index ord_ret_fin_app_recon_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(finalization_approval_record_id);

create index ord_ret_fin_app_recon_fin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(finalization_review_record_id);

create index ord_ret_fin_app_recon_fin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(finalization_record_id);

create index ord_ret_fin_app_recon_rel_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(review_release_confirmation_record_id);

create index ord_ret_fin_app_recon_review_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(review_release_record_id);

create index ord_ret_fin_app_recon_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(approval_record_id);

create index ord_ret_fin_app_recon_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(review_record_id);

create index ord_ret_fin_app_recon_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(delivery_record_id);

create index ord_ret_fin_app_recon_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(export_record_id);

create index ord_ret_fin_app_recon_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(evidence_record_id);

create index ord_ret_fin_app_recon_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(requested_by_profile_id);

create index ord_ret_fin_app_recon_reconciled_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(reconciled_by_profile_id);

create index ord_ret_fin_app_recon_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(verified_by_profile_id);

create index ord_ret_fin_app_recon_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(status);

create index ord_ret_fin_app_recon_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(reconciliation_result);

create index ord_ret_fin_app_recon_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(ready_at);

create index ord_ret_fin_app_recon_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(requested_at);

create index ord_ret_fin_app_recon_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(started_at);

create index ord_ret_fin_app_recon_reconciled_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(reconciled_at);

create index ord_ret_fin_app_recon_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(verified_at);

create index ord_ret_fin_app_recon_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_events (
  id bigint generated always as identity primary key,
  completion_recon_record_id bigint not null,
  order_id bigint not null,
  completion_report_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_recon_events_record_fk
    foreign key (completion_recon_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_recon_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_recon_events_report_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_recon_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_recon_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_recon_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_recon_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_recon_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_events(completion_recon_record_id);

create index ord_ret_fin_app_recon_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_events(order_id);

create index ord_ret_fin_app_recon_events_report_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_events(completion_report_record_id);

create index ord_ret_fin_app_recon_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_events(actor_profile_id);

create index ord_ret_fin_app_recon_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_events(actor_role);

create index ord_ret_fin_app_recon_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_events(event_type);

create index ord_ret_fin_app_recon_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_events(previous_status);

create index ord_ret_fin_app_recon_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_events(new_status);

create index ord_ret_fin_app_recon_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_events(created_at);
