-- Migration 056 order retention disposition export delivery finalization approval completion handover foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion handover records and handover event tracking after finalization approval completion archive.
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
-- - handover records are administrative workflow records only; they do not transfer ownership, release funds, or delete files.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_handover_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_status as enum (
      'pending_archive',
      'ready_for_handover',
      'handover_requested',
      'handover_in_progress',
      'handed_over',
      'handover_failed',
      'handover_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_handover_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_result as enum (
      'not_handed_over',
      'handed_over',
      'handed_over_with_notes',
      'retention_hold',
      'blocked',
      'needs_archive_update',
      'manual_handover'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_handover_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_event as enum (
      'handover_created',
      'archive_attached',
      'handover_ready',
      'handover_requested',
      'handover_started',
      'handover_completed',
      'handover_failed',
      'handover_cancelled',
      'retention_hold_recorded',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_handover_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_archive_record_id bigint not null,
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
  handed_over_by_profile_id bigint,
  verified_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_status not null default 'pending_archive',
  handover_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_result not null default 'not_handed_over',
  handover_reference text not null,
  handover_summary text,
  handover_note text,
  retention_hold_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  handed_over_at timestamptz,
  verified_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_handover_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_handover_archive_fk
    foreign key (completion_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_archive_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_handover_settlement_fk
    foreign key (completion_settlement_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_settlement_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_recon_fk
    foreign key (completion_recon_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_recon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_report_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_audit_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_closeout_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_final_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_conf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_rel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_app_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_rev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_handed_by_fk
    foreign key (handed_over_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_reference_chk check (
    btrim(handover_reference) <> ''
  ),
  constraint ord_ret_fin_app_handover_summary_chk check (
    handover_summary is null or btrim(handover_summary) <> ''
  ),
  constraint ord_ret_fin_app_handover_note_chk check (
    handover_note is null or btrim(handover_note) <> ''
  ),
  constraint ord_ret_fin_app_handover_hold_note_chk check (
    retention_hold_note is null or btrim(retention_hold_note) <> ''
  ),
  constraint ord_ret_fin_app_handover_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_handover_failed_reason_chk check (
    status <> 'handover_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_handover_hold_result_chk check (
    handover_result <> 'retention_hold' or retention_hold_note is not null
  ),
  constraint ord_ret_fin_app_handover_result_status_chk check (
    (
      status in (
        'pending_archive',
        'ready_for_handover',
        'handover_requested',
        'handover_in_progress',
        'handover_cancelled'
      )
      and handover_result = 'not_handed_over'
    )
    or (
      status = 'handed_over'
      and handover_result in (
        'handed_over',
        'handed_over_with_notes',
        'retention_hold',
        'manual_handover'
      )
    )
    or (
      status = 'handover_failed'
      and handover_result in (
        'blocked',
        'needs_archive_update'
      )
    )
  ),
  constraint ord_ret_fin_app_handover_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_handover',
      'handover_requested',
      'handover_in_progress',
      'handed_over',
      'handover_failed',
      'handover_cancelled'
    )
  ),
  constraint ord_ret_fin_app_handover_requested_status_chk check (
    requested_at is null
    or status in (
      'handover_requested',
      'handover_in_progress',
      'handed_over',
      'handover_failed',
      'handover_cancelled'
    )
  ),
  constraint ord_ret_fin_app_handover_started_status_chk check (
    started_at is null
    or status in (
      'handover_in_progress',
      'handed_over',
      'handover_failed',
      'handover_cancelled'
    )
  ),
  constraint ord_ret_fin_app_handover_handed_status_chk check (
    handed_over_at is null or status = 'handed_over'
  ),
  constraint ord_ret_fin_app_handover_verified_status_chk check (
    verified_at is null or status = 'handed_over'
  ),
  constraint ord_ret_fin_app_handover_failed_status_chk check (
    failed_at is null or status = 'handover_failed'
  ),
  constraint ord_ret_fin_app_handover_cancelled_status_chk check (
    cancelled_at is null or status = 'handover_cancelled'
  ),
  constraint ord_ret_fin_app_handover_terminal_one_chk check (
    num_nonnulls(handed_over_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_handover_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_handover_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(handover_reference);

create unique index ord_ret_fin_app_handover_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(order_id)
  where status in (
    'pending_archive',
    'ready_for_handover',
    'handover_requested',
    'handover_in_progress',
    'handover_failed'
  );

create index ord_ret_fin_app_handover_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(order_id);

create index ord_ret_fin_app_handover_archive_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(completion_archive_record_id);

create index ord_ret_fin_app_handover_settlement_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(completion_settlement_record_id);

create index ord_ret_fin_app_handover_recon_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(completion_recon_record_id);

create index ord_ret_fin_app_handover_report_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(completion_report_record_id);

create index ord_ret_fin_app_handover_audit_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(completion_audit_record_id);

create index ord_ret_fin_app_handover_closeout_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(completion_closeout_record_id);

create index ord_ret_fin_app_handover_final_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(completion_final_record_id);

create index ord_ret_fin_app_handover_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(completion_confirmation_record_id);

create index ord_ret_fin_app_handover_rel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(completion_release_record_id);

create index ord_ret_fin_app_handover_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(completion_approval_record_id);

create index ord_ret_fin_app_handover_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(completion_review_record_id);

create index ord_ret_fin_app_handover_completion_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(approval_completion_record_id);

create index ord_ret_fin_app_handover_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(approval_confirmation_record_id);

create index ord_ret_fin_app_handover_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(approval_release_record_id);

create index ord_ret_fin_app_handover_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(finalization_approval_record_id);

create index ord_ret_fin_app_handover_fin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(finalization_review_record_id);

create index ord_ret_fin_app_handover_fin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(finalization_record_id);

create index ord_ret_fin_app_handover_rel_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(review_release_confirmation_record_id);

create index ord_ret_fin_app_handover_review_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(review_release_record_id);

create index ord_ret_fin_app_handover_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(approval_record_id);

create index ord_ret_fin_app_handover_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(review_record_id);

create index ord_ret_fin_app_handover_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(delivery_record_id);

create index ord_ret_fin_app_handover_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(export_record_id);

create index ord_ret_fin_app_handover_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(evidence_record_id);

create index ord_ret_fin_app_handover_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(requested_by_profile_id);

create index ord_ret_fin_app_handover_handed_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(handed_over_by_profile_id);

create index ord_ret_fin_app_handover_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(verified_by_profile_id);

create index ord_ret_fin_app_handover_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(status);

create index ord_ret_fin_app_handover_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(handover_result);

create index ord_ret_fin_app_handover_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(ready_at);

create index ord_ret_fin_app_handover_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(requested_at);

create index ord_ret_fin_app_handover_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(started_at);

create index ord_ret_fin_app_handover_handed_over_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(handed_over_at);

create index ord_ret_fin_app_handover_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(verified_at);

create index ord_ret_fin_app_handover_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_events (
  id bigint generated always as identity primary key,
  completion_handover_record_id bigint not null,
  order_id bigint not null,
  completion_archive_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_handover_events_record_fk
    foreign key (completion_handover_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_handover_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_handover_events_archive_fk
    foreign key (completion_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_archive_records(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_handover_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_handover_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_handover_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_handover_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_handover_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_events(completion_handover_record_id);

create index ord_ret_fin_app_handover_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_events(order_id);

create index ord_ret_fin_app_handover_events_archive_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_events(completion_archive_record_id);

create index ord_ret_fin_app_handover_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_events(actor_profile_id);

create index ord_ret_fin_app_handover_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_events(actor_role);

create index ord_ret_fin_app_handover_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_events(event_type);

create index ord_ret_fin_app_handover_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_events(previous_status);

create index ord_ret_fin_app_handover_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_events(new_status);

create index ord_ret_fin_app_handover_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_handover_events(created_at);
