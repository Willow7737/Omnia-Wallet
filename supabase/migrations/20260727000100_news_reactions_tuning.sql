-- Two findings the Supabase linter raised against news_reactions right after
-- it was created. Both are folded back into 20260727000000 so a fresh project
-- gets them from the start; this file exists because that migration had
-- already been applied to the live project and an applied migration is not
-- rewritten. It is idempotent, so running it after the corrected original is
-- a no-op.
--
-- 1. `unindexed_foreign_keys` — the primary key leads with content_type, so
--    it cannot serve a lookup by user alone. Deleting an account made the
--    cascade scan the whole table to find that person's reactions.
--
-- 2. `auth_rls_initplan` — a bare `auth.uid()` in a policy is re-evaluated
--    for every row scanned. Wrapped in a sub-select it becomes an InitPlan,
--    evaluated once per statement.

create index if not exists news_reactions_user_idx
  on public.news_reactions (user_id);

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
