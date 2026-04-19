-- Artist In Art: Row Level Security policy blueprint
-- Scope: Backend-core MVP tables listed in DATA_MODEL.md and RLS_PLAN.md
-- NOTE:
-- 1) This script assumes tables already exist.
-- 2) Execute in a migration after schema creation.
-- 3) Keep a single shared artwork path via artworks.id references.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select r.name
  from public.profiles p
  join public.roles r on r.id = p.role_id
  where p.id = auth.uid()
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_role() = 'admin', false)
$$;

create or replace function public.is_artist()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_role() = 'artist', false)
$$;

create or replace function public.is_buyer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_role() = 'buyer', false)
$$;

-- ---------------------------------------------------------------------------
-- Enable RLS on all application tables
-- ---------------------------------------------------------------------------
alter table if exists public.profiles enable row level security;
alter table if exists public.audit_logs enable row level security;
alter table if exists public.artworks enable row level security;
alter table if exists public.artwork_assets enable row level security;
alter table if exists public.artwork_authentication enable row level security;
alter table if exists public.certificates enable row level security;
alter table if exists public.ownership_history enable row level security;
alter table if exists public.listings enable row level security;
alter table if exists public.orders enable row level security;
alter table if exists public.order_items enable row level security;
alter table if exists public.escrow_records enable row level security;
alter table if exists public.subscriptions enable row level security;
alter table if exists public.refund_requests enable row level security;
alter table if exists public.disputes enable row level security;
alter table if exists public.shipping_records enable row level security;
alter table if exists public.insurance_records enable row level security;
alter table if exists public.environments enable row level security;
alter table if exists public.environment_assignments enable row level security;
alter table if exists public.homepage_content enable row level security;
alter table if exists public.featured_content enable row level security;
alter table if exists public.notifications enable row level security;

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------
drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin on public.profiles
for select using (id = auth.uid() or public.is_admin());

drop policy if exists profiles_insert_self_or_admin on public.profiles;
create policy profiles_insert_self_or_admin on public.profiles
for insert with check (id = auth.uid() or public.is_admin());

drop policy if exists profiles_update_self_or_admin on public.profiles;
create policy profiles_update_self_or_admin on public.profiles
for update using (id = auth.uid() or public.is_admin())
with check (
  id = auth.uid()
  or public.is_admin()
);

-- ---------------------------------------------------------------------------
-- Audit logs: admin read, backend-only writes (service_role bypasses RLS)
-- ---------------------------------------------------------------------------
drop policy if exists audit_logs_select_admin on public.audit_logs;
create policy audit_logs_select_admin on public.audit_logs
for select using (public.is_admin());

-- ---------------------------------------------------------------------------
-- Artworks (single shared source of truth)
-- ---------------------------------------------------------------------------
drop policy if exists artworks_select_scoped on public.artworks;
create policy artworks_select_scoped on public.artworks
for select using (
  public.is_admin()
  or artist_user_id = auth.uid()
  or (
    publish_status in ('approved', 'live')
    and visibility_mode in ('marketplace_only', 'both', 'vr_only')
  )
);

drop policy if exists artworks_insert_artist_or_admin on public.artworks;
create policy artworks_insert_artist_or_admin on public.artworks
for insert with check (
  public.is_admin()
  or (public.is_artist() and artist_user_id = auth.uid())
);

drop policy if exists artworks_update_artist_or_admin on public.artworks;
create policy artworks_update_artist_or_admin on public.artworks
for update using (
  public.is_admin()
  or artist_user_id = auth.uid()
)
with check (
  public.is_admin()
  or artist_user_id = auth.uid()
);

drop policy if exists artworks_delete_admin_only on public.artworks;
create policy artworks_delete_admin_only on public.artworks
for delete using (public.is_admin());

-- ---------------------------------------------------------------------------
-- Artwork assets
-- ---------------------------------------------------------------------------
drop policy if exists artwork_assets_select_scoped on public.artwork_assets;
create policy artwork_assets_select_scoped on public.artwork_assets
for select using (
  public.is_admin()
  or exists (
    select 1
    from public.artworks a
    where a.id = artwork_assets.artwork_id
      and a.artist_user_id = auth.uid()
  )
  or exists (
    select 1
    from public.artworks a
    where a.id = artwork_assets.artwork_id
      and a.publish_status in ('approved', 'live')
      and a.visibility_mode in ('marketplace_only', 'both', 'vr_only')
  )
);

drop policy if exists artwork_assets_write_artist_or_admin on public.artwork_assets;
create policy artwork_assets_write_artist_or_admin on public.artwork_assets
for all using (
  public.is_admin()
  or exists (
    select 1
    from public.artworks a
    where a.id = artwork_assets.artwork_id
      and a.artist_user_id = auth.uid()
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.artworks a
    where a.id = artwork_assets.artwork_id
      and a.artist_user_id = auth.uid()
  )
);

-- ---------------------------------------------------------------------------
-- Artwork authentication
-- ---------------------------------------------------------------------------
drop policy if exists artwork_auth_select_scoped on public.artwork_authentication;
create policy artwork_auth_select_scoped on public.artwork_authentication
for select using (
  public.is_admin()
  or exists (
    select 1
    from public.artworks a
    where a.id = artwork_authentication.artwork_id
      and a.artist_user_id = auth.uid()
  )
);

drop policy if exists artwork_auth_insert_artist_or_admin on public.artwork_authentication;
create policy artwork_auth_insert_artist_or_admin on public.artwork_authentication
for insert with check (
  public.is_admin()
  or exists (
    select 1
    from public.artworks a
    where a.id = artwork_authentication.artwork_id
      and a.artist_user_id = auth.uid()
  )
);

drop policy if exists artwork_auth_update_admin_or_owner on public.artwork_authentication;
create policy artwork_auth_update_admin_or_owner on public.artwork_authentication
for update using (
  public.is_admin()
  or exists (
    select 1
    from public.artworks a
    where a.id = artwork_authentication.artwork_id
      and a.artist_user_id = auth.uid()
  )
)
with check (
  public.is_admin()
  or exists (
    select 1
    from public.artworks a
    where a.id = artwork_authentication.artwork_id
      and a.artist_user_id = auth.uid()
  )
);

-- ---------------------------------------------------------------------------
-- Listings
-- ---------------------------------------------------------------------------
drop policy if exists listings_select_scoped on public.listings;
create policy listings_select_scoped on public.listings
for select using (
  public.is_admin()
  or seller_user_id = auth.uid()
  or listing_status in ('approved', 'live')
);

drop policy if exists listings_insert_artist_or_admin on public.listings;
create policy listings_insert_artist_or_admin on public.listings
for insert with check (
  public.is_admin()
  or (
    public.is_artist()
    and seller_user_id = auth.uid()
    and exists (
      select 1 from public.artworks a
      where a.id = listings.artwork_id
        and a.artist_user_id = auth.uid()
    )
  )
);

drop policy if exists listings_update_artist_or_admin on public.listings;
create policy listings_update_artist_or_admin on public.listings
for update using (public.is_admin() or seller_user_id = auth.uid())
with check (public.is_admin() or seller_user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Orders + order_items + financial tables
-- ---------------------------------------------------------------------------
drop policy if exists orders_select_buyer_or_admin on public.orders;
create policy orders_select_buyer_or_admin on public.orders
for select using (public.is_admin() or buyer_user_id = auth.uid());

drop policy if exists orders_insert_buyer_or_admin on public.orders;
create policy orders_insert_buyer_or_admin on public.orders
for insert with check (public.is_admin() or buyer_user_id = auth.uid());

drop policy if exists orders_update_admin_only on public.orders;
create policy orders_update_admin_only on public.orders
for update using (public.is_admin()) with check (public.is_admin());

-- Order items are tied to order ownership.
drop policy if exists order_items_select_scoped on public.order_items;
create policy order_items_select_scoped on public.order_items
for select using (
  public.is_admin()
  or exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.buyer_user_id = auth.uid()
  )
);

drop policy if exists order_items_write_admin_only on public.order_items;
create policy order_items_write_admin_only on public.order_items
for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists escrow_select_scoped on public.escrow_records;
create policy escrow_select_scoped on public.escrow_records
for select using (
  public.is_admin()
  or exists (
    select 1
    from public.orders o
    where o.id = escrow_records.order_id
      and o.buyer_user_id = auth.uid()
  )
);

drop policy if exists escrow_write_admin_only on public.escrow_records;
create policy escrow_write_admin_only on public.escrow_records
for all using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- Subscriptions, refunds, disputes
-- ---------------------------------------------------------------------------
drop policy if exists subscriptions_select_scoped on public.subscriptions;
create policy subscriptions_select_scoped on public.subscriptions
for select using (public.is_admin() or user_id = auth.uid());

drop policy if exists subscriptions_insert_scoped on public.subscriptions;
create policy subscriptions_insert_scoped on public.subscriptions
for insert with check (public.is_admin() or user_id = auth.uid());

drop policy if exists subscriptions_update_scoped on public.subscriptions;
create policy subscriptions_update_scoped on public.subscriptions
for update using (public.is_admin() or user_id = auth.uid())
with check (public.is_admin() or user_id = auth.uid());

drop policy if exists refund_select_scoped on public.refund_requests;
create policy refund_select_scoped on public.refund_requests
for select using (
  public.is_admin()
  or requester_user_id = auth.uid()
  or exists (
    select 1
    from public.orders o
    where o.id = refund_requests.order_id
      and o.buyer_user_id = auth.uid()
  )
);

drop policy if exists refund_insert_scoped on public.refund_requests;
create policy refund_insert_scoped on public.refund_requests
for insert with check (
  public.is_admin()
  or requester_user_id = auth.uid()
);

drop policy if exists refund_update_admin_only on public.refund_requests;
create policy refund_update_admin_only on public.refund_requests
for update using (public.is_admin()) with check (public.is_admin());

drop policy if exists disputes_select_scoped on public.disputes;
create policy disputes_select_scoped on public.disputes
for select using (
  public.is_admin()
  or opened_by_user_id = auth.uid()
  or exists (
    select 1 from public.orders o
    where o.id = disputes.order_id
      and o.buyer_user_id = auth.uid()
  )
);

drop policy if exists disputes_insert_scoped on public.disputes;
create policy disputes_insert_scoped on public.disputes
for insert with check (public.is_admin() or opened_by_user_id = auth.uid());

drop policy if exists disputes_update_admin_only on public.disputes;
create policy disputes_update_admin_only on public.disputes
for update using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- Shipping + insurance
-- ---------------------------------------------------------------------------
drop policy if exists shipping_select_scoped on public.shipping_records;
create policy shipping_select_scoped on public.shipping_records
for select using (
  public.is_admin()
  or exists (
    select 1 from public.orders o
    where o.id = shipping_records.order_id
      and o.buyer_user_id = auth.uid()
  )
);

drop policy if exists shipping_write_admin_only on public.shipping_records;
create policy shipping_write_admin_only on public.shipping_records
for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists insurance_select_scoped on public.insurance_records;
create policy insurance_select_scoped on public.insurance_records
for select using (
  public.is_admin()
  or exists (
    select 1 from public.orders o
    where o.id = insurance_records.order_id
      and o.buyer_user_id = auth.uid()
  )
);

drop policy if exists insurance_write_admin_only on public.insurance_records;
create policy insurance_write_admin_only on public.insurance_records
for all using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- Gallery metadata
-- ---------------------------------------------------------------------------
drop policy if exists environments_select_public_or_admin on public.environments;
create policy environments_select_public_or_admin on public.environments
for select using (public.is_admin() or status = 'active');

drop policy if exists environments_write_admin_only on public.environments;
create policy environments_write_admin_only on public.environments
for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists env_assign_select_scoped on public.environment_assignments;
create policy env_assign_select_scoped on public.environment_assignments
for select using (
  public.is_admin()
  or exists (
    select 1
    from public.artworks a
    where a.id = environment_assignments.artwork_id
      and a.artist_user_id = auth.uid()
  )
  or exists (
    select 1
    from public.artworks a
    where a.id = environment_assignments.artwork_id
      and a.publish_status in ('approved', 'live')
      and a.visibility_mode in ('vr_only', 'both')
  )
);

drop policy if exists env_assign_write_admin_only on public.environment_assignments;
create policy env_assign_write_admin_only on public.environment_assignments
for all using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- CMS + notifications
-- ---------------------------------------------------------------------------
drop policy if exists homepage_select_public on public.homepage_content;
create policy homepage_select_public on public.homepage_content
for select using (public.is_admin() or visibility_status = 'active');

drop policy if exists homepage_write_admin_only on public.homepage_content;
create policy homepage_write_admin_only on public.homepage_content
for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists featured_select_public on public.featured_content;
create policy featured_select_public on public.featured_content
for select using (public.is_admin() or active_status = 'active');

drop policy if exists featured_write_admin_only on public.featured_content;
create policy featured_write_admin_only on public.featured_content
for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists notifications_select_owner_or_admin on public.notifications;
create policy notifications_select_owner_or_admin on public.notifications
for select using (public.is_admin() or user_id = auth.uid());

drop policy if exists notifications_insert_admin_only on public.notifications;
create policy notifications_insert_admin_only on public.notifications
for insert with check (public.is_admin());

drop policy if exists notifications_update_owner_or_admin on public.notifications;
create policy notifications_update_owner_or_admin on public.notifications
for update using (public.is_admin() or user_id = auth.uid())
with check (public.is_admin() or user_id = auth.uid());
