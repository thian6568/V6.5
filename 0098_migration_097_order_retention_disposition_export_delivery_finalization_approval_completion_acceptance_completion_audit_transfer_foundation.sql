-- Migration 096 order retention disposition export delivery finalization approval completion acceptance completion review transfer foundation.
-- Scope: backend-only order retention disposition export delivery finalization approval completion acceptance completion review transfer records and event tracking after completion approval transfer.
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
-- - completion review transfer records are administrative workflow records only.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_status'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_status as enum (
      'pending_completion_approval_transfer',
      'ready_for_completion_review_transfer',
      'completion_review_transfer_requested',
      'completion_review_transfer_in_progress',
      'completion_review_transferred',
      'completion_review_transfer_failed',
      'completion_review_transfer_cancelled'
    );
  end if;

  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_result'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_result as enum (
      'not_transferred',
      'transferred',
      'transferred_with_notes',
      'retention_hold',
      'discrepancy_found',
      'blocked',
      'needs_completion_approval_transfer_update',
      'manual_review_transfer'
    );
  end if;

  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_event'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_event as enum (
      'completion_review_transfer_created',
      'completion_approval_transfer_attached',
      'completion_review_transfer_ready',
      'completion_review_transfer_requested',
      'completion_review_transfer_started',
      'completion_review_transfer_completed',
      'completion_review_transfer_failed',
      'completion_review_transfer_cancelled',
      'retention_hold_recorded',
      'discrepancy_recorded',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_actor'
  ) then
    create type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  completion_approval_transfer_record_id bigint not null,
  completion_release_transfer_record_id bigint,
  completion_confirmation_transfer_record_id bigint,
  completion_transfer_record_id bigint,
  requested_by_profile_id bigint,
  transferred_by_profile_id bigint,
  verified_by_profile_id bigint,
  reviewed_by_profile_id bigint,
  status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_status not null default 'pending_completion_approval_transfer',
  completion_review_transfer_result public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_result not null default 'not_transferred',
  completion_review_transfer_reference text not null,
  completion_review_transfer_summary text,
  completion_review_transfer_note text,
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

  constraint ord_ret_fin_app_acrevtran_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrevtran_acapptran_fk
    foreign key (completion_approval_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapptran_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrevtran_acreltran_fk
    foreign key (completion_release_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acreltran_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrevtran_acctran_fk
    foreign key (completion_confirmation_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acctran_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrevtran_actrans_fk
    foreign key (completion_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_actrans_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrevtran_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrevtran_transferred_by_fk
    foreign key (transferred_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrevtran_verified_by_fk
    foreign key (verified_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrevtran_reviewed_by_fk
    foreign key (reviewed_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrevtran_reference_chk check (
    btrim(completion_review_transfer_reference) <> ''
  ),
  constraint ord_ret_fin_app_acrevtran_failed_reason_chk check (
    status <> 'completion_review_transfer_failed' or failure_reason is not null
  ),
  constraint ord_ret_fin_app_acrevtran_hold_result_chk check (
    completion_review_transfer_result <> 'retention_hold' or retention_hold_note is not null
  ),
  constraint ord_ret_fin_app_acrevtran_discrepancy_result_chk check (
    completion_review_transfer_result <> 'discrepancy_found' or discrepancy_note is not null
  ),
  constraint ord_ret_fin_app_acrevtran_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_fin_app_acrevtran_reference_key
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_records(completion_review_transfer_reference);

create unique index ord_ret_fin_app_acrevtran_one_active_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_records(order_id)
  where status in (
    'pending_completion_approval_transfer',
    'ready_for_completion_review_transfer',
    'completion_review_transfer_requested',
    'completion_review_transfer_in_progress',
    'completion_review_transfer_failed'
  );

create index ord_ret_fin_app_acrevtran_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_records(order_id);

create index ord_ret_fin_app_acrevtran_acapptran_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_records(completion_approval_transfer_record_id);

create index ord_ret_fin_app_acrevtran_status_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_records(status);

create index ord_ret_fin_app_acrevtran_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_records(created_at);

create table public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_events (
  id bigint generated always as identity primary key,
  completion_review_transfer_record_id bigint not null,
  order_id bigint not null,
  completion_approval_transfer_record_id bigint,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_event not null,
  previous_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_status,
  new_status public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_fin_app_acrevtran_events_record_fk
    foreign key (completion_review_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_records(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrevtran_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_fin_app_acrevtran_events_acapptran_fk
    foreign key (completion_approval_transfer_record_id)
    references public.marketplace_order_ret_disp_exp_del_fin_app_comp_acapptran_records(id)
    on delete set null,

  constraint ord_ret_fin_app_acrevtran_events_actor_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_fin_app_acrevtran_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_fin_app_acrevtran_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_fin_app_acrevtran_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_fin_app_acrevtran_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_fin_app_acrevtran_events_record_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_events(completion_review_transfer_record_id);

create index ord_ret_fin_app_acrevtran_events_order_id_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_events(order_id);

create index ord_ret_fin_app_acrevtran_events_event_type_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_events(event_type);

create index ord_ret_fin_app_acrevtran_events_created_at_idx
  on public.marketplace_order_ret_disp_exp_del_fin_app_comp_acrevtran_events(created_at);
