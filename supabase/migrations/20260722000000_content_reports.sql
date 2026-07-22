-- Content moderation: user reports of user-generated content.
--
-- The wallet lets any signed-in user flag a reply (or, later, a post) that
-- breaks the community guidelines. Reports land here for the moderation team
-- to review. Blocking is handled entirely client-side and never reaches the
-- server, so there is deliberately no "blocks" table.
--
-- RLS model:
--   * Any authenticated user may INSERT a report (reporter_id defaults to
--     their auth.uid()). They may not read, update, or delete reports —
--     not even their own — so the queue can't be enumerated or tampered with.
--   * Members of the `moderators` table may SELECT and UPDATE (to triage /
--     resolve). Service-role callers (edge functions, dashboards) bypass RLS.

create table if not exists public.content_reports (
  id            uuid primary key default gen_random_uuid(),
  content_type  text not null check (content_type in ('reply', 'post')),
  content_id    text not null,
  reason        text not null,
  reported_author text,
  details       text,
  reporter_id   uuid not null default auth.uid() references auth.users (id)
                  on delete set null,
  status        text not null default 'open'
                  check (status in ('open', 'reviewing', 'actioned', 'dismissed')),
  created_at    timestamptz not null default now(),
  reviewed_at   timestamptz,
  reviewed_by   uuid references auth.users (id)
);

-- Speed up the moderator queue (newest open reports first) and dedupe checks.
create index if not exists content_reports_status_created_idx
  on public.content_reports (status, created_at desc);
create index if not exists content_reports_content_idx
  on public.content_reports (content_type, content_id);

alter table public.content_reports enable row level security;

-- Allowlist of moderator accounts. Populated out-of-band (dashboard / SQL).
create table if not exists public.moderators (
  user_id uuid primary key references auth.users (id) on delete cascade,
  added_at timestamptz not null default now()
);
alter table public.moderators enable row level security;

create or replace function public.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.moderators m where m.user_id = auth.uid()
  );
$$;

-- Anyone signed in can file a report; reporter_id is forced to their own uid.
drop policy if exists "signed-in users can report" on public.content_reports;
create policy "signed-in users can report"
  on public.content_reports
  for insert
  to authenticated
  with check (reporter_id = auth.uid());

-- Only moderators can read the queue.
drop policy if exists "moderators read reports" on public.content_reports;
create policy "moderators read reports"
  on public.content_reports
  for select
  to authenticated
  using (public.is_moderator());

-- Only moderators can triage / resolve.
drop policy if exists "moderators update reports" on public.content_reports;
create policy "moderators update reports"
  on public.content_reports
  for update
  to authenticated
  using (public.is_moderator())
  with check (public.is_moderator());

-- Moderators can see who else is a moderator; no self-service writes.
drop policy if exists "moderators read roster" on public.moderators;
create policy "moderators read roster"
  on public.moderators
  for select
  to authenticated
  using (public.is_moderator());
