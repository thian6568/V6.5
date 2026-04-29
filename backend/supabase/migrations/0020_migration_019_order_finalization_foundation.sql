-- Migration 019 order finalization foundation.
-- Scope: backend-only order finalization status and event tracking after checkout-to-order draft conversion.
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
      and t.typname = 'marketplace_order_finalization_status'
  ) then
    create type public.marketplace_order_finalization_status as enum (
      'pending',
      'ready_for_review',
      'finalization_in_progress',
      'finalized',
      'finalization_failed',
      'cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_finalization_event_type'
  ) then
    create type public.marketplace_order_finalization_event_type as enum (
      'finalization_requested',
      'finalization_started',
      'finalization_succeeded',
      'finalization_failed',
      'finalization_cancelled',
      'note_added'
    );
  end if;
end
$$;

create table public.marketplace_order_finalizations (
  id bigint generated always as identity primary key,
  order_draft_id bigint not null references public.marketplace_order_drafts(id),
  order_id bigint references public.orders(id),
  buyer_profile_id bigint not null references public.profiles(id),
  status public.marketplace_order_finalization_status not null default 'pending',
  currency_code text not null,
  subtotal_amount numeric(12,2) not null default 0,
  shipping_amount numeric(12,2) not null default 0,
  tax_amount numeric(12,2) not null default 0,
  insurance_amount numeric(12,2) not null default 0,
  discount_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null default 0,
  ready_for_review_at timestamptz,
  finalization_requested_at timestamptz,
  finalized_at timestamptz,
  finalization_failed_at timestamptz,
  cancellation_at timestamptz,
  failure_reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_order_finalizations_currency_code_chk check (
    currency_code ~ '^[A-Z]{3}$'
  ),
  constraint marketplace_order_finalizations_subtotal_nonnegative_chk check (
    subtotal_amount >= 0
  ),
  constraint marketplace_order_finalizations_shipping_nonnegative_chk check (
    shipping_amount >= 0
  ),
  constraint marketplace_order_finalizations_tax_nonnegative_chk check (
    tax_amount >= 0
  ),
  constraint marketplace_order_finalizations_insurance_nonnegative_chk check (
    insurance_amount >= 0
  ),
  constraint marketplace_order_finalizations_discount_nonnegative_chk check (
    discount_amount >= 0
  ),
  constraint marketplace_order_finalizations_total_nonnegative_chk check (
    total_amount >= 0
  ),
  constraint marketplace_order_finalizations_discount_bound_chk check (
    discount_amount <= subtotal_amount + shipping_amount + tax_amount + insurance_amount
  ),
  constraint marketplace_order_finalizations_total_consistency_chk check (
    total_amount = subtotal_amount + shipping_amount + tax_amount + insurance_amount - discount_amount
  ),
  constraint marketplace_order_finalizations_finalized_status_timestamp_chk check (
    finalized_at is null or status = 'finalized'
  ),
  constraint marketplace_order_finalizations_failed_status_timestamp_chk check (
    finalization_failed_at is null or status = 'finalization_failed'
  ),
  constraint marketplace_order_finalizations_cancelled_status_timestamp_chk check (
    cancellation_at is null or status = 'cancelled'
  ),
  constraint marketplace_order_finalizations_order_id_finalized_chk check (
    order_id is null or status = 'finalized'
  ),
  constraint marketplace_order_finalizations_terminal_timestamps_exclusive_chk check (
    num_nonnulls(finalized_at, finalization_failed_at, cancellation_at) <= 1
  ),
  constraint marketplace_order_finalizations_failure_reason_nonblank_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint marketplace_order_finalizations_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index marketplace_order_finalizations_one_active_per_order_draft_idx
  on public.marketplace_order_finalizations(order_draft_id)
  where status in ('pending', 'ready_for_review', 'finalization_in_progress');

create index marketplace_order_finalizations_order_draft_id_idx
  on public.marketplace_order_finalizations(order_draft_id);

create index marketplace_order_finalizations_order_id_idx
  on public.marketplace_order_finalizations(order_id);

create index marketplace_order_finalizations_buyer_profile_id_idx
  on public.marketplace_order_finalizations(buyer_profile_id);

create index marketplace_order_finalizations_status_idx
  on public.marketplace_order_finalizations(status);

create index marketplace_order_finalizations_created_at_idx
  on public.marketplace_order_finalizations(created_at);

create index marketplace_order_finalizations_finalization_requested_at_idx
  on public.marketplace_order_finalizations(finalization_requested_at);

create index marketplace_order_finalizations_finalized_at_idx
  on public.marketplace_order_finalizations(finalized_at);

create table public.marketplace_order_finalization_events (
  id bigint generated always as identity primary key,
  order_finalization_id bigint not null references public.marketplace_order_finalizations(id) on delete cascade,
  actor_profile_id bigint references public.profiles(id) on delete set null,
  event_type public.marketplace_order_finalization_event_type not null,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint marketplace_order_finalization_events_event_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint marketplace_order_finalization_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index marketplace_order_finalization_events_order_finalization_id_idx
  on public.marketplace_order_finalization_events(order_finalization_id);

create index marketplace_order_finalization_events_actor_profile_id_idx
  on public.marketplace_order_finalization_events(actor_profile_id);

create index marketplace_order_finalization_events_event_type_idx
  on public.marketplace_order_finalization_events(event_type);

create index marketplace_order_finalization_events_created_at_idx
  on public.marketplace_order_finalization_events(created_at);
