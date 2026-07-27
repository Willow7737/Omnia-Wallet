-- Likes and dislikes on news posts and replies.
--
-- One row per (user, content) pair, so a person's reaction is naturally
-- idempotent: liking twice is still one like, and switching from like to
-- dislike is an UPDATE rather than a second row. The primary key does that
-- enforcement, not the client.
--
-- `value` is +1 (like) or -1 (dislike). Storing the direction rather than two
-- boolean columns keeps "switch my reaction" a single upsert and makes the
-- score a plain SUM.
--
-- `content_id` is a uuid because both news_posts.id and news_replies.id are.
-- It cannot carry a foreign key — one column addressing two tables — but the
-- uuid type still rejects garbage and normalises formatting, so one reaction
-- can never land on two rows that differ only in case.
--
-- RLS model:
--   * Anyone — including anonymous readers — may SELECT, because counts are
--     public and the feed is readable without an account.
--   * An authenticated user may INSERT / UPDATE / DELETE only rows whose
--     user_id is their own auth.uid(). Nobody can react on someone else's
--     behalf, or clear someone else's reaction.

create table if not exists public.news_reactions (
  content_type text not null check (content_type in ('post', 'reply')),
  content_id   uuid not null,
  user_id      uuid not null default auth.uid()
                 references auth.users (id) on delete cascade,
  value        smallint not null check (value in (-1, 1)),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  primary key (content_type, content_id, user_id)
);

-- The feed reads reactions by content, never by user, so this is the index
-- that matters. The primary key already covers the per-user lookup.
create index if not exists news_reactions_content_idx
  on public.news_reactions (content_type, content_id);

-- The primary key leads with content_type, so it cannot serve a lookup by
-- user alone — which is what the FK to auth.users needs when an account is
-- deleted and the cascade has to find that person's rows.
create index if not exists news_reactions_user_idx
  on public.news_reactions (user_id);

alter table public.news_reactions enable row level security;

-- `(select auth.uid())` rather than a bare `auth.uid()`: wrapped in a
-- sub-select, Postgres hoists it into an InitPlan and evaluates it once for
-- the statement instead of once per row.
drop policy if exists news_reactions_read on public.news_reactions;
create policy news_reactions_read
  on public.news_reactions for select
  using (true);

drop policy if exists news_reactions_insert_own on public.news_reactions;
create policy news_reactions_insert_own
  on public.news_reactions for insert
  with check (user_id = (select auth.uid()));

drop policy if exists news_reactions_update_own on public.news_reactions;
create policy news_reactions_update_own
  on public.news_reactions for update
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists news_reactions_delete_own on public.news_reactions;
create policy news_reactions_delete_own
  on public.news_reactions for delete
  using (user_id = (select auth.uid()));

grant select on public.news_reactions to anon, authenticated;
grant insert, update, delete on public.news_reactions to authenticated;

-- Keep updated_at honest so "switch from like to dislike" is visible in the
-- row, not just inferable from the value.
create or replace function public.touch_news_reaction()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists news_reactions_touch on public.news_reactions;
create trigger news_reactions_touch
  before update on public.news_reactions
  for each row execute function public.touch_news_reaction();

-- Aggregated tallies, so the client fetches one row per piece of content
-- instead of every individual reaction.
--
-- `security_invoker` matters: without it the view runs as its owner and reads
-- straight past RLS. These counts are public either way, but a view that
-- quietly bypasses the policies on its base table is the wrong default to
-- leave lying around.
create or replace view public.news_reaction_counts
  with (security_invoker = true) as
  select
    content_type,
    content_id,
    count(*) filter (where value = 1)::int  as likes,
    count(*) filter (where value = -1)::int as dislikes
  from public.news_reactions
  group by content_type, content_id;

grant select on public.news_reaction_counts to anon, authenticated;

-- Realtime: the client subscribes to this table so a like landing on another
-- device updates every open feed. Adding a table to the publication twice is
-- an error, so this is guarded.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'news_reactions'
  ) then
    alter publication supabase_realtime add table public.news_reactions;
  end if;
end
$$;
