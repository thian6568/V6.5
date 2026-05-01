-- Migration 038 order retention disposition export delivery review release confirmation foundation.
-- Scope: backend-only order retention disposition export delivery review release confirmation records and confirmation event tracking after release.
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
      and t.typname = 'marketplace_order_ret_disp_exp_del_rev_rel_conf_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_rev_rel_conf_status as enum (
      'pending_release',
      'ready_for_confirmation',
      'confirmation_requested',
      'confirmation_in_progress',
      'confirmed',
      'confirmation_failed',
      'confirmation_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_rev_rel_conf_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_rev_rel_conf_result as enum (
      'not_confirmed',
      'confirmed',
      'confirmed_with_notes',
      'blocked',
      'needs_release_update',
      'manual_confirmation'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_rev_rel_conf_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_rev_rel_conf_event as enum (
      'confirmation_created',
      'release_attached',
      'confirmation_ready',
      'confirmation_requested',
      'confirmation_started',
      'confirmation_completed',
      'confirmation_failed',
      'confirmation_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_rev_rel_conf_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_rev_rel_conf_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  release_record_id bigint not null,
  approval_record_id bigint,
  review_record_id bigint,
  delivery_record_id bigint,
  export_record_id bigint,
  evidence_record_id bigint,
  requested_by_profile_id bigint,
  confirmed_by_profile_id bigint,
  verified_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_rev_rel_conf_status not null default 'pending_release',
  confirmation_result public.marketplace_order_ret_disp_exp_del_rev_rel_conf_result not null default 'not_confirmed',
  confirmation_reference text not null,
  confirmation_summary text,
  confirmation_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  started_at timestamptz,
  confirmed_at timestamptz,
  verified_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_disp_exp_del_rev_rel_conf_records_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_disp_exp_del_rev_rel_conf_records_release_fk
    foreign key (release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete cascade,

  constraint ord_ret_disp_exp_del_rev_rel_conf_records_approval_fk
    foreign key (approval_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_approval_records(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_rel_conf_records_review_fk
    foreign key (review_record_id)
    references public.marketplace_order_ret_disp_export_delivery_review_records(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_rel_conf_records_delivery_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_rel_conf_records_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_rel_conf_records_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_rel_conf_records_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_rel_conf_records_confirmed_by_fk
    foreign key (confirmed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_rel_conf_records_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_rel_conf_records_reference_chk check (
    btrim(confirmation_reference) <> ''
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_records_summary_chk check (
    confirmation_summary is null or btrim(confirmation_summary) <> ''
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_records_note_chk check (
    confirmation_note is null or btrim(confirmation_note) <> ''
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_records_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_records_failed_reason_chk check (
    status <> 'confirmation_failed' or failure_reason is not null
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_records_result_status_chk check (
    (
      status in (
        'pending_release',
        'ready_for_confirmation',
        'confirmation_requested',
        'confirmation_in_progress',
        'confirmation_cancelled'
      )
      and confirmation_result = 'not_confirmed'
    )
    or (
      status = 'confirmed'
      and confirmation_result in (
        'confirmed',
        'confirmed_with_notes',
        'manual_confirmation'
      )
    )
    or (
      status = 'confirmation_failed'
      and confirmation_result in (
        'blocked',
        'needs_release_update'
      )
    )
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_records_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_confirmation',
      'confirmation_requested',
      'confirmation_in_progress',
      'confirmed',
      'confirmation_failed',
      'confirmation_cancelled'
    )
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_records_requested_status_chk check (
    requested_at is null
    or status in (
      'confirmation_requested',
      'confirmation_in_progress',
      'confirmed',
      'confirmation_failed',
      'confirmation_cancelled'
    )
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_records_started_status_chk check (
    started_at is null
    or status in (
      'confirmation_in_progress',
      'confirmed',
      'confirmation_failed',
      'confirmation_cancelled'
    )
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_records_confirmed_status_chk check (
    confirmed_at is null or status = 'confirmed'
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_records_verified_status_chk check (
    verified_at is null or status = 'confirmed'
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_records_failed_status_chk check (
    failed_at is null or status = 'confirmation_failed'
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_records_cancelled_status_chk check (
    cancelled_at is null or status = 'confirmation_cancelled'
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_records_terminal_one_chk check (
    num_nonnulls(confirmed_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_disp_exp_del_rev_rel_conf_records_reference_key
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(confirmation_reference);

create unique index ord_ret_disp_exp_del_rev_rel_conf_records_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(order_id)
  where status in (
    'pending_release',
    'ready_for_confirmation',
    'confirmation_requested',
    'confirmation_in_progress',
    'confirmation_failed'
  );

create index ord_ret_disp_exp_del_rev_rel_conf_records_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(order_id);

create index ord_ret_disp_exp_del_rev_rel_conf_records_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(release_record_id);

create index ord_ret_disp_exp_del_rev_rel_conf_records_approval_id_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(approval_record_id);

create index ord_ret_disp_exp_del_rev_rel_conf_records_review_id_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(review_record_id);

create index ord_ret_disp_exp_del_rev_rel_conf_records_delivery_id_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(delivery_record_id);

create index ord_ret_disp_exp_del_rev_rel_conf_records_export_id_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(export_record_id);

create index ord_ret_disp_exp_del_rev_rel_conf_records_evidence_id_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(evidence_record_id);

create index ord_ret_disp_exp_del_rev_rel_conf_records_requested_by_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(requested_by_profile_id);

create index ord_ret_disp_exp_del_rev_rel_conf_records_confirmed_by_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(confirmed_by_profile_id);

create index ord_ret_disp_exp_del_rev_rel_conf_records_verified_by_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(verified_by_profile_id);

create index ord_ret_disp_exp_del_rev_rel_conf_records_status_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(status);

create index ord_ret_disp_exp_del_rev_rel_conf_records_result_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(confirmation_result);

create index ord_ret_disp_exp_del_rev_rel_conf_records_ready_at_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(ready_at);

create index ord_ret_disp_exp_del_rev_rel_conf_records_requested_at_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(requested_at);

create index ord_ret_disp_exp_del_rev_rel_conf_records_started_at_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(started_at);

create index ord_ret_disp_exp_del_rev_rel_conf_records_confirmed_at_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(confirmed_at);

create index ord_ret_disp_exp_del_rev_rel_conf_records_verified_at_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(verified_at);

create index ord_ret_disp_exp_del_rev_rel_conf_records_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_events (
  id bigint generated always as identity primary key,
  confirmation_record_id bigint not null,
  order_id bigint not null,
  release_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_rev_rel_conf_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_rev_rel_conf_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_rev_rel_conf_status,
  new_status public.marketplace_order_ret_disp_exp_del_rev_rel_conf_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_disp_exp_del_rev_rel_conf_events_record_fk
    foreign key (confirmation_record_id)
    references public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_records(id)
    on delete cascade,

  constraint ord_ret_disp_exp_del_rev_rel_conf_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_disp_exp_del_rev_rel_conf_events_release_fk
    foreign key (release_record_id)
    references public.marketplace_order_ret_disp_exp_del_review_release_records(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_rel_conf_events_actor_profile_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_rev_rel_conf_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_disp_exp_del_rev_rel_conf_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_disp_exp_del_rev_rel_conf_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_events(confirmation_record_id);

create index ord_ret_disp_exp_del_rev_rel_conf_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_events(order_id);

create index ord_ret_disp_exp_del_rev_rel_conf_events_release_id_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_events(release_record_id);

create index ord_ret_disp_exp_del_rev_rel_conf_events_actor_profile_id_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_events(actor_profile_id);

create index ord_ret_disp_exp_del_rev_rel_conf_events_actor_role_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_events(actor_role);

create index ord_ret_disp_exp_del_rev_rel_conf_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_events(event_type);

create index ord_ret_disp_exp_del_rev_rel_conf_events_previous_status_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_events(previous_status);

create index ord_ret_disp_exp_del_rev_rel_conf_events_new_status_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_events(new_status);

create index ord_ret_disp_exp_del_rev_rel_conf_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_rev_rel_confirm_events(created_at);
