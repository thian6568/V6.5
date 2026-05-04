-- Migration 092 order retention disposition export delivery finalization approval completion acceptance completion transfer foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion acceptance completion transfer records and completion transfer event tracking after completion handover.
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
-- - completion transfer records are administrative workflow records only; they do not transfer ownership, release funds, mint NFTs, or delete files.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_status as enum (
      'pending_completion_handover',
      'ready_for_completion_transfer',
      'completion_transfer_requested',
      'completion_transfer_in_progress',
      'completion_transferred',
      'completion_transfer_failed',
      'completion_transfer_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_result as enum (
      'not_transferred',
      'transferred',
      'transferred_with_notes',
      'retention_hold',
      'discrepancy_found',
      'blocked',
      'needs_completion_handover_update',
      'manual_transfer'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_event as enum (
      'completion_transfer_created',
      'completion_handover_attached',
      'completion_transfer_ready',
      'completion_transfer_requested',
      'completion_transfer_started',
      'completion_transfer_completed',
      'completion_transfer_failed',
      'completion_transfer_cancelled',
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_handover_record_id bigint not null,
  completion_certification_record_id bigint,
  completion_verification_record_id bigint,
  completion_final_record_id bigint,
  completion_archive_record_id bigint,
  completion_closeout_record_id bigint,
  completion_reconciliation_record_id bigint,
  completion_report_record_id bigint,
  completion_audit_record_id bigint,
  completion_approval_record_id bigint,
  completion_review_record_id bigint,
  completion_release_record_id bigint,
  completion_confirmation_record_id bigint,
  completion_finalization_record_id bigint,
  requested_by_profile_id bigint,
  transferred_by_profile_id bigint,
  verified_by_profile_id bigint,
  reviewed_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_status not null default 'pending_completion_handover',
  completion_transfer_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_result not null default 'not_transferred',
  completion_transfer_reference text not null,
  completion_transfer_summary text,
  completion_transfer_note text,
  retention_hold_note text,
  discrepancy_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  transferred_at timestamptz,
  verified_at timestamptz,
  reviewed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_actrans_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_actrans_achand_fk
    foreign key (completion_handover_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_achand_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_actrans_accert_fk
    foreign key (completion_certification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_accert_records(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_acver_fk
    foreign key (completion_verification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acver_records(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_acfinal_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_acarc_fk
    foreign key (completion_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acarc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_acclo_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acclo_records(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_acrecon_fk
    foreign key (completion_reconciliation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrecon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_acrep_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_acaud_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acaud_records(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_acapp_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_acrev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_acrel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrel_records(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_acconf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_acfin_fk
    foreign key (completion_finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfin_records(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_transferred_by_fk
    foreign key (transferred_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_reviewed_by_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_reference_chk check (
    btrim(completion_transfer_reference) <> ''
  ),
  constraint ord_ret_fin_app_actrans_summary_chk check (
    completion_transfer_summary is null or btrim(completion_transfer_summary) <> ''
  ),
  constraint ord_ret_fin_app_actrans_note_chk check (
    completion_transfer_note is null or btrim(completion_transfer_note) <> ''
  ),
  constraint ord_ret_fin_app_actrans_hold_note_chk check (
    retention_hold_note is null or btrim(retention_hold_note) <> ''
  ),
  constraint ord_ret_fin_app_actrans_discrepancy_chk check (
    discrepancy_note is null or btrim(discrepancy_note) <> ''
  ),
  constraint ord_ret_fin_app_actrans_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_actrans_failed_reason_chk check (
    status <> 'completion_transfer_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_actrans_hold_result_chk check (
    completion_transfer_result <> 'retention_hold' or retention_hold_note is not null
  ),
  constraint ord_ret_fin_app_actrans_discrepancy_result_chk check (
    completion_transfer_result <> 'discrepancy_found' or discrepancy_note is not null
  ),
  constraint ord_ret_fin_app_actrans_result_status_chk check (
    (
      status in (
        'pending_completion_handover',
        'ready_for_completion_transfer',
        'completion_transfer_requested',
        'completion_transfer_in_progress',
        'completion_transfer_cancelled'
      )
      and completion_transfer_result = 'not_transferred'
    )
    or (
      status = 'completion_transferred'
      and completion_transfer_result in (
        'transferred',
        'transferred_with_notes',
        'retention_hold',
        'discrepancy_found',
        'manual_transfer'
      )
    )
    or (
      status = 'completion_transfer_failed'
      and completion_transfer_result in (
        'blocked',
        'needs_completion_handover_update'
      )
    )
  ),
  constraint ord_ret_fin_app_actrans_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_completion_transfer',
      'completion_transfer_requested',
      'completion_transfer_in_progress',
      'completion_transferred',
      'completion_transfer_failed',
      'completion_transfer_cancelled'
    )
  ),
  constraint ord_ret_fin_app_actrans_requested_status_chk check (
    requested_at is null
    or status in (
      'completion_transfer_requested',
      'completion_transfer_in_progress',
      'completion_transferred',
      'completion_transfer_failed',
      'completion_transfer_cancelled'
    )
  ),
  constraint ord_ret_fin_app_actrans_started_status_chk check (
    started_at is null
    or status in (
      'completion_transfer_in_progress',
      'completion_transferred',
      'completion_transfer_failed',
      'completion_transfer_cancelled'
    )
  ),
  constraint ord_ret_fin_app_actrans_transferred_status_chk check (
    transferred_at is null or status = 'completion_transferred'
  ),
  constraint ord_ret_fin_app_actrans_verified_status_chk check (
    verified_at is null or status = 'completion_transferred'
  ),
  constraint ord_ret_fin_app_actrans_reviewed_status_chk check (
    reviewed_at is null or status = 'completion_transferred'
  ),
  constraint ord_ret_fin_app_actrans_failed_status_chk check (
    failed_at is null or status = 'completion_transfer_failed'
  ),
  constraint ord_ret_fin_app_actrans_cancelled_status_chk check (
    cancelled_at is null or status = 'completion_transfer_cancelled'
  ),
  constraint ord_ret_fin_app_actrans_terminal_one_chk check (
    num_nonnulls(transferred_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_actrans_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_actrans_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_transfer_reference);

create unique index ord_ret_fin_app_actrans_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(order_id)
  where status in (
    'pending_completion_handover',
    'ready_for_completion_transfer',
    'completion_transfer_requested',
    'completion_transfer_in_progress',
    'completion_transfer_failed'
  );

create index ord_ret_fin_app_actrans_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(order_id);

create index ord_ret_fin_app_actrans_achand_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_handover_record_id);

create index ord_ret_fin_app_actrans_accert_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_certification_record_id);

create index ord_ret_fin_app_actrans_acver_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_verification_record_id);

create index ord_ret_fin_app_actrans_acfinal_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_final_record_id);

create index ord_ret_fin_app_actrans_acarc_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_archive_record_id);

create index ord_ret_fin_app_actrans_acclo_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_closeout_record_id);

create index ord_ret_fin_app_actrans_acrecon_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_reconciliation_record_id);

create index ord_ret_fin_app_actrans_acrep_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_report_record_id);

create index ord_ret_fin_app_actrans_acaud_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_audit_record_id);

create index ord_ret_fin_app_actrans_acapp_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_approval_record_id);

create index ord_ret_fin_app_actrans_acrev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_review_record_id);

create index ord_ret_fin_app_actrans_acrel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_release_record_id);

create index ord_ret_fin_app_actrans_acconf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_confirmation_record_id);

create index ord_ret_fin_app_actrans_acfin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_finalization_record_id);

create index ord_ret_fin_app_actrans_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(status);

create index ord_ret_fin_app_actrans_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(completion_transfer_result);

create index ord_ret_fin_app_actrans_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(ready_at);

create index ord_ret_fin_app_actrans_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(requested_at);

create index ord_ret_fin_app_actrans_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(started_at);

create index ord_ret_fin_app_actrans_transferred_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(transferred_at);

create index ord_ret_fin_app_actrans_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_events (
  id bigint generated always as identity primary key,
  completion_transfer_record_id bigint not null,
  order_id bigint not null,
  completion_handover_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_actrans_events_record_fk
    foreign key (completion_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_actrans_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_actrans_events_achand_fk
    foreign key (completion_handover_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_achand_records(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_actrans_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_actrans_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_actrans_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_actrans_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_actrans_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_events(completion_transfer_record_id);

create index ord_ret_fin_app_actrans_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_events(order_id);

create index ord_ret_fin_app_actrans_events_achand_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_events(completion_handover_record_id);

create index ord_ret_fin_app_actrans_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_events(actor_profile_id);

create index ord_ret_fin_app_actrans_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_events(actor_role);

create index ord_ret_fin_app_actrans_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_events(event_type);

create index ord_ret_fin_app_actrans_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_events(previous_status);

create index ord_ret_fin_app_actrans_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_events(new_status);

create index ord_ret_fin_app_actrans_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_events(created_at);
