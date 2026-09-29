-- Two private one-time activation codes let the two devices sign in without email.
-- Insert only hashes of independently generated codes after applying this migration.
create extension if not exists pgcrypto with schema extensions;

create table public.activation_codes (
  space_id uuid not null references public.spaces(id) on delete cascade,
  slot smallint not null check (slot in (1,2)),
  code_hash bytea not null unique,
  claimed_by uuid unique references auth.users(id),
  claimed_at timestamptz,
  primary key (space_id, slot)
);
alter table public.activation_codes enable row level security;
revoke all on public.activation_codes from public, anon, authenticated;

create function public.claim_slot(p_code text, p_nickname text) returns smallint
language plpgsql security definer set search_path = '' as $$
declare
  activation public.activation_codes%rowtype;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if p_code is null or char_length(p_code) < 20 or char_length(p_code) > 120 then
    raise exception 'Invalid activation code';
  end if;
  if p_nickname is null or char_length(trim(p_nickname)) not between 1 and 60 then
    raise exception 'Invalid nickname';
  end if;
  select * into activation from public.activation_codes
    where code_hash = extensions.digest(p_code, 'sha256') for update;
  if not found or activation.claimed_by is not null then
    raise exception 'Activation code unavailable';
  end if;
  if exists (select 1 from public.members where user_id = auth.uid()) then
    raise exception 'This device is already activated';
  end if;
  insert into public.members(user_id, space_id, slot, nickname)
    values (auth.uid(), activation.space_id, activation.slot, trim(p_nickname));
  update public.activation_codes set claimed_by = auth.uid(), claimed_at = now()
    where space_id = activation.space_id and slot = activation.slot;
  return activation.slot;
end $$;
revoke all on function public.claim_slot(text,text) from public;
grant execute on function public.claim_slot(text,text) to authenticated;

-- Send changes in the shared mural to both authenticated devices.
alter publication supabase_realtime add table public.notes;
