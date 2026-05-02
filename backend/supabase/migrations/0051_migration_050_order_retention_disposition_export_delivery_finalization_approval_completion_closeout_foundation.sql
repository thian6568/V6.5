-- Migration 050 order retention disposition export delivery finalization approval completion closeout foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion closeout records and closeout event tracking after finalization approval completion finalization.
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_close_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_close_status as enum (
      'pending_finalization',
      'ready_for_closeout',
      'closeout_requested',
      'closeout_in_progress',
      'closed_out',
      'closeout_failed',
      'closeout_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_close_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_close_result as enum (
      'not_closed_out',
      'closed_out',
      'closed_out_with_notes',
      'blocked',
      'needs_finalization_update',
      'manual_closeout'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_close_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_close_event as enum (
      'closeout_created',
      'finalization_attached',
      'closeout_ready',
      'closeout_requested',
      'closeout_started',
      'closeout_completed',
      'closeout_failed',
      'closeout_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_close_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_close_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_final_record_id bigint not null,
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
  closed_by_profile_id bigint,
  verified_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_close_status not null default 'pending_finalization',
  closeout_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_close_result not null default 'not_closed_out',
  closeout_reference text not null,
  closeout_summary text,
  closeout_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  closed_at timestamptz,
  verified_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_cclose_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_cclose_final_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_cclose_conf_fk
    foreign key (completion_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_rel_fk
    foreign key (completion_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_app_fk
    foreign key (completion_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_app_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_rev_fk
    foreign key (completion_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_completion_fk
    foreign key (approval_completion_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_completion_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_confirmation_fk
    foreign key (approval_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_confirmation_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_release_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_rel_conf_fk
    foreign key (review_release_confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_closed_by_fk
    foreign key (closed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_reference_chk check (
    btrim(closeout_reference) <> ''
  ),
  constraint ord_ret_fin_app_cclose_summary_chk check (
    closeout_summary is null or btrim(closeout_summary) <> ''
  ),
  constraint ord_ret_fin_app_cclose_note_chk check (
    closeout_note is null or btrim(closeout_note) <> ''
  ),
  constraint ord_ret_fin_app_cclose_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_cclose_failed_reason_chk check (
    status <> 'closeout_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_cclose_result_status_chk check (
    (
      status in (
        'pending_finalization',
        'ready_for_closeout',
        'closeout_requested',
        'closeout_in_progress',
        'closeout_cancelled'
      )
      and closeout_result = 'not_closed_out'
    )
    or (
      status = 'closed_out'
      and closeout_result in (
        'closed_out',
        'closed_out_with_notes',
        'manual_closeout'
      )
    )
    or (
      status = 'closeout_failed'
      and closeout_result in (
        'blocked',
        'needs_finalization_update'
      )
    )
  ),
  constraint ord_ret_fin_app_cclose_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_closeout',
      'closeout_requested',
      'closeout_in_progress',
      'closed_out',
      'closeout_failed',
      'closeout_cancelled'
    )
  ),
  constraint ord_ret_fin_app_cclose_requested_status_chk check (
    requested_at is null
    or status in (
      'closeout_requested',
      'closeout_in_progress',
      'closed_out',
      'closeout_failed',
      'closeout_cancelled'
    )
  ),
  constraint ord_ret_fin_app_cclose_started_status_chk check (
    started_at is null
    or status in (
      'closeout_in_progress',
      'closed_out',
      'closeout_failed',
      'closeout_cancelled'
    )
  ),
  constraint ord_ret_fin_app_cclose_closed_status_chk check (
    closed_at is null or status = 'closed_out'
  ),
  constraint ord_ret_fin_app_cclose_verified_status_chk check (
    verified_at is null or status = 'closed_out'
  ),
  constraint ord_ret_fin_app_cclose_failed_status_chk check (
    failed_at is null or status = 'closeout_failed'
  ),
  constraint ord_ret_fin_app_cclose_cancelled_status_chk check (
    cancelled_at is null or status = 'closeout_cancelled'
  ),
  constraint ord_ret_fin_app_cclose_terminal_one_chk check (
    num_nonnulls(closed_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_cclose_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_cclose_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(closeout_reference);

create unique index ord_ret_fin_app_cclose_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(order_id)
  where status in (
    'pending_finalization',
    'ready_for_closeout',
    'closeout_requested',
    'closeout_in_progress',
    'closeout_failed'
  );

create index ord_ret_fin_app_cclose_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(order_id);

create index ord_ret_fin_app_cclose_final_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(completion_final_record_id);

create index ord_ret_fin_app_cclose_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(completion_confirmation_record_id);

create index ord_ret_fin_app_cclose_rel_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(completion_release_record_id);

create index ord_ret_fin_app_cclose_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(completion_approval_record_id);

create index ord_ret_fin_app_cclose_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(completion_review_record_id);

create index ord_ret_fin_app_cclose_completion_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(approval_completion_record_id);

create index ord_ret_fin_app_cclose_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(approval_confirmation_record_id);

create index ord_ret_fin_app_cclose_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(approval_release_record_id);

create index ord_ret_fin_app_cclose_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(finalization_approval_record_id);

create index ord_ret_fin_app_cclose_fin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(finalization_review_record_id);

create index ord_ret_fin_app_cclose_fin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(finalization_record_id);

create index ord_ret_fin_app_cclose_rel_conf_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(review_release_confirmation_record_id);

create index ord_ret_fin_app_cclose_review_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(review_release_record_id);

create index ord_ret_fin_app_cclose_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(approval_record_id);

create index ord_ret_fin_app_cclose_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(review_record_id);

create index ord_ret_fin_app_cclose_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(delivery_record_id);

create index ord_ret_fin_app_cclose_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(export_record_id);

create index ord_ret_fin_app_cclose_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(evidence_record_id);

create index ord_ret_fin_app_cclose_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(requested_by_profile_id);

create index ord_ret_fin_app_cclose_closed_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(closed_by_profile_id);

create index ord_ret_fin_app_cclose_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(verified_by_profile_id);

create index ord_ret_fin_app_cclose_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(status);

create index ord_ret_fin_app_cclose_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(closeout_result);

create index ord_ret_fin_app_cclose_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(ready_at);

create index ord_ret_fin_app_cclose_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(requested_at);

create index ord_ret_fin_app_cclose_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(started_at);

create index ord_ret_fin_app_cclose_closed_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(closed_at);

create index ord_ret_fin_app_cclose_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(verified_at);

create index ord_ret_fin_app_cclose_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_events (
  id bigint generated always as identity primary key,
  completion_closeout_record_id bigint not null,
  order_id bigint not null,
  completion_final_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_close_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_close_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_close_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_close_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_cclose_events_record_fk
    foreign key (completion_closeout_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_cclose_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_cclose_events_final_fk
    foreign key (completion_final_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_final_records(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_events_actor_profile_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_cclose_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_cclose_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_cclose_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_cclose_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_cclose_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_events(completion_closeout_record_id);

create index ord_ret_fin_app_cclose_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_events(order_id);

create index ord_ret_fin_app_cclose_events_final_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_events(completion_final_record_id);

create index ord_ret_fin_app_cclose_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_events(actor_profile_id);

create index ord_ret_fin_app_cclose_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_events(actor_role);

create index ord_ret_fin_app_cclose_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_events(event_type);

create index ord_ret_fin_app_cclose_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_events(previous_status);

create index ord_ret_fin_app_cclose_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_events(new_status);

create index ord_ret_fin_app_cclose_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_closeout_events(created_at);
