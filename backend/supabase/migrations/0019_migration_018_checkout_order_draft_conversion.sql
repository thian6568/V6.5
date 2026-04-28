-- Migration 018 checkout order draft and conversion foundation.
-- Scope: checkout-to-order draft preparation and conversion tracking.
-- Guardrails:
-- - artworks remains the single artwork identity path.
-- - no second artwork table or upload identity path.
-- - no coupling to environments or homepage/admin content logic.
-- - backend foundation only; no frontend/UI implementation.
-- - no AI, bots, or agents.
-- - no payment capture.
-- - no escrow release logic.
-- - no crypto.
-- - no live shipping execution.
-- - no real tax calculation execution.
-- - no payment gateway integration.
-- - do not replace existing public.orders or public.order_items.
-- - public.orders remains the final canonical order table.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_draft_status'
  ) then
    create type public.marketplace_order_draft_status as enum (
      'draft',
      'ready_for_conversion',
      'conversion_in_progress',
      'converted',
      'conversion_failed',
      'cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_conversion_event_type'
  ) then
    create type public.marketplace_order_conversion_event_type as enum (
      'conversion_requested',
      'conversion_started',
      'conversion_succeeded',
      'conversion_failed',
      'conversion_cancelled',
      'note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_draft_item_source_type'
  ) then
    create type public.marketplace_order_draft_item_source_type as enum (
      'invoice_draft_item',
      'checkout_intent_item',
      'manual_adjustment'
    );
  end if;
end
$$;

create table public.marketplace_order_drafts (
  id bigint generated always as identity primary key,
  checkout_intent_id bigint not null references public.marketplace_checkout_intents(id),
  invoice_draft_id bigint references public.marketplace_invoice_drafts(id),
  buyer_profile_id bigint not null references public.profiles(id),
  status public.marketplace_order_draft_status not null default 'draft',
  currency_code text not null,
  subtotal_amount numeric(12,2) not null default 0,
  shipping_amount numeric(12,2) not null default 0,
  tax_amount numeric(12,2) not null default 0,
  insurance_amount numeric(12,2) not null default 0,
  discount_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null default 0,
  target_order_id bigint references public.orders(id),
  conversion_requested_at timestamptz,
  converted_at timestamptz,
  conversion_failed_at timestamptz,
  cancellation_at timestamptz,
  failure_reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_order_drafts_currency_code_chk check (
    currency_code ~ '^[A-Z]{3}$'
  ),
  constraint marketplace_order_drafts_subtotal_nonnegative_chk check (
    subtotal_amount >= 0
  ),
  constraint marketplace_order_drafts_shipping_nonnegative_chk check (
    shipping_amount >= 0
  ),
  constraint marketplace_order_drafts_tax_nonnegative_chk check (
    tax_amount >= 0
  ),
  constraint marketplace_order_drafts_insurance_nonnegative_chk check (
    insurance_amount >= 0
  ),
  constraint marketplace_order_drafts_discount_nonnegative_chk check (
    discount_amount >= 0
  ),
  constraint marketplace_order_drafts_total_nonnegative_chk check (
    total_amount >= 0
  ),
  constraint marketplace_order_drafts_discount_bound_chk check (
    discount_amount <= subtotal_amount + shipping_amount + tax_amount + insurance_amount
  ),
  constraint marketplace_order_drafts_total_consistency_chk check (
    total_amount = subtotal_amount + shipping_amount + tax_amount + insurance_amount - discount_amount
  ),
  constraint marketplace_order_drafts_converted_status_timestamp_chk check (
    converted_at is null or status = 'converted'
  ),
  constraint marketplace_order_drafts_failed_status_timestamp_chk check (
    conversion_failed_at is null or status = 'conversion_failed'
  ),
  constraint marketplace_order_drafts_cancelled_status_timestamp_chk check (
    cancellation_at is null or status = 'cancelled'
  ),
  constraint marketplace_order_drafts_terminal_timestamps_exclusive_chk check (
    num_nonnulls(converted_at, conversion_failed_at, cancellation_at) <= 1
  ),
  constraint marketplace_order_drafts_failure_reason_nonblank_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint marketplace_order_drafts_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index marketplace_order_drafts_one_active_per_checkout_intent_idx
  on public.marketplace_order_drafts(checkout_intent_id)
  where status in ('draft', 'ready_for_conversion', 'conversion_in_progress');

create index marketplace_order_drafts_checkout_intent_id_idx
  on public.marketplace_order_drafts(checkout_intent_id);

create index marketplace_order_drafts_invoice_draft_id_idx
  on public.marketplace_order_drafts(invoice_draft_id);

create index marketplace_order_drafts_buyer_profile_id_idx
  on public.marketplace_order_drafts(buyer_profile_id);

create index marketplace_order_drafts_target_order_id_idx
  on public.marketplace_order_drafts(target_order_id);

create index marketplace_order_drafts_status_idx
  on public.marketplace_order_drafts(status);

create index marketplace_order_drafts_created_at_idx
  on public.marketplace_order_drafts(created_at);

create index marketplace_order_drafts_conversion_requested_at_idx
  on public.marketplace_order_drafts(conversion_requested_at);

create index marketplace_order_drafts_converted_at_idx
  on public.marketplace_order_drafts(converted_at);

create table public.marketplace_order_draft_items (
  id bigint generated always as identity primary key,
  order_draft_id bigint not null references public.marketplace_order_drafts(id) on delete cascade,
  source_type public.marketplace_order_draft_item_source_type not null,
  invoice_draft_item_id bigint references public.marketplace_invoice_draft_items(id),
  checkout_intent_item_id bigint references public.marketplace_checkout_intent_items(id),
  description text not null,
  quantity integer not null default 1,
  unit_amount numeric(12,2) not null default 0,
  line_amount numeric(12,2) not null default 0,
  sort_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint marketplace_order_draft_items_description_nonblank_chk check (
    btrim(description) <> ''
  ),
  constraint marketplace_order_draft_items_quantity_positive_chk check (
    quantity > 0
  ),
  constraint marketplace_order_draft_items_unit_amount_nonnegative_chk check (
    unit_amount >= 0
  ),
  constraint marketplace_order_draft_items_line_amount_nonnegative_chk check (
    line_amount >= 0
  ),
  constraint marketplace_order_draft_items_line_amount_consistency_chk check (
    line_amount = unit_amount * quantity
  ),
  constraint marketplace_order_draft_items_sort_order_nonnegative_chk check (
    sort_order >= 0
  ),
  constraint marketplace_order_draft_items_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  ),
  constraint marketplace_order_draft_items_source_mapping_chk check (
    (
      source_type = 'invoice_draft_item'
      and invoice_draft_item_id is not null
      and checkout_intent_item_id is null
    )
    or
    (
      source_type = 'checkout_intent_item'
      and invoice_draft_item_id is null
      and checkout_intent_item_id is not null
    )
    or
    (
      source_type = 'manual_adjustment'
      and invoice_draft_item_id is null
      and checkout_intent_item_id is null
    )
  )
);

create index marketplace_order_draft_items_order_draft_id_idx
  on public.marketplace_order_draft_items(order_draft_id);

create index marketplace_order_draft_items_invoice_draft_item_id_idx
  on public.marketplace_order_draft_items(invoice_draft_item_id);

create index marketplace_order_draft_items_checkout_intent_item_id_idx
  on public.marketplace_order_draft_items(checkout_intent_item_id);

create index marketplace_order_draft_items_source_type_idx
  on public.marketplace_order_draft_items(source_type);

create index marketplace_order_draft_items_sort_order_idx
  on public.marketplace_order_draft_items(sort_order);

create table public.marketplace_order_conversion_events (
  id bigint generated always as identity primary key,
  order_draft_id bigint not null references public.marketplace_order_drafts(id) on delete cascade,
  actor_profile_id bigint references public.profiles(id) on delete set null,
  event_type public.marketplace_order_conversion_event_type not null,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint marketplace_order_conversion_events_event_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint marketplace_order_conversion_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index marketplace_order_conversion_events_order_draft_id_idx
  on public.marketplace_order_conversion_events(order_draft_id);

create index marketplace_order_conversion_events_actor_profile_id_idx
  on public.marketplace_order_conversion_events(actor_profile_id);

create index marketplace_order_conversion_events_event_type_idx
  on public.marketplace_order_conversion_events(event_type);

create index marketplace_order_conversion_events_created_at_idx
  on public.marketplace_order_conversion_events(created_at);
