-- Migration 052 order retention disposition export delivery finalization approval completion reporting foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion reporting records and reporting event tracking after finalization approval completion audit.
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_report_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_status as enum (
      'pending_audit',
      'ready_for_reporting',
      'reporting_requested',
      'reporting_in_progress',
      'reported',
      'reporting_failed',
      'reporting_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_report_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_result as enum (
      'not_reported',
      'reported',
      'reported_with_notes',
      'blocked',
      'needs_audit_update',
      'manual_reporting'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_report_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_event as enum (
      'reporting_created',
      'audit_attached',
      'reporting_ready',
      'reporting_requested',
      'reporting_started',
      'reporting_completed',
      'reporting_failed',
      'reporting_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_report_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_audit_record_id bigint not null,
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
  reported_by_profile_id bigint,
  verified_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_status not null default 'pending_audit',
  report_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_result not null default 'not_reported',
  report_reference text not null,
  report_summary text,
  report_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  reported_at timestamptz,
  verified_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_report_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_report_audit_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_report_closeout_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_final_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_conf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_rel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_app_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_rev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_report_reported_by_fk
    foreign key (reported_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_report_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_report_reference_chk check (
    btrim(report_reference) <> ''
  ),
  constraint ord_ret_fin_app_report_summary_chk check (
    report_summary is null or btrim(report_summary) <> ''
  ),
  constraint ord_ret_fin_app_report_note_chk check (
    report_note is null or btrim(report_note) <> ''
  ),
  constraint ord_ret_fin_app_report_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_report_failed_reason_chk check (
    status <> 'reporting_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_report_result_status_chk check (
    (
      status in (
        'pending_audit',
        'ready_for_reporting',
        'reporting_requested',
        'reporting_in_progress',
        'reporting_cancelled'
      )
      and report_result = 'not_reported'
    )
    or (
      status = 'reported'
      and report_result in (
        'reported',
        'reported_with_notes',
        'manual_reporting'
      )
    )
    or (
      status = 'reporting_failed'
      and report_result in (
        'blocked',
        'needs_audit_update'
      )
    )
  ),
  constraint ord_ret_fin_app_report_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_reporting',
      'reporting_requested',
      'reporting_in_progress',
      'reported',
      'reporting_failed',
      'reporting_cancelled'
    )
  ),
  constraint ord_ret_fin_app_report_requested_status_chk check (
    requested_at is null
    or status in (
      'reporting_requested',
      'reporting_in_progress',
      'reported',
      'reporting_failed',
      'reporting_cancelled'
    )
  ),
  constraint ord_ret_fin_app_report_started_status_chk check (
    started_at is null
    or status in (
      'reporting_in_progress',
      'reported',
      'reporting_failed',
      'reporting_cancelled'
    )
  ),
  constraint ord_ret_fin_app_report_reported_status_chk check (
    reported_at is null or status = 'reported'
  ),
  constraint ord_ret_fin_app_report_verified_status_chk check (
    verified_at is null or status = 'reported'
  ),
  constraint ord_ret_fin_app_report_failed_status_chk check (
    failed_at is null or status = 'reporting_failed'
  ),
  constraint ord_ret_fin_app_report_cancelled_status_chk check (
    cancelled_at is null or status = 'reporting_cancelled'
  ),
  constraint ord_ret_fin_app_report_terminal_one_chk check (
    num_nonnulls(reported_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_report_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_report_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(report_reference);

create unique index ord_ret_fin_app_report_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(order_id)
  where status in (
    'pending_audit',
    'ready_for_reporting',
    'reporting_requested',
    'reporting_in_progress',
    'reporting_failed'
  );

create index ord_ret_fin_app_report_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(order_id);

create index ord_ret_fin_app_report_audit_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(completion_audit_record_id);

create index ord_ret_fin_app_report_closeout_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(completion_closeout_record_id);

create index ord_ret_fin_app_report_final_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(completion_final_record_id);

create index ord_ret_fin_app_report_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(completion_confirmation_record_id);

create index ord_ret_fin_app_report_rel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(completion_release_record_id);

create index ord_ret_fin_app_report_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(completion_approval_record_id);

create index ord_ret_fin_app_report_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(completion_review_record_id);

create index ord_ret_fin_app_report_completion_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(approval_completion_record_id);

create index ord_ret_fin_app_report_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(approval_confirmation_record_id);

create index ord_ret_fin_app_report_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(approval_release_record_id);

create index ord_ret_fin_app_report_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(finalization_approval_record_id);

create index ord_ret_fin_app_report_fin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(finalization_review_record_id);

create index ord_ret_fin_app_report_fin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(finalization_record_id);

create index ord_ret_fin_app_report_rel_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(review_release_confirmation_record_id);

create index ord_ret_fin_app_report_review_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(review_release_record_id);

create index ord_ret_fin_app_report_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(approval_record_id);

create index ord_ret_fin_app_report_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(review_record_id);

create index ord_ret_fin_app_report_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(delivery_record_id);

create index ord_ret_fin_app_report_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(export_record_id);

create index ord_ret_fin_app_report_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(evidence_record_id);

create index ord_ret_fin_app_report_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(requested_by_profile_id);

create index ord_ret_fin_app_report_reported_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(reported_by_profile_id);

create index ord_ret_fin_app_report_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(verified_by_profile_id);

create index ord_ret_fin_app_report_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(status);

create index ord_ret_fin_app_report_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(report_result);

create index ord_ret_fin_app_report_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(ready_at);

create index ord_ret_fin_app_report_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(requested_at);

create index ord_ret_fin_app_report_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(started_at);

create index ord_ret_fin_app_report_reported_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(reported_at);

create index ord_ret_fin_app_report_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(verified_at);

create index ord_ret_fin_app_report_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_events (
  id bigint generated always as identity primary key,
  completion_report_record_id bigint not null,
  order_id bigint not null,
  completion_audit_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_report_events_record_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_report_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_report_events_audit_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(id)
    on delete set null,

  constraint ord_ret_fin_app_report_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_report_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_report_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_report_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_report_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_report_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_events(completion_report_record_id);

create index ord_ret_fin_app_report_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_events(order_id);

create index ord_ret_fin_app_report_events_audit_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_events(completion_audit_record_id);

create index ord_ret_fin_app_report_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_events(actor_profile_id);

create index ord_ret_fin_app_report_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_events(actor_role);

create index ord_ret_fin_app_report_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_events(event_type);

create index ord_ret_fin_app_report_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_events(previous_status);

create index ord_ret_fin_app_report_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_events(new_status);

create index ord_ret_fin_app_report_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_report_events(created_at);
