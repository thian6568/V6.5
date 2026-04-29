-- Migration 005 logistics tables.
-- Scope: shipping_records, insurance_records.
-- Guardrails:
-- - logistics state is separate from order / escrow / refund / dispute states.
-- - no environment assignment logic is included in this migration.
-- - artworks remains the single artwork identity path.

-- Enums required for Migration 005.
do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'shipping_status'
  ) then
    create type public.shipping_status as enum ('pending', 'prepared', 'shipped', 'delivered', 'returned', 'lost');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'insurance_status'
  ) then
    create type public.insurance_status as enum ('not_selected', 'selected', 'active', 'claimed', 'closed');
  end if;
end
$$;

create table public.shipping_records (
  id bigint generated always as identity primary key,
  order_id bigint not null unique references public.orders(id) on delete restrict,
  status public.shipping_status not null default 'pending',
  carrier text,
  tracking_number text,
  shipped_at timestamptz,
  delivered_at timestamptz,
  address_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shipping_records_tracking_nonempty_chk check (tracking_number is null or length(trim(tracking_number)) > 0),
  constraint shipping_records_delivered_after_shipped_chk check (
    delivered_at is null or shipped_at is null or delivered_at >= shipped_at
  )
);

create index shipping_records_status_idx on public.shipping_records(status);
create index shipping_records_tracking_number_idx on public.shipping_records(tracking_number);

create table public.insurance_records (
  id bigint generated always as identity primary key,
  order_id bigint not null unique references public.orders(id) on delete restrict,
  status public.insurance_status not null default 'not_selected',
  provider text,
  policy_number text,
  coverage_amount numeric(12, 2),
  premium_amount numeric(12, 2),
  claimed_at timestamptz,
  closed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint insurance_records_policy_nonempty_chk check (policy_number is null or length(trim(policy_number)) > 0),
  constraint insurance_records_coverage_nonnegative_chk check (coverage_amount is null or coverage_amount >= 0),
  constraint insurance_records_premium_nonnegative_chk check (premium_amount is null or premium_amount >= 0),
  constraint insurance_records_closed_after_claimed_chk check (
    closed_at is null or claimed_at is null or closed_at >= claimed_at
  )
);

create index insurance_records_status_idx on public.insurance_records(status);
create index insurance_records_policy_number_idx on public.insurance_records(policy_number);
