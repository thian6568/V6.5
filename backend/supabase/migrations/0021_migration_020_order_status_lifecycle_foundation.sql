-- Migration 020 order status lifecycle foundation.
-- Scope: backend-only order status lifecycle rules and event tracking after order finalization.
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
      and t.typname = 'marketplace_order_status_lifecycle_event_type'
  ) then
    create type public.marketplace_order_status_lifecycle_event_type as enum (
      'status_initialized',
      'transition_requested',
      'transition_approved',
      'transition_applied',
      'transition_rejected',
      'transition_cancelled',
      'note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_status_change_source'
  ) then
    create type public.marketplace_order_status_change_source as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support',
      'migration'
    );
  end if;
end
$$;

create table public.marketplace_order_status_lifecycle_rules (
  id bigint generated always as identity primary key,
  from_status public.order_status,
  to_status public.order_status not null,
  change_source public.marketplace_order_status_change_source not null default 'system',
  is_active boolean not null default true,
  rule_label text not null,
  guardrail_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint order_status_lifecycle_rules_from_to_different_chk check (
    from_status is null or from_status <> to_status
  ),
  constraint order_status_lifecycle_rules_label_nonblank_chk check (
    btrim(rule_label) <> ''
  ),
  constraint order_status_lifecycle_rules_note_nonblank_chk check (
    guardrail_note is null or btrim(guardrail_note) <> ''
  ),
  constraint order_status_lifecycle_rules_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index order_status_lifecycle_rules_unique_active_transition_idx
  on public.marketplace_order_status_lifecycle_rules (
    from_status,
    to_status,
    change_source
  )
  where is_active = true
    and from_status is not null;

create unique index order_status_lifecycle_rules_unique_active_initial_idx
  on public.marketplace_order_status_lifecycle_rules (
    to_status,
    change_source
  )
  where is_active = true
    and from_status is null;

create index order_status_lifecycle_rules_from_status_idx
  on public.marketplace_order_status_lifecycle_rules(from_status);

create index order_status_lifecycle_rules_to_status_idx
  on public.marketplace_order_status_lifecycle_rules(to_status);

create index order_status_lifecycle_rules_change_source_idx
  on public.marketplace_order_status_lifecycle_rules(change_source);

create index order_status_lifecycle_rules_is_active_idx
  on public.marketplace_order_status_lifecycle_rules(is_active);

create table public.marketplace_order_status_lifecycle_events (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  transition_rule_id bigint,
  actor_profile_id bigint,
  event_type public.marketplace_order_status_lifecycle_event_type not null,
  change_source public.marketplace_order_status_change_source not null default 'system',
  from_status public.order_status,
  to_status public.order_status,
  status_changed_at timestamptz,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint order_status_events_order_id_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint order_status_events_transition_rule_id_fk
    foreign key (transition_rule_id)
    references public.marketplace_order_status_lifecycle_rules(id)
    on delete set null,

  constraint order_status_events_actor_profile_id_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint order_status_lifecycle_events_to_status_required_chk check (
    (
      event_type = 'note_added'
      and to_status is null
    )
    or
    (
      event_type <> 'note_added'
      and to_status is not null
    )
  ),
  constraint order_status_lifecycle_events_from_to_different_chk check (
    from_status is null or to_status is null or from_status <> to_status
  ),
  constraint order_status_lifecycle_events_note_nonblank_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint order_status_lifecycle_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index order_status_lifecycle_events_order_id_idx
  on public.marketplace_order_status_lifecycle_events(order_id);

create index order_status_lifecycle_events_transition_rule_id_idx
  on public.marketplace_order_status_lifecycle_events(transition_rule_id);

create index order_status_lifecycle_events_actor_profile_id_idx
  on public.marketplace_order_status_lifecycle_events(actor_profile_id);

create index order_status_lifecycle_events_event_type_idx
  on public.marketplace_order_status_lifecycle_events(event_type);

create index order_status_lifecycle_events_change_source_idx
  on public.marketplace_order_status_lifecycle_events(change_source);

create index order_status_lifecycle_events_from_status_idx
  on public.marketplace_order_status_lifecycle_events(from_status);

create index order_status_lifecycle_events_to_status_idx
  on public.marketplace_order_status_lifecycle_events(to_status);

create index order_status_lifecycle_events_status_changed_at_idx
  on public.marketplace_order_status_lifecycle_events(status_changed_at);

create index order_status_lifecycle_events_created_at_idx
  on public.marketplace_order_status_lifecycle_events(created_at);
