-- Migration 007 homepage/admin content + notifications.
-- Scope: homepage_content, featured_content, notifications.
-- Guardrails:
-- - keep artworks as the single artwork identity path.
-- - no second upload path for VR.
-- - keep homepage/admin content separate from environment assignment logic.

-- Enums required for Migration 007.
do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'homepage_visibility_status'
  ) then
    create type public.homepage_visibility_status as enum ('draft', 'active', 'archived');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'featured_content_type'
  ) then
    create type public.featured_content_type as enum ('artwork', 'artist', 'collection', 'announcement');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'featured_content_status'
  ) then
    create type public.featured_content_status as enum ('draft', 'active', 'inactive', 'archived');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'notification_type'
  ) then
    create type public.notification_type as enum (
      'system',
      'admin',
      'listing',
      'order',
      'escrow',
      'shipping',
      'insurance',
      'subscription',
      'authentication'
    );
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'notification_status'
  ) then
    create type public.notification_status as enum ('unread', 'read', 'archived');
  end if;
end
$$;

create table public.homepage_content (
  id bigint generated always as identity primary key,
  slug text not null unique,
  title text not null,
  subtitle text,
  body text,
  visibility_status public.homepage_visibility_status not null default 'draft',
  sort_order integer not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_by_profile_id bigint references public.profiles(id) on delete set null,
  updated_by_profile_id bigint references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint homepage_content_slug_nonempty_chk check (length(trim(slug)) > 0),
  constraint homepage_content_title_nonempty_chk check (length(trim(title)) > 0),
  constraint homepage_content_sort_order_nonnegative_chk check (sort_order >= 0),
  constraint homepage_content_ends_after_starts_chk check (
    ends_at is null or starts_at is null or ends_at >= starts_at
  )
);

create index homepage_content_visibility_status_idx on public.homepage_content(visibility_status);
create index homepage_content_sort_order_idx on public.homepage_content(sort_order);

create table public.featured_content (
  id bigint generated always as identity primary key,
  featured_content_type public.featured_content_type not null,
  status public.featured_content_status not null default 'draft',
  artwork_id bigint references public.artworks(id) on delete restrict,
  headline text not null,
  summary text,
  cta_label text,
  cta_url text,
  sort_order integer not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_by_profile_id bigint references public.profiles(id) on delete set null,
  updated_by_profile_id bigint references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint featured_content_headline_nonempty_chk check (length(trim(headline)) > 0),
  constraint featured_content_sort_order_nonnegative_chk check (sort_order >= 0),
  constraint featured_content_ends_after_starts_chk check (
    ends_at is null or starts_at is null or ends_at >= starts_at
  ),
  constraint featured_content_artwork_type_consistency_chk check (
    (featured_content_type = 'artwork' and artwork_id is not null)
    or
    (featured_content_type <> 'artwork' and artwork_id is null)
  )
);

create index featured_content_status_idx on public.featured_content(status);
create index featured_content_type_idx on public.featured_content(featured_content_type);
create index featured_content_sort_order_idx on public.featured_content(sort_order);
create index featured_content_artwork_id_idx on public.featured_content(artwork_id);
create unique index featured_content_one_active_artwork_idx
  on public.featured_content(artwork_id)
  where featured_content_type = 'artwork' and status = 'active';

create table public.notifications (
  id bigint generated always as identity primary key,
  profile_id bigint not null references public.profiles(id) on delete cascade,
  artwork_id bigint references public.artworks(id) on delete set null,
  created_by_profile_id bigint references public.profiles(id) on delete set null,
  notification_type public.notification_type not null,
  status public.notification_status not null default 'unread',
  title text not null,
  message text not null,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notifications_title_nonempty_chk check (length(trim(title)) > 0),
  constraint notifications_message_nonempty_chk check (length(trim(message)) > 0),
  constraint notifications_archived_after_read_chk check (
    archived_at is null or read_at is null or archived_at >= read_at
  ),
  constraint notifications_read_status_consistency_chk check (
    status <> 'read' or read_at is not null
  ),
  constraint notifications_archived_status_consistency_chk check (
    status <> 'archived' or archived_at is not null
  )
);

create index notifications_profile_id_idx on public.notifications(profile_id);
create index notifications_status_idx on public.notifications(status);
create index notifications_notification_type_idx on public.notifications(notification_type);
create index notifications_profile_status_created_at_idx
  on public.notifications(profile_id, status, created_at desc);

-- RLS helpers for profile/user path correctness on notification ownership.
create or replace function public.current_profile_id()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select p.id
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1
$$;

create or replace function public.current_profile_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.roles r on r.id = p.role_id
    where p.auth_user_id = auth.uid()
      and r.name = 'admin'
  )
$$;

-- Enforce owner update scope for notifications: only state fields by owner.
create or replace function public.notifications_enforce_owner_update_scope()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_profile_is_admin() then
    return new;
  end if;

  if public.current_profile_id() is null then
    raise exception 'Unauthorized notification update';
  end if;

  if old.profile_id <> public.current_profile_id() then
    raise exception 'Only notification owner may update notification state';
  end if;

  if new.profile_id is distinct from old.profile_id
     or new.artwork_id is distinct from old.artwork_id
     or new.created_by_profile_id is distinct from old.created_by_profile_id
     or new.notification_type is distinct from old.notification_type
     or new.title is distinct from old.title
     or new.message is distinct from old.message
     or new.payload is distinct from old.payload
     or new.created_at is distinct from old.created_at
  then
    raise exception 'Notification owners may only update state fields';
  end if;

  return new;
end
$$;

drop trigger if exists notifications_owner_update_scope_trg on public.notifications;
create trigger notifications_owner_update_scope_trg
before update on public.notifications
for each row
execute function public.notifications_enforce_owner_update_scope();

alter table public.homepage_content enable row level security;
alter table public.featured_content enable row level security;
alter table public.notifications enable row level security;

drop policy if exists homepage_content_select_public_or_admin on public.homepage_content;
create policy homepage_content_select_public_or_admin on public.homepage_content
for select using (public.current_profile_is_admin() or visibility_status = 'active');

drop policy if exists homepage_content_write_admin_only on public.homepage_content;
create policy homepage_content_write_admin_only on public.homepage_content
for all using (public.current_profile_is_admin()) with check (public.current_profile_is_admin());

drop policy if exists featured_content_select_public_or_admin on public.featured_content;
create policy featured_content_select_public_or_admin on public.featured_content
for select using (public.current_profile_is_admin() or status = 'active');

drop policy if exists featured_content_write_admin_only on public.featured_content;
create policy featured_content_write_admin_only on public.featured_content
for all using (public.current_profile_is_admin()) with check (public.current_profile_is_admin());

drop policy if exists notifications_select_owner_or_admin on public.notifications;
create policy notifications_select_owner_or_admin on public.notifications
for select using (
  public.current_profile_is_admin()
  or profile_id = public.current_profile_id()
);

drop policy if exists notifications_insert_admin_only on public.notifications;
create policy notifications_insert_admin_only on public.notifications
for insert with check (public.current_profile_is_admin());

drop policy if exists notifications_update_owner_or_admin on public.notifications;
create policy notifications_update_owner_or_admin on public.notifications
for update using (
  public.current_profile_is_admin()
  or profile_id = public.current_profile_id()
)
with check (
  public.current_profile_is_admin()
  or profile_id = public.current_profile_id()
);

-- Optional: keep delete admin-only to preserve audit trail.
drop policy if exists notifications_delete_admin_only on public.notifications;
create policy notifications_delete_admin_only on public.notifications
for delete using (public.current_profile_is_admin());
