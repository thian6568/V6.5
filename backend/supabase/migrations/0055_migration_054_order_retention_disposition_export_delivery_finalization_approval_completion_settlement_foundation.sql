-- Migration 054 order retention disposition export delivery finalization approval completion settlement foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion settlement records and settlement event tracking after finalization approval completion reconciliation.
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
-- - settlement records are administrative workflow records only; they do not move funds.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_settle_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_settle_status as enum (
      'pending_reconciliation',
      'ready_for_settlement',
      'settlement_requested',
      'settlement_in_progress',
      'settled',
      'settlement_failed',
      'settlement_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_settle_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_settle_result as enum (
      'not_settled',
      'settled',
      'settled_with_notes',
      'discrepancy_found',
      'blocked',
      'needs_reconciliation_update',
      'manual_settlement'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_settle_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_settle_event as enum (
      'settlement_created',
      'reconciliation_attached',
      'settlement_ready',
      'settlement_requested',
      'settlement_started',
      'settlement_completed',
      'settlement_failed',
      'settlement_cancelled',
      'discrepancy_recorded',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_settle_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_settle_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_recon_record_id bigint not null,
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
  settled_by_profile_id bigint,
  verified_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_settle_status not null default 'pending_reconciliation',
  settlement_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_settle_result not null default 'not_settled',
  settlement_reference text not null,
  settlement_summary text,
  settlement_note text,
  discrepancy_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  settled_at timestamptz,
  verified_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_settle_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_settle_recon_fk
    foreign key (completion_recon_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_settle_report_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_audit_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_closeout_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_final_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_conf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_rel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_app_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_rev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_settled_by_fk
    foreign key (settled_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_reference_chk check (
    btrim(settlement_reference) <> ''
  ),
  constraint ord_ret_fin_app_settle_summary_chk check (
    settlement_summary is null or btrim(settlement_summary) <> ''
  ),
  constraint ord_ret_fin_app_settle_note_chk check (
    settlement_note is null or btrim(settlement_note) <> ''
  ),
  constraint ord_ret_fin_app_settle_discrepancy_chk check (
    discrepancy_note is null or btrim(discrepancy_note) <> ''
  ),
  constraint ord_ret_fin_app_settle_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_settle_failed_reason_chk check (
    status <> 'settlement_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_settle_discrepancy_result_chk check (
    settlement_result <> 'discrepancy_found' or discrepancy_note is not null
  ),
  constraint ord_ret_fin_app_settle_result_status_chk check (
    (
      status in (
        'pending_reconciliation',
        'ready_for_settlement',
        'settlement_requested',
        'settlement_in_progress',
        'settlement_cancelled'
      )
      and settlement_result = 'not_settled'
    )
    or (
      status = 'settled'
      and settlement_result in (
        'settled',
        'settled_with_notes',
        'discrepancy_found',
        'manual_settlement'
      )
    )
    or (
      status = 'settlement_failed'
      and settlement_result in (
        'blocked',
        'needs_reconciliation_update'
      )
    )
  ),
  constraint ord_ret_fin_app_settle_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_settlement',
      'settlement_requested',
      'settlement_in_progress',
      'settled',
      'settlement_failed',
      'settlement_cancelled'
    )
  ),
  constraint ord_ret_fin_app_settle_requested_status_chk check (
    requested_at is null
    or status in (
      'settlement_requested',
      'settlement_in_progress',
      'settled',
      'settlement_failed',
      'settlement_cancelled'
    )
  ),
  constraint ord_ret_fin_app_settle_started_status_chk check (
    started_at is null
    or status in (
      'settlement_in_progress',
      'settled',
      'settlement_failed',
      'settlement_cancelled'
    )
  ),
  constraint ord_ret_fin_app_settle_settled_status_chk check (
    settled_at is null or status = 'settled'
  ),
  constraint ord_ret_fin_app_settle_verified_status_chk check (
    verified_at is null or status = 'settled'
  ),
  constraint ord_ret_fin_app_settle_failed_status_chk check (
    failed_at is null or status = 'settlement_failed'
  ),
  constraint ord_ret_fin_app_settle_cancelled_status_chk check (
    cancelled_at is null or status = 'settlement_cancelled'
  ),
  constraint ord_ret_fin_app_settle_terminal_one_chk check (
    num_nonnulls(settled_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_settle_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_settle_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(settlement_reference);

create unique index ord_ret_fin_app_settle_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(order_id)
  where status in (
    'pending_reconciliation',
    'ready_for_settlement',
    'settlement_requested',
    'settlement_in_progress',
    'settlement_failed'
  );

create index ord_ret_fin_app_settle_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(order_id);

create index ord_ret_fin_app_settle_recon_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(completion_recon_record_id);

create index ord_ret_fin_app_settle_report_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(completion_report_record_id);

create index ord_ret_fin_app_settle_audit_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(completion_audit_record_id);

create index ord_ret_fin_app_settle_closeout_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(completion_closeout_record_id);

create index ord_ret_fin_app_settle_final_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(completion_final_record_id);

create index ord_ret_fin_app_settle_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(completion_confirmation_record_id);

create index ord_ret_fin_app_settle_rel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(completion_release_record_id);

create index ord_ret_fin_app_settle_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(completion_approval_record_id);

create index ord_ret_fin_app_settle_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(completion_review_record_id);

create index ord_ret_fin_app_settle_completion_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(approval_completion_record_id);

create index ord_ret_fin_app_settle_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(approval_confirmation_record_id);

create index ord_ret_fin_app_settle_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(approval_release_record_id);

create index ord_ret_fin_app_settle_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(finalization_approval_record_id);

create index ord_ret_fin_app_settle_fin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(finalization_review_record_id);

create index ord_ret_fin_app_settle_fin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(finalization_record_id);

create index ord_ret_fin_app_settle_rel_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(review_release_confirmation_record_id);

create index ord_ret_fin_app_settle_review_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(review_release_record_id);

create index ord_ret_fin_app_settle_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(approval_record_id);

create index ord_ret_fin_app_settle_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(review_record_id);

create index ord_ret_fin_app_settle_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(delivery_record_id);

create index ord_ret_fin_app_settle_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(export_record_id);

create index ord_ret_fin_app_settle_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(evidence_record_id);

create index ord_ret_fin_app_settle_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(requested_by_profile_id);

create index ord_ret_fin_app_settle_settled_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(settled_by_profile_id);

create index ord_ret_fin_app_settle_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(verified_by_profile_id);

create index ord_ret_fin_app_settle_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(status);

create index ord_ret_fin_app_settle_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(settlement_result);

create index ord_ret_fin_app_settle_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(ready_at);

create index ord_ret_fin_app_settle_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(requested_at);

create index ord_ret_fin_app_settle_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(started_at);

create index ord_ret_fin_app_settle_settled_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(settled_at);

create index ord_ret_fin_app_settle_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(verified_at);

create index ord_ret_fin_app_settle_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_events (
  id bigint generated always as identity primary key,
  completion_settlement_record_id bigint not null,
  order_id bigint not null,
  completion_recon_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_settle_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_settle_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_settle_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_settle_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_settle_events_record_fk
    foreign key (completion_settlement_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_settle_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_settle_events_recon_fk
    foreign key (completion_recon_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_settle_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_settle_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_settle_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_settle_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_settle_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_events(completion_settlement_record_id);

create index ord_ret_fin_app_settle_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_events(order_id);

create index ord_ret_fin_app_settle_events_recon_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_events(completion_recon_record_id);

create index ord_ret_fin_app_settle_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_events(actor_profile_id);

create index ord_ret_fin_app_settle_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_events(actor_role);

create index ord_ret_fin_app_settle_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_events(event_type);

create index ord_ret_fin_app_settle_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_events(previous_status);

create index ord_ret_fin_app_settle_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_events(new_status);

create index ord_ret_fin_app_settle_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_events(created_at);
