-- Migration 001 enum foundation only.
-- Keep this file scoped to the initial foundation tables (roles, profiles, audit_logs).

create type public.role_name as enum ('admin', 'artist', 'buyer');
create type public.profile_status as enum ('active', 'suspended', 'pending', 'archived');
