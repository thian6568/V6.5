-- Migration 042 order retention disposition export delivery finalization approval release foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval release records and release event tracking after finalization approval.
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_rel_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_rel_status as enum (
      'pending_approval',
      'ready_for_release',
      'release_requested',
      'release_in_progress',
      'released',
      'release_failed',
      'release_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_rel_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_rel_result as enum (
      'not_released',
      'released',
      'released_with_notes',
      'blocked',
      'needs_approval_update',
      'manual_release'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_rel_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_rel_event as enum (
      'release_created',
      'approval_attached',
      'release_ready',
      'release_requested',
      'release_started',
      'release_completed',
      'release_failed',
      'release_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_rel_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_rel_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_release_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  finalization_approval_record_id bigint not null,
  finalization_review_record_id bigint,
  finalization_record_id bigint,
  confirmation_record_id bigint,
  review_release_record_id bigint,
  approval_record_id bigint,
  review_record_id bigint,
  delivery_record_id bigint,
  export_record_id bigint,
  evidence_record_id bigint,
  requested_by_profile_id bigint,
  released_by_profile_id bigint,
  verified_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_rel_status not null default 'pending_approval',
  release_result public.marketplace_order_ret_disp_exp_del_fin_app_rel_result not null default 'not_released',
  release_reference text not null,
  release_summary text,
  release_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  released_at timestamptz,
  verified_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_fin_app_rel_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_rel_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_rel_fin_rev_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_rel_fin_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_fin_app_rel_confirmation_fk
    foreign key (confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_fin_app_rel_review_release_fk
    foreign key (review_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_fin_app_rel_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_rel_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_fin_app_rel_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_fin_app_rel_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_fin_app_rel_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_fin_app_rel_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_rel_released_by_fk
    foreign key (released_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_rel_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_rel_reference_chk check (
    btrim(release_reference) <> ''
  ),
  constraint ord_ret_fin_app_rel_summary_chk check (
    release_summary is null or btrim(release_summary) <> ''
  ),
  constraint ord_ret_fin_app_rel_note_chk check (
    release_note is null or btrim(release_note) <> ''
  ),
  constraint ord_ret_fin_app_rel_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_fin_app_rel_failed_reason_chk check (
    status <> 'release_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_rel_result_status_chk check (
    (
      status in (
        'pending_approval',
        'ready_for_release',
        'release_requested',
        'release_in_progress',
        'release_cancelled'
      )
      and release_result = 'not_released'
    )
    or (
      status = 'released'
      and release_result in (
        'released',
        'released_with_notes',
        'manual_release'
      )
    )
    or (
      status = 'release_failed'
      and release_result in (
        'blocked',
        'needs_approval_update'
      )
    )
  ),
  constraint ord_ret_fin_app_rel_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_release',
      'release_requested',
      'release_in_progress',
      'released',
      'release_failed',
      'release_cancelled'
    )
  ),
  constraint ord_ret_fin_app_rel_requested_status_chk check (
    requested_at is null
    or status in (
      'release_requested',
      'release_in_progress',
      'released',
      'release_failed',
      'release_cancelled'
    )
  ),
  constraint ord_ret_fin_app_rel_started_status_chk check (
    started_at is null
    or status in (
      'release_in_progress',
      'released',
      'release_failed',
      'release_cancelled'
    )
  ),
  constraint ord_ret_fin_app_rel_released_status_chk check (
    released_at is null or status = 'released'
  ),
  constraint ord_ret_fin_app_rel_verified_status_chk check (
    verified_at is null or status = 'released'
  ),
  constraint ord_ret_fin_app_rel_failed_status_chk check (
    failed_at is null or status = 'release_failed'
  ),
  constraint ord_ret_fin_app_rel_cancelled_status_chk check (
    cancelled_at is null or status = 'release_cancelled'
  ),
  constraint ord_ret_fin_app_rel_terminal_one_chk check (
    num_nonnulls(released_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_fin_app_rel_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_rel_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(release_reference);

create unique index ord_ret_fin_app_rel_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(order_id)
  where status in (
    'pending_approval',
    'ready_for_release',
    'release_requested',
    'release_in_progress',
    'release_failed'
  );

create index ord_ret_fin_app_rel_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(order_id);

create index ord_ret_fin_app_rel_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(finalization_approval_record_id);

create index ord_ret_fin_app_rel_fin_rev_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(finalization_review_record_id);

create index ord_ret_fin_app_rel_fin_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(finalization_record_id);

create index ord_ret_fin_app_rel_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(confirmation_record_id);

create index ord_ret_fin_app_rel_review_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(review_release_record_id);

create index ord_ret_fin_app_rel_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(approval_record_id);

create index ord_ret_fin_app_rel_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(review_record_id);

create index ord_ret_fin_app_rel_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(delivery_record_id);

create index ord_ret_fin_app_rel_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(export_record_id);

create index ord_ret_fin_app_rel_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(evidence_record_id);

create index ord_ret_fin_app_rel_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(requested_by_profile_id);

create index ord_ret_fin_app_rel_released_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(released_by_profile_id);

create index ord_ret_fin_app_rel_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(verified_by_profile_id);

create index ord_ret_fin_app_rel_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(status);

create index ord_ret_fin_app_rel_result_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(release_result);

create index ord_ret_fin_app_rel_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(ready_at);

create index ord_ret_fin_app_rel_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(requested_at);

create index ord_ret_fin_app_rel_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(started_at);

create index ord_ret_fin_app_rel_released_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(released_at);

create index ord_ret_fin_app_rel_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(verified_at);

create index ord_ret_fin_app_rel_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_release_events (
  id bigint generated always as identity primary key,
  approval_release_record_id bigint not null,
  order_id bigint not null,
  finalization_approval_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_rel_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_rel_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_rel_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_rel_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_rel_events_record_fk
    foreign key (approval_release_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_release_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_rel_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_rel_events_fin_app_fk
    foreign key (finalization_approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_approval_records(id)
    on delete set null,

  constraint ord_ret_fin_app_rel_events_actor_profile_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_rel_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_rel_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_rel_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_rel_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_rel_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_events(approval_release_record_id);

create index ord_ret_fin_app_rel_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_events(order_id);

create index ord_ret_fin_app_rel_events_fin_app_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_events(finalization_approval_record_id);

create index ord_ret_fin_app_rel_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_events(actor_profile_id);

create index ord_ret_fin_app_rel_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_events(actor_role);

create index ord_ret_fin_app_rel_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_events(event_type);

create index ord_ret_fin_app_rel_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_events(previous_status);

create index ord_ret_fin_app_rel_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_events(new_status);

create index ord_ret_fin_app_rel_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_release_events(created_at);
