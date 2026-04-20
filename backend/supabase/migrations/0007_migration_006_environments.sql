-- Migration 006 VR/WebGL environment integration.
-- Scope: environments, environment_assignments.
-- Guardrails:
-- - artworks remains the single artwork identity path.
-- - no second upload path for VR.
-- - no homepage/admin content tables in this migration.

-- Assignment cardinality rules (MVP):
-- - the same artwork cannot be actively assigned to the same environment more than once.
-- - the same wall_anchor_id in one environment cannot be reused by more than one active assignment.

-- Enums required for Migration 006.
do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'environment_status'
  ) then
    create type public.environment_status as enum ('draft', 'active', 'inactive', 'archived');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'performance_tier'
  ) then
    create type public.performance_tier as enum ('light', 'standard', 'premium');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = 'assignment_status'
  ) then
    create type public.assignment_status as enum ('pending', 'active', 'removed');
  end if;
end
$$;

create table public.environments (
  id bigint generated always as identity primary key,
  name text not null unique,
  runtime_key text not null unique,
  status public.environment_status not null default 'draft',
  performance_tier public.performance_tier not null default 'standard',
  version integer not null default 1,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint environments_name_nonempty_chk check (length(trim(name)) > 0),
  constraint environments_runtime_key_nonempty_chk check (length(trim(runtime_key)) > 0),
  constraint environments_version_positive_chk check (version > 0)
);

create index environments_status_idx on public.environments(status);
create index environments_performance_tier_idx on public.environments(performance_tier);

create table public.environment_assignments (
  id bigint generated always as identity primary key,
  environment_id bigint not null references public.environments(id) on delete cascade,
  artwork_id bigint not null references public.artworks(id) on delete cascade,
  status public.assignment_status not null default 'pending',
  wall_anchor_id text,
  sort_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint environment_assignments_wall_anchor_nonempty_chk check (
    wall_anchor_id is null or length(trim(wall_anchor_id)) > 0
  ),
  constraint environment_assignments_sort_order_nonnegative_chk check (sort_order >= 0)
);

create index environment_assignments_environment_id_idx on public.environment_assignments(environment_id);
create index environment_assignments_artwork_id_idx on public.environment_assignments(artwork_id);
create index environment_assignments_status_idx on public.environment_assignments(status);

create unique index environment_assignments_unique_active_artwork_idx
  on public.environment_assignments(environment_id, artwork_id)
  where status in ('pending', 'active');

create unique index environment_assignments_unique_active_anchor_idx
  on public.environment_assignments(environment_id, wall_anchor_id)
  where wall_anchor_id is not null and status = 'active';
