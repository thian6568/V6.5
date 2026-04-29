-- Migration 004 financial flows.
-- Scope: escrow_records, subscriptions, refund_requests, disputes.
-- Guardrails:
-- - escrow state is separate from orders.
-- - shipping/insurance are not part of this migration.
-- - artworks remains the single artwork identity path.

-- Dispute model:
-- - order_id is required (order-level baseline).
-- - artwork_id is nullable to support order-level disputes.
-- - when artwork_id is present, (order_id, artwork_id) must exist in order_items.

-- Enums required for Migration 004.
do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'escrow_status'
  ) then
    create type public.escrow_status as enum ('pending', 'held', 'partially_released', 'released', 'disputed', 'cancelled');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'subscription_status'
  ) then
    create type public.subscription_status as enum ('active', 'trial', 'past_due', 'cancelled', 'expired');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'refund_status'
  ) then
    create type public.refund_status as enum ('requested', 'under_review', 'approved', 'rejected', 'processed');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'dispute_type'
  ) then
    create type public.dispute_type as enum ('authenticity', 'shipping_damage', 'lost_shipment', 'non_delivery', 'other');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'dispute_status'
  ) then
    create type public.dispute_status as enum ('open', 'under_review', 'resolved', 'rejected', 'closed');
  end if;
end
$$;

create table public.escrow_records (
  id bigint generated always as identity primary key,
  order_id bigint not null unique references public.orders(id) on delete restrict,
  status public.escrow_status not null default 'pending',
  amount numeric(12, 2) not null,
  currency_code char(3) not null default 'USD',
  held_at timestamptz,
  released_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint escrow_records_amount_nonnegative_chk check (amount >= 0),
  constraint escrow_records_currency_code_upper_chk check (currency_code = upper(currency_code)),
  constraint escrow_records_released_after_held_chk check (
    released_at is null or held_at is null or released_at >= held_at
  )
);

create index escrow_records_status_idx on public.escrow_records(status);

create table public.subscriptions (
  id bigint generated always as identity primary key,
  profile_id bigint not null references public.profiles(id) on delete restrict,
  status public.subscription_status not null default 'trial',
  plan_code text not null,
  started_at timestamptz not null default now(),
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subscriptions_plan_code_nonempty_chk check (length(trim(plan_code)) > 0),
  constraint subscriptions_period_order_chk check (
    current_period_end is null or current_period_start is null or current_period_end >= current_period_start
  )
);

create index subscriptions_profile_id_idx on public.subscriptions(profile_id);
create index subscriptions_status_idx on public.subscriptions(status);
create unique index subscriptions_one_active_per_profile_idx
  on public.subscriptions(profile_id)
  where status in ('active', 'trial', 'past_due');

create table public.refund_requests (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete restrict,
  requester_profile_id bigint not null references public.profiles(id) on delete restrict,
  reviewed_by_profile_id bigint references public.profiles(id) on delete set null,
  status public.refund_status not null default 'requested',
  reason text not null,
  requested_amount numeric(12, 2) not null,
  decision_notes text,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint refund_requests_reason_nonempty_chk check (length(trim(reason)) > 0),
  constraint refund_requests_amount_nonnegative_chk check (requested_amount >= 0),
  constraint refund_requests_reviewed_after_requested_chk check (reviewed_at is null or reviewed_at >= requested_at)
);

create index refund_requests_order_id_idx on public.refund_requests(order_id);
create index refund_requests_requester_profile_id_idx on public.refund_requests(requester_profile_id);
create index refund_requests_status_idx on public.refund_requests(status);

create table public.disputes (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete restrict,
  artwork_id bigint references public.artworks(id) on delete restrict,
  opened_by_profile_id bigint not null references public.profiles(id) on delete restrict,
  assigned_admin_profile_id bigint references public.profiles(id) on delete set null,
  dispute_type public.dispute_type not null,
  status public.dispute_status not null default 'open',
  title text not null,
  description text,
  opened_at timestamptz not null default now(),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint disputes_title_nonempty_chk check (length(trim(title)) > 0),
  constraint disputes_resolved_after_opened_chk check (resolved_at is null or resolved_at >= opened_at),
  constraint disputes_authenticity_requires_artwork_chk check (
    dispute_type <> 'authenticity' or artwork_id is not null
  ),
  constraint disputes_order_item_artwork_fk
    foreign key (order_id, artwork_id)
    references public.order_items(order_id, artwork_id)
    on delete restrict
);

create index disputes_order_id_idx on public.disputes(order_id);
create index disputes_artwork_id_idx on public.disputes(artwork_id);
create index disputes_opened_by_profile_id_idx on public.disputes(opened_by_profile_id);
create index disputes_assigned_admin_profile_id_idx on public.disputes(assigned_admin_profile_id);
create index disputes_type_status_idx on public.disputes(dispute_type, status);
