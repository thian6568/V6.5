-- Migration 017 checkout contact, delivery preference, billing snapshot, and invoice draft foundation.
-- Scope: checkout-side data snapshots and invoice draft preparation.
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

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_delivery_preference_type'
  ) then
    create type public.marketplace_delivery_preference_type as enum (
      'shipping',
      'pickup',
      'digital'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_invoice_draft_status'
  ) then
    create type public.marketplace_invoice_draft_status as enum (
      'draft',
      'review_ready',
      'finalized',
      'voided'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_invoice_line_type'
  ) then
    create type public.marketplace_invoice_line_type as enum (
      'item_subtotal',
      'shipping_estimate',
      'tax_estimate',
      'insurance_estimate',
      'discount',
      'fee',
      'other'
    );
  end if;
end
$$;

create table public.marketplace_checkout_contact_snapshots (
  id bigint generated always as identity primary key,
  checkout_intent_id bigint not null,
  email text not null,
  phone text,
  full_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_checkout_contact_snapshots_checkout_intent_fk
    foreign key (checkout_intent_id)
    references public.marketplace_checkout_intents(id)
    on delete cascade,
  constraint marketplace_checkout_contact_snapshots_email_nonblank_chk check (
    btrim(email) <> ''
  ),
  constraint marketplace_checkout_contact_snapshots_full_name_nonblank_chk check (
    btrim(full_name) <> ''
  ),
  constraint marketplace_checkout_contact_snapshots_phone_nonblank_chk check (
    phone is null or btrim(phone) <> ''
  )
);

create unique index marketplace_checkout_contact_snapshots_checkout_intent_id_key
  on public.marketplace_checkout_contact_snapshots(checkout_intent_id);

create index marketplace_checkout_contact_snapshots_checkout_intent_id_idx
  on public.marketplace_checkout_contact_snapshots(checkout_intent_id);

create table public.marketplace_checkout_delivery_preferences (
  id bigint generated always as identity primary key,
  checkout_intent_id bigint not null,
  delivery_preference public.marketplace_delivery_preference_type not null default 'shipping',
  shipping_address_line1 text,
  shipping_address_line2 text,
  shipping_city text,
  shipping_region text,
  shipping_postal_code text,
  shipping_country_code text,
  pickup_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint mkt_delivery_preferences_checkout_intent_fk
    foreign key (checkout_intent_id)
    references public.marketplace_checkout_intents(id)
    on delete cascade,
  constraint mkt_delivery_preferences_country_code_chk check (
    shipping_country_code is null or shipping_country_code ~ '^[A-Z]{2}$'
  ),
  constraint mkt_delivery_preferences_pickup_note_nonblank_chk check (
    pickup_note is null or btrim(pickup_note) <> ''
  ),
  constraint mkt_delivery_preferences_shipping_required_chk check (
    delivery_preference <> 'shipping'
    or (
      shipping_address_line1 is not null
      and btrim(shipping_address_line1) <> ''
      and shipping_city is not null
      and btrim(shipping_city) <> ''
      and shipping_country_code is not null
      and btrim(shipping_country_code) <> ''
    )
  )
);

create unique index mkt_delivery_preferences_checkout_intent_id_key
  on public.marketplace_checkout_delivery_preferences(checkout_intent_id);

create index mkt_delivery_preferences_checkout_intent_id_idx
  on public.marketplace_checkout_delivery_preferences(checkout_intent_id);

create index marketplace_checkout_delivery_preferences_delivery_preference_idx
  on public.marketplace_checkout_delivery_preferences(delivery_preference);

create table public.marketplace_checkout_billing_snapshots (
  id bigint generated always as identity primary key,
  checkout_intent_id bigint not null,
  billing_name text not null,
  billing_address_line1 text,
  billing_address_line2 text,
  billing_city text,
  billing_region text,
  billing_postal_code text,
  billing_country_code text,
  tax_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_checkout_billing_snapshots_checkout_intent_fk
    foreign key (checkout_intent_id)
    references public.marketplace_checkout_intents(id)
    on delete cascade,
  constraint marketplace_checkout_billing_snapshots_billing_name_nonblank_chk check (
    btrim(billing_name) <> ''
  ),
  constraint mkt_billing_snapshots_country_code_chk check (
    billing_country_code is null or billing_country_code ~ '^[A-Z]{2}$'
  ),
  constraint mkt_billing_snapshots_tax_id_nonblank_chk check (
    tax_id is null or btrim(tax_id) <> ''
  )
);

create unique index marketplace_checkout_billing_snapshots_checkout_intent_id_key
  on public.marketplace_checkout_billing_snapshots(checkout_intent_id);

create index marketplace_checkout_billing_snapshots_checkout_intent_id_idx
  on public.marketplace_checkout_billing_snapshots(checkout_intent_id);

create table public.marketplace_invoice_drafts (
  id bigint generated always as identity primary key,
  checkout_intent_id bigint not null,
  buyer_profile_id bigint not null,
  status public.marketplace_invoice_draft_status not null default 'draft',
  currency_code text not null,
  items_subtotal_amount numeric(12,2) not null default 0,
  shipping_estimate_amount numeric(12,2) not null default 0,
  tax_estimate_amount numeric(12,2) not null default 0,
  insurance_estimate_amount numeric(12,2) not null default 0,
  discount_amount numeric(12,2) not null default 0,
  grand_total_amount numeric(12,2) not null default 0,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketplace_invoice_drafts_checkout_intent_fk
    foreign key (checkout_intent_id)
    references public.marketplace_checkout_intents(id),
  constraint marketplace_invoice_drafts_buyer_profile_id_fkey
    foreign key (buyer_profile_id)
    references public.profiles(id),
  constraint marketplace_invoice_drafts_currency_code_chk check (
    currency_code ~ '^[A-Z]{3}$'
  ),
  constraint marketplace_invoice_drafts_items_subtotal_nonnegative_chk check (
    items_subtotal_amount >= 0
  ),
  constraint marketplace_invoice_drafts_shipping_estimate_nonnegative_chk check (
    shipping_estimate_amount >= 0
  ),
  constraint marketplace_invoice_drafts_tax_estimate_nonnegative_chk check (
    tax_estimate_amount >= 0
  ),
  constraint marketplace_invoice_drafts_insurance_estimate_nonnegative_chk check (
    insurance_estimate_amount >= 0
  ),
  constraint marketplace_invoice_drafts_discount_nonnegative_chk check (
    discount_amount >= 0
  ),
  constraint marketplace_invoice_drafts_grand_total_nonnegative_chk check (
    grand_total_amount >= 0
  ),
  constraint marketplace_invoice_drafts_discount_bound_chk check (
    discount_amount <= items_subtotal_amount + shipping_estimate_amount + tax_estimate_amount + insurance_estimate_amount
  ),
  constraint marketplace_invoice_drafts_grand_total_consistency_chk check (
    grand_total_amount = items_subtotal_amount + shipping_estimate_amount + tax_estimate_amount + insurance_estimate_amount - discount_amount
  ),
  constraint marketplace_invoice_drafts_notes_nonblank_chk check (
    notes is null or btrim(notes) <> ''
  ),
  constraint marketplace_invoice_drafts_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index marketplace_invoice_drafts_checkout_intent_id_idx
  on public.marketplace_invoice_drafts(checkout_intent_id);

create index marketplace_invoice_drafts_buyer_profile_id_idx
  on public.marketplace_invoice_drafts(buyer_profile_id);

create index marketplace_invoice_drafts_status_idx
  on public.marketplace_invoice_drafts(status);

create index marketplace_invoice_drafts_created_at_idx
  on public.marketplace_invoice_drafts(created_at);

create unique index marketplace_invoice_drafts_one_active_per_checkout_intent_idx
  on public.marketplace_invoice_drafts(checkout_intent_id)
  where status in ('draft', 'review_ready');

create table public.marketplace_invoice_draft_items (
  id bigint generated always as identity primary key,
  invoice_draft_id bigint not null,
  checkout_intent_item_id bigint,
  line_type public.marketplace_invoice_line_type not null,
  description text not null,
  quantity integer not null default 1,
  unit_amount numeric(12,2) not null default 0,
  line_amount numeric(12,2) not null default 0,
  sort_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint marketplace_invoice_draft_items_invoice_draft_id_fkey
    foreign key (invoice_draft_id)
    references public.marketplace_invoice_drafts(id)
    on delete cascade,
  constraint marketplace_invoice_draft_items_checkout_intent_item_id_fkey
    foreign key (checkout_intent_item_id)
    references public.marketplace_checkout_intent_items(id),
  constraint marketplace_invoice_draft_items_description_nonblank_chk check (
    btrim(description) <> ''
  ),
  constraint marketplace_invoice_draft_items_quantity_positive_chk check (
    quantity > 0
  ),
  constraint marketplace_invoice_draft_items_unit_amount_nonnegative_chk check (
    unit_amount >= 0
  ),
  constraint marketplace_invoice_draft_items_line_amount_nonnegative_chk check (
    line_amount >= 0
  ),
  constraint marketplace_invoice_draft_items_line_amount_consistency_chk check (
    line_amount = unit_amount * quantity
  ),
  constraint marketplace_invoice_draft_items_sort_order_nonnegative_chk check (
    sort_order >= 0
  ),
  constraint marketplace_invoice_draft_items_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index marketplace_invoice_draft_items_invoice_draft_id_idx
  on public.marketplace_invoice_draft_items(invoice_draft_id);

create index marketplace_invoice_draft_items_checkout_intent_item_id_idx
  on public.marketplace_invoice_draft_items(checkout_intent_item_id);

create index marketplace_invoice_draft_items_line_type_idx
  on public.marketplace_invoice_draft_items(line_type);

create index marketplace_invoice_draft_items_sort_order_idx
  on public.marketplace_invoice_draft_items(sort_order);
