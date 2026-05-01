-- Migration 040 order retention disposition export delivery finalization review foundation.
-- Scope: backend-only order retention disposition export delivery finalization review records and review event tracking after finalization.
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_review_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_review_status as enum (
      'pending_finalization',
      'ready_for_review',
      'review_requested',
      'review_in_progress',
      'reviewed',
      'review_failed',
      'review_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_review_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_review_result as enum (
      'not_reviewed',
      'reviewed',
      'reviewed_with_notes',
      'blocked',
      'needs_finalization_update',
      'manual_review'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_review_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_review_event as enum (
      'review_created',
      'finalization_attached',
      'review_ready',
      'review_requested',
      'review_started',
      'review_completed',
      'review_failed',
      'review_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_review_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_review_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_finalization_review_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  finalization_record_id bigint not null,
  confirmation_record_id bigint,
  release_record_id bigint,
  approval_record_id bigint,
  review_record_id bigint,
  delivery_record_id bigint,
  export_record_id bigint,
  evidence_record_id bigint,
  requested_by_profile_id bigint,
  reviewed_by_profile_id bigint,
  verified_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_review_status not null default 'pending_finalization',
  review_result public.marketplace_order_ret_disp_exp_del_fin_review_result not null default 'not_reviewed',
  review_reference text not null,
  review_summary text,
  review_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  reviewed_at timestamptz,
  verified_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_exp_del_fin_rev_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_exp_del_fin_rev_finalization_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete cascade,

  constraint ord_ret_exp_del_fin_rev_confirmation_fk
    foreign key (confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete set null,

  constraint ord_ret_exp_del_fin_rev_release_fk
    foreign key (release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_exp_del_fin_rev_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_exp_del_fin_rev_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_exp_del_fin_rev_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_exp_del_fin_rev_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_exp_del_fin_rev_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_exp_del_fin_rev_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_exp_del_fin_rev_reviewed_by_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_exp_del_fin_rev_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_exp_del_fin_rev_reference_chk check (
    btrim(review_reference) <> ''
  ),
  constraint ord_ret_exp_del_fin_rev_summary_chk check (
    review_summary is null or btrim(review_summary) <> ''
  ),
  constraint ord_ret_exp_del_fin_rev_note_chk check (
    review_note is null or btrim(review_note) <> ''
  ),
  constraint ord_ret_exp_del_fin_rev_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_exp_del_fin_rev_failed_reason_chk check (
    status <> 'review_failed' or failure_reason is not null
  ),
  constraint ord_ret_exp_del_fin_rev_result_status_chk check (
    (
      status in (
        'pending_finalization',
        'ready_for_review',
        'review_requested',
        'review_in_progress',
        'review_cancelled'
      )
      and review_result = 'not_reviewed'
    )
    or (
      status = 'reviewed'
      and review_result in (
        'reviewed',
        'reviewed_with_notes',
        'manual_review'
      )
    )
    or (
      status = 'review_failed'
      and review_result in (
        'blocked',
        'needs_finalization_update'
      )
    )
  ),
  constraint ord_ret_exp_del_fin_rev_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_review',
      'review_requested',
      'review_in_progress',
      'reviewed',
      'review_failed',
      'review_cancelled'
    )
  ),
  constraint ord_ret_exp_del_fin_rev_requested_status_chk check (
    requested_at is null
    or status in (
      'review_requested',
      'review_in_progress',
      'reviewed',
      'review_failed',
      'review_cancelled'
    )
  ),
  constraint ord_ret_exp_del_fin_rev_started_status_chk check (
    started_at is null
    or status in (
      'review_in_progress',
      'reviewed',
      'review_failed',
      'review_cancelled'
    )
  ),
  constraint ord_ret_exp_del_fin_rev_reviewed_status_chk check (
    reviewed_at is null or status = 'reviewed'
  ),
  constraint ord_ret_exp_del_fin_rev_verified_status_chk check (
    verified_at is null or status = 'reviewed'
  ),
  constraint ord_ret_exp_del_fin_rev_failed_status_chk check (
    failed_at is null or status = 'review_failed'
  ),
  constraint ord_ret_exp_del_fin_rev_cancelled_status_chk check (
    cancelled_at is null or status = 'review_cancelled'
  ),
  constraint ord_ret_exp_del_fin_rev_terminal_one_chk check (
    num_nonnulls(reviewed_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_exp_del_fin_rev_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_exp_del_fin_rev_reference_key
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(review_reference);

create unique index ord_ret_exp_del_fin_rev_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(order_id)
  where status in (
    'pending_finalization',
    'ready_for_review',
    'review_requested',
    'review_in_progress',
    'review_failed'
  );

create index ord_ret_exp_del_fin_rev_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(order_id);

create index ord_ret_exp_del_fin_rev_finalization_id_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(finalization_record_id);

create index ord_ret_exp_del_fin_rev_confirmation_id_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(confirmation_record_id);

create index ord_ret_exp_del_fin_rev_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(release_record_id);

create index ord_ret_exp_del_fin_rev_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(approval_record_id);

create index ord_ret_exp_del_fin_rev_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(review_record_id);

create index ord_ret_exp_del_fin_rev_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(delivery_record_id);

create index ord_ret_exp_del_fin_rev_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(export_record_id);

create index ord_ret_exp_del_fin_rev_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(evidence_record_id);

create index ord_ret_exp_del_fin_rev_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(requested_by_profile_id);

create index ord_ret_exp_del_fin_rev_reviewed_by_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(reviewed_by_profile_id);

create index ord_ret_exp_del_fin_rev_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(verified_by_profile_id);

create index ord_ret_exp_del_fin_rev_status_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(status);

create index ord_ret_exp_del_fin_rev_result_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(review_result);

create index ord_ret_exp_del_fin_rev_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(ready_at);

create index ord_ret_exp_del_fin_rev_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(requested_at);

create index ord_ret_exp_del_fin_rev_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(started_at);

create index ord_ret_exp_del_fin_rev_reviewed_at_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(reviewed_at);

create index ord_ret_exp_del_fin_rev_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(verified_at);

create index ord_ret_exp_del_fin_rev_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_finalization_review_events (
  id bigint generated always as identity primary key,
  finalization_review_record_id bigint not null,
  order_id bigint not null,
  finalization_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_review_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_review_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_review_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_review_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_exp_del_fin_rev_events_record_fk
    foreign key (finalization_review_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_review_records(id)
    on delete cascade,

  constraint ord_ret_exp_del_fin_rev_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_exp_del_fin_rev_events_finalization_fk
    foreign key (finalization_record_id)
    references public.marketplace_order_ret_disp_exp_del_finalization_records(id)
    on delete set null,

  constraint ord_ret_exp_del_fin_rev_events_actor_profile_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_exp_del_fin_rev_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_exp_del_fin_rev_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_exp_del_fin_rev_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_exp_del_fin_rev_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_exp_del_fin_rev_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_events(finalization_review_record_id);

create index ord_ret_exp_del_fin_rev_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_events(order_id);

create index ord_ret_exp_del_fin_rev_events_finalization_id_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_events(finalization_record_id);

create index ord_ret_exp_del_fin_rev_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_events(actor_profile_id);

create index ord_ret_exp_del_fin_rev_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_events(actor_role);

create index ord_ret_exp_del_fin_rev_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_events(event_type);

create index ord_ret_exp_del_fin_rev_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_events(previous_status);

create index ord_ret_exp_del_fin_rev_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_events(new_status);

create index ord_ret_exp_del_fin_rev_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_finalization_review_events(created_at);
