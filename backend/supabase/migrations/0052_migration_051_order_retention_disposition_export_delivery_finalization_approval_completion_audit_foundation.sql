-- Migration 051 order retention disposition export delivery finalization approval completion audit foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion audit records and audit event tracking after finalization approval completion closeout.
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_audit_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_status as enum (
      'pending_closeout',
      'ready_for_audit',
      'audit_requested',
      'audit_in_progress',
      'audited',
      'audit_failed',
      'audit_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_audit_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_result as enum (
      'not_audited',
      'audited',
      'audited_with_notes',
      'blocked',
      'needs_closeout_update',
      'manual_audit'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_audit_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_event as enum (
      'audit_created',
      'closeout_attached',
      'audit_ready',
      'audit_requested',
      'audit_started',
      'audit_completed',
      'audit_failed',
      'audit_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_audit_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_closeout_record_id bigint not null,
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
  audited_by_profile_id bigint,
  verified_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_status not null default 'pending_closeout',
  audit_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_result not null default 'not_audited',
  audit_reference text not null,
  audit_summary text,
  audit_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  audited_at timestamptz,
  verified_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_audit_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_audit_closeout_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_audit_final_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_conf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_rel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_app_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_rev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_audited_by_fk
    foreign key (audited_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_reference_chk check (
    btrim(audit_reference) <> ''
  ),
  constraint ord_ret_fin_app_audit_summary_chk check (
    audit_summary is null or btrim(audit_summary) <> ''
  ),
  constraint ord_ret_fin_app_audit_note_chk check (
    audit_note is null or btrim(audit_note) <> ''
  ),
  constraint ord_ret_fin_app_audit_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_audit_failed_reason_chk check (
    status <> 'audit_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_audit_result_status_chk check (
    (
      status in (
        'pending_closeout',
        'ready_for_audit',
        'audit_requested',
        'audit_in_progress',
        'audit_cancelled'
      )
      and audit_result = 'not_audited'
    )
    or (
      status = 'audited'
      and audit_result in (
        'audited',
        'audited_with_notes',
        'manual_audit'
      )
    )
    or (
      status = 'audit_failed'
      and audit_result in (
        'blocked',
        'needs_closeout_update'
      )
    )
  ),
  constraint ord_ret_fin_app_audit_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_audit',
      'audit_requested',
      'audit_in_progress',
      'audited',
      'audit_failed',
      'audit_cancelled'
    )
  ),
  constraint ord_ret_fin_app_audit_requested_status_chk check (
    requested_at is null
    or status in (
      'audit_requested',
      'audit_in_progress',
      'audited',
      'audit_failed',
      'audit_cancelled'
    )
  ),
  constraint ord_ret_fin_app_audit_started_status_chk check (
    started_at is null
    or status in (
      'audit_in_progress',
      'audited',
      'audit_failed',
      'audit_cancelled'
    )
  ),
  constraint ord_ret_fin_app_audit_audited_status_chk check (
    audited_at is null or status = 'audited'
  ),
  constraint ord_ret_fin_app_audit_verified_status_chk check (
    verified_at is null or status = 'audited'
  ),
  constraint ord_ret_fin_app_audit_failed_status_chk check (
    failed_at is null or status = 'audit_failed'
  ),
  constraint ord_ret_fin_app_audit_cancelled_status_chk check (
    cancelled_at is null or status = 'audit_cancelled'
  ),
  constraint ord_ret_fin_app_audit_terminal_one_chk check (
    num_nonnulls(audited_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_audit_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_audit_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(audit_reference);

create unique index ord_ret_fin_app_audit_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(order_id)
  where status in (
    'pending_closeout',
    'ready_for_audit',
    'audit_requested',
    'audit_in_progress',
    'audit_failed'
  );

create index ord_ret_fin_app_audit_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(order_id);

create index ord_ret_fin_app_audit_closeout_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(completion_closeout_record_id);

create index ord_ret_fin_app_audit_final_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(completion_final_record_id);

create index ord_ret_fin_app_audit_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(completion_confirmation_record_id);

create index ord_ret_fin_app_audit_rel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(completion_release_record_id);

create index ord_ret_fin_app_audit_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(completion_approval_record_id);

create index ord_ret_fin_app_audit_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(completion_review_record_id);

create index ord_ret_fin_app_audit_completion_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(approval_completion_record_id);

create index ord_ret_fin_app_audit_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(approval_confirmation_record_id);

create index ord_ret_fin_app_audit_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(approval_release_record_id);

create index ord_ret_fin_app_audit_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(finalization_approval_record_id);

create index ord_ret_fin_app_audit_fin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(finalization_review_record_id);

create index ord_ret_fin_app_audit_fin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(finalization_record_id);

create index ord_ret_fin_app_audit_rel_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(review_release_confirmation_record_id);

create index ord_ret_fin_app_audit_review_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(review_release_record_id);

create index ord_ret_fin_app_audit_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(approval_record_id);

create index ord_ret_fin_app_audit_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(review_record_id);

create index ord_ret_fin_app_audit_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(delivery_record_id);

create index ord_ret_fin_app_audit_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(export_record_id);

create index ord_ret_fin_app_audit_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(evidence_record_id);

create index ord_ret_fin_app_audit_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(requested_by_profile_id);

create index ord_ret_fin_app_audit_audited_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(audited_by_profile_id);

create index ord_ret_fin_app_audit_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(verified_by_profile_id);

create index ord_ret_fin_app_audit_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(status);

create index ord_ret_fin_app_audit_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(audit_result);

create index ord_ret_fin_app_audit_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(ready_at);

create index ord_ret_fin_app_audit_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(requested_at);

create index ord_ret_fin_app_audit_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(started_at);

create index ord_ret_fin_app_audit_audited_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(audited_at);

create index ord_ret_fin_app_audit_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(verified_at);

create index ord_ret_fin_app_audit_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_events (
  id bigint generated always as identity primary key,
  completion_audit_record_id bigint not null,
  order_id bigint not null,
  completion_closeout_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_audit_events_record_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_audit_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_audit_events_closeout_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_audit_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_audit_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_audit_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_audit_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_audit_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_events(completion_audit_record_id);

create index ord_ret_fin_app_audit_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_events(order_id);

create index ord_ret_fin_app_audit_events_closeout_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_events(completion_closeout_record_id);

create index ord_ret_fin_app_audit_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_events(actor_profile_id);

create index ord_ret_fin_app_audit_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_events(actor_role);

create index ord_ret_fin_app_audit_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_events(event_type);

create index ord_ret_fin_app_audit_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_events(previous_status);

create index ord_ret_fin_app_audit_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_events(new_status);

create index ord_ret_fin_app_audit_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_audit_events(created_at);
