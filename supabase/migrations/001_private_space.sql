-- Initial private space. Apply through Supabase SQL editor or CLI migrations.
-- Membership is provisioned only by the owner/admin, never by the mobile client.
create table public.spaces (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Nuestro rincón'
);
create table public.members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  space_id uuid not null references public.spaces(id) on delete cascade,
  slot smallint not null check (slot in (1,2)),
  nickname text not null check (char_length(nickname) between 1 and 60),
  unique(space_id,slot)
);
create table public.cards (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  title text not null,
  drive_file_id text not null,
  mime_type text not null default 'image/webp' check (mime_type in ('image/webp','image/jpeg','image/png')),
  version integer not null default 1 check (version>0),
  active boolean not null default true
);
create table public.highscores (
  user_id uuid not null references public.members(user_id) on delete cascade,
  game text not null check (game in ('blocks-v1','arrows-v1','memory-v1','puzzle-v1')),
  score bigint not null check (score>=0),
  updated_at timestamptz not null default now(),
  primary key(user_id,game)
);
create table public.notes (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  author_id uuid not null references public.members(user_id),
  body text not null check (char_length(body) between 1 and 300),
  x real not null default 0 check (x between 0 and 1),
  y real not null default 0 check (y between 0 and 1),
  updated_at timestamptz not null default now()
);
alter table public.spaces enable row level security;
alter table public.members enable row level security;
alter table public.cards enable row level security;
alter table public.highscores enable row level security;
alter table public.notes enable row level security;

create function public.my_space() returns uuid language sql stable security definer
set search_path='' as $$ select space_id from public.members where user_id=(select auth.uid()) $$;
revoke all on function public.my_space() from public;
grant execute on function public.my_space() to authenticated;

revoke all on public.spaces, public.members, public.cards, public.highscores, public.notes from anon, authenticated;
grant select on public.spaces, public.members, public.cards, public.highscores, public.notes to authenticated;
grant insert on public.notes to authenticated;
grant update(body,x,y) on public.notes to authenticated;
grant delete on public.notes to authenticated;
create policy space_read on public.spaces for select to authenticated using (id=(select public.my_space()));
create policy members_read on public.members for select to authenticated using (space_id=(select public.my_space()));
create policy cards_read on public.cards for select to authenticated using (space_id=(select public.my_space()) and active);
create policy scores_read on public.highscores for select to authenticated using (user_id in (select user_id from public.members where space_id=(select public.my_space())));
create policy notes_read on public.notes for select to authenticated using (space_id=(select public.my_space()));
create policy notes_insert on public.notes for insert to authenticated with check (space_id=(select public.my_space()) and author_id=(select auth.uid()));
create policy notes_update on public.notes for update to authenticated using (space_id=(select public.my_space())) with check (space_id=(select public.my_space()));
create policy notes_delete on public.notes for delete to authenticated using (space_id=(select public.my_space()));

-- Atomic maximum prevents late offline submissions from lowering a record.
-- This is a trust-based leaderboard for two people, not an anti-cheat service.
create function public.submit_highscore(p_game text,p_score bigint) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or public.my_space() is null then raise exception 'Not a member'; end if;
  if p_score is null or p_score<0 then raise exception 'Invalid score'; end if;
  insert into public.highscores(user_id,game,score) values(auth.uid(),p_game,p_score)
  on conflict(user_id,game) do update set score=greatest(public.highscores.score,excluded.score),updated_at=now();
end $$;
revoke all on function public.submit_highscore(text,bigint) from public;
grant execute on function public.submit_highscore(text,bigint) to authenticated;

create function public.touch_note() returns trigger language plpgsql set search_path='' as $$
begin new.updated_at=now(); return new; end $$;
create trigger touch_note before update on public.notes for each row execute function public.touch_note();
