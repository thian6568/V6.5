-- Minimal auth schema bootstrap for local PostgreSQL validation runs.
-- Supabase provides auth.users in real environments; this is only for local test DBs.

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key,
  email text
);
