-- Migration 001 foundation tables.
-- Required creation order for this batch:
-- 1) roles
-- 2) profiles
-- 3) audit_logs

create table public.roles (
  id bigint generated always as identity primary key,
  name public.role_name not null unique,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id bigint generated always as identity primary key,
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  role_id bigint not null references public.roles(id) on delete restrict,
  display_name text,
  email text,
  status public.profile_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_email_chk check (email is null or position('@' in email) > 1)
);

create index profiles_role_id_idx on public.profiles(role_id);
create index profiles_status_idx on public.profiles(status);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_profile_id bigint references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint audit_logs_action_nonempty_chk check (length(trim(action)) > 0),
  constraint audit_logs_entity_type_nonempty_chk check (length(trim(entity_type)) > 0)
);

create index audit_logs_actor_profile_id_idx on public.audit_logs(actor_profile_id);
create index audit_logs_entity_idx on public.audit_logs(entity_type, entity_id);
create index audit_logs_created_at_idx on public.audit_logs(created_at desc);

insert into public.roles (name, description)
values
  ('admin', 'Platform administrator'),
  ('artist', 'Artist account'),
  ('buyer', 'Buyer account')
on conflict (name)
do update set
  description = excluded.description,
  updated_at = now();
