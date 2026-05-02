-- Migration 049 order retention disposition export delivery finalization approval completion finalization foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion finalization records and finalization event tracking after finalization approval completion confirmation.
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_final_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_status as enum (
      'pending_confirmation',
      'ready_for_finalization',
      'finalization_requested',
      'finalization_in_progress',
      'finalized',
      'finalization_failed',
      'finalization_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_final_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_result as enum (
      'not_finalized',
      'finalized',
      'finalized_with_notes',
      'blocked',
      'needs_confirmation_update',
      'manual_finalization'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_final_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_event as enum (
      'finalization_created',
      'confirmation_attached',
      'finalization_ready',
      'finalization_requested',
      'finalization_started',
      'finalization_completed',
      'finalization_failed',
      'finalization_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_final_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_confirmation_record_id bigint not null,
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
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_status not null default 'pending_confirmation',
  finalization_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_result not null default 'not_finalized',
  finalization_reference text not null,
  finalization_summary text,
  finalization_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  finalized_at timestamptz,
  verified_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_cfin_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_cfin_comp_conf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_cfin_comp_rel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_comp_app_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_comp_rev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_finalized_by_fk
    foreign key (finalized_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_reference_chk check (
    btrim(finalization_reference) <> ''
  ),
  constraint ord_ret_fin_app_cfin_summary_chk check (
    finalization_summary is null or btrim(finalization_summary) <> ''
  ),
  constraint ord_ret_fin_app_cfin_note_chk check (
    finalization_note is null or btrim(finalization_note) <> ''
  ),
  constraint ord_ret_fin_app_cfin_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_cfin_failed_reason_chk check (
    status <> 'finalization_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_cfin_result_status_chk check (
    (
      status in (
        'pending_confirmation',
        'ready_for_finalization',
        'finalization_requested',
        'finalization_in_progress',
        'finalization_cancelled'
      )
      and finalization_result = 'not_finalized'
    )
    or (
      status = 'finalized'
      and finalization_result in (
        'finalized',
        'finalized_with_notes',
        'manual_finalization'
      )
    )
    or (
      status = 'finalization_failed'
      and finalization_result in (
        'blocked',
        'needs_confirmation_update'
      )
    )
  ),
  constraint ord_ret_fin_app_cfin_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_finalization',
      'finalization_requested',
      'finalization_in_progress',
      'finalized',
      'finalization_failed',
      'finalization_cancelled'
    )
  ),
  constraint ord_ret_fin_app_cfin_requested_status_chk check (
    requested_at is null
    or status in (
      'finalization_requested',
      'finalization_in_progress',
      'finalized',
      'finalization_failed',
      'finalization_cancelled'
    )
  ),
  constraint ord_ret_fin_app_cfin_started_status_chk check (
    started_at is null
    or status in (
      'finalization_in_progress',
      'finalized',
      'finalization_failed',
      'finalization_cancelled'
    )
  ),
  constraint ord_ret_fin_app_cfin_finalized_status_chk check (
    finalized_at is null or status = 'finalized'
  ),
  constraint ord_ret_fin_app_cfin_verified_status_chk check (
    verified_at is null or status = 'finalized'
  ),
  constraint ord_ret_fin_app_cfin_failed_status_chk check (
    failed_at is null or status = 'finalization_failed'
  ),
  constraint ord_ret_fin_app_cfin_cancelled_status_chk check (
    cancelled_at is null or status = 'finalization_cancelled'
  ),
  constraint ord_ret_fin_app_cfin_terminal_one_chk check (
    num_nonnulls(finalized_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_cfin_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_cfin_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(finalization_reference);

create unique index ord_ret_fin_app_cfin_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(order_id)
  where status in (
    'pending_confirmation',
    'ready_for_finalization',
    'finalization_requested',
    'finalization_in_progress',
    'finalization_failed'
  );

create index ord_ret_fin_app_cfin_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(order_id);

create index ord_ret_fin_app_cfin_comp_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(completion_confirmation_record_id);

create index ord_ret_fin_app_cfin_comp_rel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(completion_release_record_id);

create index ord_ret_fin_app_cfin_comp_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(completion_approval_record_id);

create index ord_ret_fin_app_cfin_comp_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(completion_review_record_id);

create index ord_ret_fin_app_cfin_completion_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(approval_completion_record_id);

create index ord_ret_fin_app_cfin_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(approval_confirmation_record_id);

create index ord_ret_fin_app_cfin_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(approval_release_record_id);

create index ord_ret_fin_app_cfin_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(finalization_approval_record_id);

create index ord_ret_fin_app_cfin_fin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(finalization_review_record_id);

create index ord_ret_fin_app_cfin_fin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(finalization_record_id);

create index ord_ret_fin_app_cfin_rel_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(review_release_confirmation_record_id);

create index ord_ret_fin_app_cfin_review_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(review_release_record_id);

create index ord_ret_fin_app_cfin_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(approval_record_id);

create index ord_ret_fin_app_cfin_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(review_record_id);

create index ord_ret_fin_app_cfin_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(delivery_record_id);

create index ord_ret_fin_app_cfin_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(export_record_id);

create index ord_ret_fin_app_cfin_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(evidence_record_id);

create index ord_ret_fin_app_cfin_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(requested_by_profile_id);

create index ord_ret_fin_app_cfin_finalized_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(finalized_by_profile_id);

create index ord_ret_fin_app_cfin_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(verified_by_profile_id);

create index ord_ret_fin_app_cfin_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(status);

create index ord_ret_fin_app_cfin_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(finalization_result);

create index ord_ret_fin_app_cfin_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(ready_at);

create index ord_ret_fin_app_cfin_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(requested_at);

create index ord_ret_fin_app_cfin_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(started_at);

create index ord_ret_fin_app_cfin_finalized_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(finalized_at);

create index ord_ret_fin_app_cfin_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(verified_at);

create index ord_ret_fin_app_cfin_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_events (
  id bigint generated always as identity primary key,
  completion_final_record_id bigint not null,
  order_id bigint not null,
  completion_confirmation_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_cfin_events_record_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_cfin_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_cfin_events_comp_conf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_events_actor_profile_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_cfin_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_cfin_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_cfin_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_cfin_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_cfin_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_events(completion_final_record_id);

create index ord_ret_fin_app_cfin_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_events(order_id);

create index ord_ret_fin_app_cfin_events_comp_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_events(completion_confirmation_record_id);

create index ord_ret_fin_app_cfin_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_events(actor_profile_id);

create index ord_ret_fin_app_cfin_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_events(actor_role);

create index ord_ret_fin_app_cfin_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_events(event_type);

create index ord_ret_fin_app_cfin_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_events(previous_status);

create index ord_ret_fin_app_cfin_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_events(new_status);

create index ord_ret_fin_app_cfin_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_events(created_at);
