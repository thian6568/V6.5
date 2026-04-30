-- Migration 034 order retention disposition export delivery foundation.
-- Scope: backend-only order retention disposition export delivery records and delivery event tracking after export generation.
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
      and t.typname = 'marketplace_order_ret_disp_export_delivery_status'
  ) then
    create type public.marketplace_order_ret_disp_export_delivery_status as enum (
      'pending_export',
      'ready_for_delivery',
      'delivery_requested',
      'delivery_prepared',
      'delivery_sent',
      'delivery_received',
      'delivery_failed',
      'delivery_cancelled'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_export_delivery_method'
  ) then
    create type public.marketplace_order_ret_disp_export_delivery_method as enum (
      'system_download',
      'admin_download',
      'secure_link',
      'email_reference',
      'manual_handover'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_export_delivery_event'
  ) then
    create type public.marketplace_order_ret_disp_export_delivery_event as enum (
      'delivery_created',
      'export_attached',
      'delivery_ready',
      'delivery_requested',
      'delivery_prepared',
      'delivery_sent',
      'delivery_received',
      'delivery_failed',
      'delivery_cancelled',
      'manual_note_added'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'marketplace_order_ret_disp_export_delivery_actor'
  ) then
    create type public.marketplace_order_ret_disp_export_delivery_actor as enum (
      'system',
      'buyer',
      'seller',
      'admin',
      'support'
    );
  end if;
end
$$;

create table public.marketplace_order_retention_disposition_export_delivery_records (
  id bigint generated always as identity primary key,
  order_id bigint not null,
  export_record_id bigint,
  evidence_record_id bigint,
  requested_by_profile_id bigint,
  prepared_by_profile_id bigint,
  sent_by_profile_id bigint,
  received_by_profile_id bigint,
  status public.marketplace_order_ret_disp_export_delivery_status not null default 'pending_export',
  delivery_method public.marketplace_order_ret_disp_export_delivery_method not null default 'system_download',
  delivery_reference text not null,
  delivery_uri text,
  delivery_hash text,
  recipient_label text,
  delivery_note text,
  failure_reason text,
  ready_at timestamptz,
  requested_at timestamptz,
  prepared_at timestamptz,
  sent_at timestamptz,
  received_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ord_ret_disp_exp_del_records_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_disp_exp_del_records_export_fk
    foreign key (export_record_id)
    references public.marketplace_order_retention_disposition_export_records(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_records_evidence_fk
    foreign key (evidence_record_id)
    references public.marketplace_order_retention_disposition_evidence_records(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_records_requested_by_fk
    foreign key (requested_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_records_prepared_by_fk
    foreign key (prepared_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_records_sent_by_fk
    foreign key (sent_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_records_received_by_fk
    foreign key (received_by_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_records_reference_chk check (
    btrim(delivery_reference) <> ''
  ),
  constraint ord_ret_disp_exp_del_records_uri_chk check (
    delivery_uri is null or btrim(delivery_uri) <> ''
  ),
  constraint ord_ret_disp_exp_del_records_hash_chk check (
    delivery_hash is null or btrim(delivery_hash) <> ''
  ),
  constraint ord_ret_disp_exp_del_records_recipient_chk check (
    recipient_label is null or btrim(recipient_label) <> ''
  ),
  constraint ord_ret_disp_exp_del_records_note_chk check (
    delivery_note is null or btrim(delivery_note) <> ''
  ),
  constraint ord_ret_disp_exp_del_records_failure_chk check (
    failure_reason is null or btrim(failure_reason) <> ''
  ),
  constraint ord_ret_disp_exp_del_records_failed_reason_chk check (
    status <> 'delivery_failed' or failure_reason is not null
  ),
  constraint ord_ret_disp_exp_del_records_ready_status_chk check (
    ready_at is null
    or status in (
      'ready_for_delivery',
      'delivery_requested',
      'delivery_prepared',
      'delivery_sent',
      'delivery_received',
      'delivery_failed',
      'delivery_cancelled'
    )
  ),
  constraint ord_ret_disp_exp_del_records_requested_status_chk check (
    requested_at is null
    or status in (
      'delivery_requested',
      'delivery_prepared',
      'delivery_sent',
      'delivery_received',
      'delivery_failed',
      'delivery_cancelled'
    )
  ),
  constraint ord_ret_disp_exp_del_records_prepared_status_chk check (
    prepared_at is null
    or status in (
      'delivery_prepared',
      'delivery_sent',
      'delivery_received',
      'delivery_failed',
      'delivery_cancelled'
    )
  ),
  constraint ord_ret_disp_exp_del_records_sent_status_chk check (
    sent_at is null
    or status in (
      'delivery_sent',
      'delivery_received',
      'delivery_failed'
    )
  ),
  constraint ord_ret_disp_exp_del_records_received_status_chk check (
    received_at is null or status = 'delivery_received'
  ),
  constraint ord_ret_disp_exp_del_records_failed_status_chk check (
    failed_at is null or status = 'delivery_failed'
  ),
  constraint ord_ret_disp_exp_del_records_cancelled_status_chk check (
    cancelled_at is null or status = 'delivery_cancelled'
  ),
  constraint ord_ret_disp_exp_del_records_terminal_exclusive_chk check (
    num_nonnulls(received_at, failed_at, cancelled_at) <= 1
  ),
  constraint ord_ret_disp_exp_del_records_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create unique index ord_ret_disp_exp_del_records_reference_key
  on public.marketplace_order_retention_disposition_export_delivery_records(delivery_reference);

create unique index ord_ret_disp_exp_del_records_one_active_per_order_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(order_id)
  where status in (
    'pending_export',
    'ready_for_delivery',
    'delivery_requested',
    'delivery_prepared',
    'delivery_sent',
    'delivery_failed'
  );

create index ord_ret_disp_exp_del_records_order_id_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(order_id);

create index ord_ret_disp_exp_del_records_export_id_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(export_record_id);

create index ord_ret_disp_exp_del_records_evidence_id_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(evidence_record_id);

create index ord_ret_disp_exp_del_records_requested_by_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(requested_by_profile_id);

create index ord_ret_disp_exp_del_records_prepared_by_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(prepared_by_profile_id);

create index ord_ret_disp_exp_del_records_sent_by_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(sent_by_profile_id);

create index ord_ret_disp_exp_del_records_received_by_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(received_by_profile_id);

create index ord_ret_disp_exp_del_records_status_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(status);

create index ord_ret_disp_exp_del_records_method_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(delivery_method);

create index ord_ret_disp_exp_del_records_ready_at_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(ready_at);

create index ord_ret_disp_exp_del_records_requested_at_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(requested_at);

create index ord_ret_disp_exp_del_records_prepared_at_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(prepared_at);

create index ord_ret_disp_exp_del_records_sent_at_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(sent_at);

create index ord_ret_disp_exp_del_records_received_at_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(received_at);

create index ord_ret_disp_exp_del_records_created_at_idx
  on public.marketplace_order_retention_disposition_export_delivery_records(created_at);

create table public.marketplace_order_retention_disposition_export_delivery_events (
  id bigint generated always as identity primary key,
  delivery_record_id bigint not null,
  order_id bigint not null,
  actor_profile_id bigint,
  actor_role public.marketplace_order_ret_disp_export_delivery_actor not null default 'system',
  event_type public.marketplace_order_ret_disp_export_delivery_event not null,
  previous_status public.marketplace_order_ret_disp_export_delivery_status,
  new_status public.marketplace_order_ret_disp_export_delivery_status,
  event_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint ord_ret_disp_exp_del_events_record_fk
    foreign key (delivery_record_id)
    references public.marketplace_order_retention_disposition_export_delivery_records(id)
    on delete cascade,

  constraint ord_ret_disp_exp_del_events_order_fk
    foreign key (order_id)
    references public.orders(id)
    on delete cascade,

  constraint ord_ret_disp_exp_del_events_actor_profile_fk
    foreign key (actor_profile_id)
    references public.profiles(id)
    on delete set null,

  constraint ord_ret_disp_exp_del_events_status_change_chk check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  ),
  constraint ord_ret_disp_exp_del_events_note_chk check (
    event_note is null or btrim(event_note) <> ''
  ),
  constraint ord_ret_disp_exp_del_events_manual_note_chk check (
    event_type <> 'manual_note_added' or event_note is not null
  ),
  constraint ord_ret_disp_exp_del_events_metadata_object_chk check (
    jsonb_typeof(metadata) = 'object'
  )
);

create index ord_ret_disp_exp_del_events_record_id_idx
  on public.marketplace_order_retention_disposition_export_delivery_events(delivery_record_id);

create index ord_ret_disp_exp_del_events_order_id_idx
  on public.marketplace_order_retention_disposition_export_delivery_events(order_id);

create index ord_ret_disp_exp_del_events_actor_profile_id_idx
  on public.marketplace_order_retention_disposition_export_delivery_events(actor_profile_id);

create index ord_ret_disp_exp_del_events_actor_role_idx
  on public.marketplace_order_retention_disposition_export_delivery_events(actor_role);

create index ord_ret_disp_exp_del_events_event_type_idx
  on public.marketplace_order_retention_disposition_export_delivery_events(event_type);

create index ord_ret_disp_exp_del_events_previous_status_idx
  on public.marketplace_order_retention_disposition_export_delivery_events(previous_status);

create index ord_ret_disp_exp_del_events_new_status_idx
  on public.marketplace_order_retention_disposition_export_delivery_events(new_status);

create index ord_ret_disp_exp_del_events_created_at_idx
  on public.marketplace_order_retention_disposition_export_delivery_events(created_at);
