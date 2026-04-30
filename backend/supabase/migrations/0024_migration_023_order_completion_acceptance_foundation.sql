-- Migration 023 order completion acceptance foundation.
-- Scope: backend-only order completion acceptance records and event tracking after order handover.
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
      and t.typname = 'marketplace_order_completion_acceptance_status'
  ) then
    create type public.marketplace_order_completion_acceptance_status as enum (
      'pending_handover',
      'pending_acceptance',
      'accepted',
      'accepted_with_note',
      'rejected',
      'cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_completion_acceptance_event_type'
  ) then
    create type public.marketplace_order_completion_acceptance_event_type as enum (
      'acceptance_created',
      'handover_attached',
      'acceptance_requested',
      'buyer_accepted',
      'seller_confirmed',
      'accepted_with_note',
      'acceptance_rejected',
      'acceptance_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_completion_acceptance_actor_role'
  ) then
    create type public.marketplace_order_completion_acceptance_actor_role as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_completion_acceptance_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  handover_record_id bigint,
  accepted_by_profile_id bigint,
  status public.marketplace_order_completion_acceptance_status not null default 'pending_handover',
  acceptance_reference text not null,
  buyer_acceptance_required boolean not null default true,
  seller_confirmation_required boolean not null default false,
  accepted_at timestamptz,
  rejected_at timestamptz,
  cancelled_at timestamptz,
  rejection_reason text,
  acceptance_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint completion_acceptance_records_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint completion_acceptance_records_handover_record_id_fk
    foreign key (handover_record_id)
    references public.marketplace_order_handover_records(id)
    on delete set null,

  constraint completion_acceptance_records_accepted_by_profile_id_fk
    foreign key (accepted_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint completion_acceptance_records_reference_nonblank_chk check (
    btrim(acceptance_reference) <> ''
  ),
  constraint completion_acceptance_records_rejection_nonblank_chk check (
    rejection_reason is null or btrim(rejection_reason) <> ''
  ),
  constraint completion_acceptance_records_note_nonblank_chk check (
    acceptance_note is null or btrim(acceptance_note) <> ''
  ),
  constraint completion_acceptance_records_rejected_reason_chk check (
    status <> 'rejected' or rejection_reason is not null
  ),
  constraint completion_acceptance_records_accepted_status_chk check (
    accepted_at is null or status in ('accepted', 'accepted_with_note')
  ),
  constraint completion_acceptance_records_rejected_status_chk check (
    rejected_at is null or status = 'rejected'
  ),
  constraint completion_acceptance_records_cancelled_status_chk check (
    cancelled_at is null or status = 'cancelled'
  ),
  constraint completion_acceptance_records_terminal_exclusive_chk check (
    num_nonnulls(accepted_at, rejected_at, cancelled_at) <= 1
  ),
  constraint completion_acceptance_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index completion_acceptance_records_reference_key
  on public.marketplace_order_completion_acceptance_records(acceptance_reference);

create unique index completion_acceptance_records_one_active_per_order_idx
  on public.marketplace_order_completion_acceptance_records(order_id)
  where status in (
    'pending_handover',
    'pending_acceptance'
  );

create index completion_acceptance_records_order_id_idx
  on public.marketplace_order_completion_acceptance_records(order_id);

create index completion_acceptance_records_handover_record_id_idx
  on public.marketplace_order_completion_acceptance_records(handover_record_id);

create index completion_acceptance_records_accepted_by_profile_id_idx
  on public.marketplace_order_completion_acceptance_records(accepted_by_profile_id);

create index completion_acceptance_records_status_idx
  on public.marketplace_order_completion_acceptance_records(status);

create index completion_acceptance_records_buyer_required_idx
  on public.marketplace_order_completion_acceptance_records(buyer_acceptance_required);

create index completion_acceptance_records_seller_required_idx
  on public.marketplace_order_completion_acceptance_records(seller_confirmation_required);

create index completion_acceptance_records_accepted_at_idx
  on public.marketplace_order_completion_acceptance_records(accepted_at);

create index completion_acceptance_records_rejected_at_idx
  on public.marketplace_order_completion_acceptance_records(rejected_at);

create index completion_acceptance_records_cancelled_at_idx
  on public.marketplace_order_completion_acceptance_records(cancelled_at);

create index completion_acceptance_records_created_at_idx
  on public.marketplace_order_completion_acceptance_records(created_at);

create table public.marketplace_order_completion_acceptance_events (
  id bigint generated always as identity primary key,
  acceptance_record_id bigint not null,
  order_id bigint not null,
  actor_profile_id bigint,
  actor_role public.marketplace_order_completion_acceptance_actor_role not null default 'system',
  event_type public.marketplace_order_completion_acceptance_event_type not null,
  previous_status public.marketplace_order_completion_acceptance_status,
  new_status public.marketplace_order_completion_acceptance_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint completion_acceptance_events_record_id_fk
    foreign key (acceptance_record_id)
    references public.marketplace_order_completion_acceptance_records(id)
    on delete cascade,

  constraint completion_acceptance_events_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint completion_acceptance_events_actor_profile_id_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint completion_acceptance_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint completion_acceptance_events_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint completion_acceptance_events_manual_note_required_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint completion_acceptance_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index completion_acceptance_events_record_id_idx
  on public.marketplace_order_completion_acceptance_events(acceptance_record_id);

create index completion_acceptance_events_order_id_idx
  on public.marketplace_order_completion_acceptance_events(order_id);

create index completion_acceptance_events_actor_profile_id_idx
  on public.marketplace_order_completion_acceptance_events(actor_profile_id);

create index completion_acceptance_events_actor_role_idx
  on public.marketplace_order_completion_acceptance_events(actor_role);

create index completion_acceptance_events_event_type_idx
  on public.marketplace_order_completion_acceptance_events(event_type);

create index completion_acceptance_events_previous_status_idx
  on public.marketplace_order_completion_acceptance_events(previous_status);

create index completion_acceptance_events_new_status_idx
  on public.marketplace_order_completion_acceptance_events(new_status);

create index completion_acceptance_events_created_at_idx
  on public.marketplace_order_completion_acceptance_events(created_at);
