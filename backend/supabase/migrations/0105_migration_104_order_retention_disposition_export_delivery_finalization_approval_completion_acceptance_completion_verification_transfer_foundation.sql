-- Migration 104 order retention disposition export delivery finalization approval completion acceptance completion verification transfer foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion acceptance completion verification transfer records and event tracking after completion audit transfer.
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
-- - completion verification transfer records are administrative workflow records only; they do not transfer ownership, release funds, mint NFTs, or delete files.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_status as enum (
      'pending_completion_audit_transfer',
      'ready_for_completion_verification_transfer',
      'completion_verification_transfer_requested',
      'completion_verification_transfer_in_progress',
      'completion_verification_transferred',
      'completion_verification_transfer_failed',
      'completion_verification_transfer_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_result as enum (
      'not_transferred',
      'transferred',
      'transferred_with_notes',
      'retention_hold',
      'discrepancy_found',
      'blocked',
      'needs_completion_audit_transfer_update',
      'manual_verification_transfer'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_event as enum (
      'completion_verification_transfer_created',
      'completion_audit_transfer_attached',
      'completion_verification_transfer_ready',
      'completion_verification_transfer_requested',
      'completion_verification_transfer_started',
      'completion_verification_transfer_completed',
      'completion_verification_transfer_failed',
      'completion_verification_transfer_cancelled',
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_audit_transfer_record_id bigint not null,
  completion_report_transfer_record_id bigint,
  completion_reconciliation_transfer_record_id bigint,
  completion_closeout_transfer_record_id bigint,
  completion_archive_transfer_record_id bigint,
  completion_settlement_transfer_record_id bigint,
  previous_completion_audit_transfer_record_id bigint,
  completion_review_transfer_record_id bigint,
  completion_approval_transfer_record_id bigint,
  completion_release_transfer_record_id bigint,
  completion_confirmation_transfer_record_id bigint,
  completion_transfer_record_id bigint,
  completion_acceptance_settlement_record_id bigint,
  completion_verification_record_id bigint,
  completion_audit_record_id bigint,
  completion_report_record_id bigint,
  completion_reconciliation_record_id bigint,
  completion_closeout_record_id bigint,
  completion_archive_record_id bigint,
  completion_approval_record_id bigint,
  completion_review_record_id bigint,
  completion_release_record_id bigint,
  completion_confirmation_record_id bigint,
  completion_finalization_record_id bigint,
  requested_by_profile_id bigint,
  transferred_by_profile_id bigint,
  verified_by_profile_id bigint,
  reviewed_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_status not null default 'pending_completion_audit_transfer',
  completion_verification_transfer_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_result not null default 'not_transferred',
  completion_verification_transfer_reference text not null,
  completion_verification_transfer_summary text,
  completion_verification_transfer_note text,
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

  constraint ord_ret_fin_app_acrepaudvertran_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrepaudvertran_acrepaudtran_fk
    foreign key (completion_audit_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudtran_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrepaudvertran_acreptran_fk
    foreign key (completion_report_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acreptran_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acrecontran_fk
    foreign key (completion_reconciliation_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrecontran_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acclotran_fk
    foreign key (completion_closeout_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acclotran_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acarctran_fk
    foreign key (completion_archive_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acarctran_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acsetttran_fk
    foreign key (completion_settlement_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acsetttran_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acaudtran_fk
    foreign key (previous_completion_audit_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acaudtran_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acrevtran_fk
    foreign key (completion_review_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acapptran_fk
    foreign key (completion_approval_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapptran_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acreltran_fk
    foreign key (completion_release_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acreltran_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acctran_fk
    foreign key (completion_confirmation_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acctran_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_actrans_fk
    foreign key (completion_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_asett_fk
    foreign key (completion_acceptance_settlement_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_asett_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acver_fk
    foreign key (completion_verification_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acver_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acaud_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acaud_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acrep_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acrecon_fk
    foreign key (completion_reconciliation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrecon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acclo_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acclo_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acarc_fk
    foreign key (completion_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acarc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acapp_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acrev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acrel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrel_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acconf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_acfin_fk
    foreign key (completion_finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfin_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_transferred_by_fk
    foreign key (transferred_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_reviewed_by_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_reference_chk check (
    btrim(completion_verification_transfer_reference) <> ''
  ),
  constraint ord_ret_fin_app_acrepaudvertran_summary_chk check (
    completion_verification_transfer_summary is null or btrim(completion_verification_transfer_summary) <> ''
  ),
  constraint ord_ret_fin_app_acrepaudvertran_note_chk check (
    completion_verification_transfer_note is null or btrim(completion_verification_transfer_note) <> ''
  ),
  constraint ord_ret_fin_app_acrepaudvertran_hold_note_chk check (
    retention_hold_note is null or btrim(retention_hold_note) <> ''
  ),
  constraint ord_ret_fin_app_acrepaudvertran_discrepancy_chk check (
    discrepancy_note is null or btrim(discrepancy_note) <> ''
  ),
  constraint ord_ret_fin_app_acrepaudvertran_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_acrepaudvertran_failed_reason_chk check (
    status <> 'completion_verification_transfer_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_acrepaudvertran_hold_result_chk check (
    completion_verification_transfer_result <> 'retention_hold' or retention_hold_note is not null
  ),
  constraint ord_ret_fin_app_acrepaudvertran_discrepancy_result_chk check (
    completion_verification_transfer_result <> 'discrepancy_found' or discrepancy_note is not null
  ),
  constraint ord_ret_fin_app_acrepaudvertran_result_status_chk check (
    (
      status in (
        'pending_completion_audit_transfer',
        'ready_for_completion_verification_transfer',
        'completion_verification_transfer_requested',
        'completion_verification_transfer_in_progress',
        'completion_verification_transfer_cancelled'
      )
      and completion_verification_transfer_result = 'not_transferred'
    )
    or (
      status = 'completion_verification_transferred'
      and completion_verification_transfer_result in (
        'transferred',
        'transferred_with_notes',
        'retention_hold',
        'discrepancy_found',
        'manual_verification_transfer'
      )
    )
    or (
      status = 'completion_verification_transfer_failed'
      and completion_verification_transfer_result in (
        'blocked',
        'needs_completion_audit_transfer_update'
      )
    )
  ),
  constraint ord_ret_fin_app_acrepaudvertran_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_completion_verification_transfer',
      'completion_verification_transfer_requested',
      'completion_verification_transfer_in_progress',
      'completion_verification_transferred',
      'completion_verification_transfer_failed',
      'completion_verification_transfer_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acrepaudvertran_requested_status_chk check (
    requested_at is null
    or status in (
      'completion_verification_transfer_requested',
      'completion_verification_transfer_in_progress',
      'completion_verification_transferred',
      'completion_verification_transfer_failed',
      'completion_verification_transfer_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acrepaudvertran_started_status_chk check (
    started_at is null
    or status in (
      'completion_verification_transfer_in_progress',
      'completion_verification_transferred',
      'completion_verification_transfer_failed',
      'completion_verification_transfer_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acrepaudvertran_transferred_status_chk check (
    transferred_at is null or status = 'completion_verification_transferred'
  ),
  constraint ord_ret_fin_app_acrepaudvertran_verified_status_chk check (
    verified_at is null or status = 'completion_verification_transferred'
  ),
  constraint ord_ret_fin_app_acrepaudvertran_reviewed_status_chk check (
    reviewed_at is null or status = 'completion_verification_transferred'
  ),
  constraint ord_ret_fin_app_acrepaudvertran_failed_status_chk check (
    failed_at is null or status = 'completion_verification_transfer_failed'
  ),
  constraint ord_ret_fin_app_acrepaudvertran_cancelled_status_chk check (
    cancelled_at is null or status = 'completion_verification_transfer_cancelled'
  ),
  constraint ord_ret_fin_app_acrepaudvertran_terminal_one_chk check (
    num_nonnulls(transferred_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_acrepaudvertran_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_acrepaudvertran_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(completion_verification_transfer_reference);

create unique index ord_ret_fin_app_acrepaudvertran_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(order_id)
  where status in (
    'pending_completion_audit_transfer',
    'ready_for_completion_verification_transfer',
    'completion_verification_transfer_requested',
    'completion_verification_transfer_in_progress',
    'completion_verification_transfer_failed'
  );

create index ord_ret_fin_app_acrepaudvertran_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(order_id);

create index ord_ret_fin_app_acrepaudvertran_acrepaudtran_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(completion_audit_transfer_record_id);

create index ord_ret_fin_app_acrepaudvertran_acreptran_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(completion_report_transfer_record_id);

create index ord_ret_fin_app_acrepaudvertran_acrecontran_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(completion_reconciliation_transfer_record_id);

create index ord_ret_fin_app_acrepaudvertran_acclotran_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(completion_closeout_transfer_record_id);

create index ord_ret_fin_app_acrepaudvertran_acarctran_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(completion_archive_transfer_record_id);

create index ord_ret_fin_app_acrepaudvertran_acsetttran_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(completion_settlement_transfer_record_id);

create index ord_ret_fin_app_acrepaudvertran_acaudtran_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(previous_completion_audit_transfer_record_id);

create index ord_ret_fin_app_acrepaudvertran_acver_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(completion_verification_record_id);

create index ord_ret_fin_app_acrepaudvertran_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(status);

create index ord_ret_fin_app_acrepaudvertran_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(completion_verification_transfer_result);

create index ord_ret_fin_app_acrepaudvertran_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(ready_at);

create index ord_ret_fin_app_acrepaudvertran_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(requested_at);

create index ord_ret_fin_app_acrepaudvertran_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(started_at);

create index ord_ret_fin_app_acrepaudvertran_transferred_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(transferred_at);

create index ord_ret_fin_app_acrepaudvertran_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_events (
  id bigint generated always as identity primary key,
  completion_verification_transfer_record_id bigint not null,
  order_id bigint not null,
  completion_audit_transfer_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_acrepaudvertran_events_record_fk
    foreign key (completion_verification_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrepaudvertran_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrepaudvertran_events_acrepaudtran_fk
    foreign key (completion_audit_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudtran_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrepaudvertran_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_acrepaudvertran_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_acrepaudvertran_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_acrepaudvertran_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_acrepaudvertran_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_events(completion_verification_transfer_record_id);

create index ord_ret_fin_app_acrepaudvertran_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_events(order_id);

create index ord_ret_fin_app_acrepaudvertran_events_acrepaudtran_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_events(completion_audit_transfer_record_id);

create index ord_ret_fin_app_acrepaudvertran_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_events(actor_profile_id);

create index ord_ret_fin_app_acrepaudvertran_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_events(actor_role);

create index ord_ret_fin_app_acrepaudvertran_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_events(event_type);

create index ord_ret_fin_app_acrepaudvertran_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_events(previous_status);

create index ord_ret_fin_app_acrepaudvertran_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_events(new_status);

create index ord_ret_fin_app_acrepaudvertran_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrepaudvertran_events(created_at);
