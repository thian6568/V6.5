-- Migration 088 order retention disposition export delivery finalization approval completion acceptance completion final foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion acceptance completion final records and completion final event tracking after completion archive.
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
-- - completion final records are administrative workflow records only; they do not transfer ownership, release funds, mint NFTs, or delete files.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_status as enum (
      'pending_completion_archive',
      'ready_for_completion_final',
      'completion_final_requested',
      'completion_final_in_progress',
      'completion_finalized',
      'completion_final_failed',
      'completion_final_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_result as enum (
      'not_finalized',
      'finalized',
      'finalized_with_notes',
      'retention_hold',
      'discrepancy_found',
      'blocked',
      'needs_completion_archive_update',
      'manual_final'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_event as enum (
      'completion_final_created',
      'completion_archive_attached',
      'completion_final_ready',
      'completion_final_requested',
      'completion_final_started',
      'completion_final_completed',
      'completion_final_failed',
      'completion_final_cancelled',
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_archive_record_id bigint not null,
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
  finalized_by_profile_id bigint,
  verified_by_profile_id bigint,
  reviewed_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_status not null default 'pending_completion_archive',
  completion_final_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_result not null default 'not_finalized',
  completion_final_reference text not null,
  completion_final_summary text,
  completion_final_note text,
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

  constraint ord_ret_fin_app_acfinal_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_acfinal_acarc_fk
    foreign key (completion_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acarc_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_acfinal_acclo_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acclo_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_acrecon_fk
    foreign key (completion_reconciliation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrecon_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_acrep_fk
    foreign key (completion_report_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrep_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_acaud_fk
    foreign key (completion_audit_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acaud_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_acapp_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapp_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_acrev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrev_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_acrel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrel_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_acconf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acconf_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_acfin_fk
    foreign key (completion_finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfin_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_finalized_by_fk
    foreign key (finalized_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_reviewed_by_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_reference_chk check (
    btrim(completion_final_reference) <> ''
  ),
  constraint ord_ret_fin_app_acfinal_summary_chk check (
    completion_final_summary is null or btrim(completion_final_summary) <> ''
  ),
  constraint ord_ret_fin_app_acfinal_note_chk check (
    completion_final_note is null or btrim(completion_final_note) <> ''
  ),
  constraint ord_ret_fin_app_acfinal_hold_note_chk check (
    retention_hold_note is null or btrim(retention_hold_note) <> ''
  ),
  constraint ord_ret_fin_app_acfinal_discrepancy_chk check (
    discrepancy_note is null or btrim(discrepancy_note) <> ''
  ),
  constraint ord_ret_fin_app_acfinal_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_acfinal_failed_reason_chk check (
    status <> 'completion_final_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_acfinal_hold_result_chk check (
    completion_final_result <> 'retention_hold' or retention_hold_note is not null
  ),
  constraint ord_ret_fin_app_acfinal_discrepancy_result_chk check (
    completion_final_result <> 'discrepancy_found' or discrepancy_note is not null
  ),
  constraint ord_ret_fin_app_acfinal_result_status_chk check (
    (
      status in (
        'pending_completion_archive',
        'ready_for_completion_final',
        'completion_final_requested',
        'completion_final_in_progress',
        'completion_final_cancelled'
      )
      and completion_final_result = 'not_finalized'
    )
    or (
      status = 'completion_finalized'
      and completion_final_result in (
        'finalized',
        'finalized_with_notes',
        'retention_hold',
        'discrepancy_found',
        'manual_final'
      )
    )
    or (
      status = 'completion_final_failed'
      and completion_final_result in (
        'blocked',
        'needs_completion_archive_update'
      )
    )
  ),
  constraint ord_ret_fin_app_acfinal_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_completion_final',
      'completion_final_requested',
      'completion_final_in_progress',
      'completion_finalized',
      'completion_final_failed',
      'completion_final_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acfinal_requested_status_chk check (
    requested_at is null
    or status in (
      'completion_final_requested',
      'completion_final_in_progress',
      'completion_finalized',
      'completion_final_failed',
      'completion_final_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acfinal_started_status_chk check (
    started_at is null
    or status in (
      'completion_final_in_progress',
      'completion_finalized',
      'completion_final_failed',
      'completion_final_cancelled'
    )
  ),
  constraint ord_ret_fin_app_acfinal_finalized_status_chk check (
    finalized_at is null or status = 'completion_finalized'
  ),
  constraint ord_ret_fin_app_acfinal_verified_status_chk check (
    verified_at is null or status = 'completion_finalized'
  ),
  constraint ord_ret_fin_app_acfinal_reviewed_status_chk check (
    reviewed_at is null or status = 'completion_finalized'
  ),
  constraint ord_ret_fin_app_acfinal_failed_status_chk check (
    failed_at is null or status = 'completion_final_failed'
  ),
  constraint ord_ret_fin_app_acfinal_cancelled_status_chk check (
    cancelled_at is null or status = 'completion_final_cancelled'
  ),
  constraint ord_ret_fin_app_acfinal_terminal_one_chk check (
    num_nonnulls(finalized_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_acfinal_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_acfinal_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(completion_final_reference);

create unique index ord_ret_fin_app_acfinal_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(order_id)
  where status in (
    'pending_completion_archive',
    'ready_for_completion_final',
    'completion_final_requested',
    'completion_final_in_progress',
    'completion_final_failed'
  );

create index ord_ret_fin_app_acfinal_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(order_id);

create index ord_ret_fin_app_acfinal_acarc_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(completion_archive_record_id);

create index ord_ret_fin_app_acfinal_acclo_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(completion_closeout_record_id);

create index ord_ret_fin_app_acfinal_acrecon_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(completion_reconciliation_record_id);

create index ord_ret_fin_app_acfinal_acrep_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(completion_report_record_id);

create index ord_ret_fin_app_acfinal_acaud_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(completion_audit_record_id);

create index ord_ret_fin_app_acfinal_acapp_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(completion_approval_record_id);

create index ord_ret_fin_app_acfinal_acrev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(completion_review_record_id);

create index ord_ret_fin_app_acfinal_acrel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(completion_release_record_id);

create index ord_ret_fin_app_acfinal_acconf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(completion_confirmation_record_id);

create index ord_ret_fin_app_acfinal_acfin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(completion_finalization_record_id);

create index ord_ret_fin_app_acfinal_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(status);

create index ord_ret_fin_app_acfinal_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(completion_final_result);

create index ord_ret_fin_app_acfinal_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(ready_at);

create index ord_ret_fin_app_acfinal_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(requested_at);

create index ord_ret_fin_app_acfinal_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(started_at);

create index ord_ret_fin_app_acfinal_finalized_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(finalized_at);

create index ord_ret_fin_app_acfinal_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_events (
  id bigint generated always as identity primary key,
  completion_final_record_id bigint not null,
  order_id bigint not null,
  completion_archive_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_acfinal_events_record_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_acfinal_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_acfinal_events_acarc_fk
    foreign key (completion_archive_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acarc_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acfinal_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_acfinal_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_acfinal_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_acfinal_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_acfinal_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_events(completion_final_record_id);

create index ord_ret_fin_app_acfinal_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_events(order_id);

create index ord_ret_fin_app_acfinal_events_acarc_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_events(completion_archive_record_id);

create index ord_ret_fin_app_acfinal_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_events(actor_profile_id);

create index ord_ret_fin_app_acfinal_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_events(actor_role);

create index ord_ret_fin_app_acfinal_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_events(event_type);

create index ord_ret_fin_app_acfinal_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_events(previous_status);

create index ord_ret_fin_app_acfinal_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_events(new_status);

create index ord_ret_fin_app_acfinal_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acfinal_events(created_at);
