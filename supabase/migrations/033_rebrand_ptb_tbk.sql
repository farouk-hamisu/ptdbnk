-- Migration 033: platform rebrand — Marvin Bank -> PTB TBK
--
-- The application source already displays PTB TBK. This migration brings the
-- live database in line with it:
--
--   1. Re-derive public functions that embed the old institution name (welcome
--      notifications, loan disbursement/repayment counterparties, admin
--      credit/debit records, card notifications).
--   2. Rewrite stored display text in every public text/jsonb column.
--   3. Move account e-mail addresses from @marvinbank.com to @ptbtbk.com in
--      Supabase Auth and the public schema, so the documented demo/admin
--      sign-ins match the frontend.
--
-- DISPLAY-ONLY + IDENTITY ONLY: no amount, rate, fee, status, reference,
-- account number, date or balance is touched.
--
-- NOTE: auth.identities.email is a generated column on current Supabase
-- (PostgreSQL 17); it is skipped and kept in sync by Supabase automatically.
--
-- ROLLBACK: re-run with 'PTB TBK' -> 'Marvin Bank', 'PTB' -> 'Marvin',
--           'ptbtbk.com' -> 'marvinbank.com'.

-- ---------------------------------------------------------------------------
-- 1. Re-derive every public function that still embeds the old name
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
  d text;
begin
  for r in
    select p.oid::regprocedure as sig
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prosrc like '%Marvin%'
     order by 1
  loop
    d := pg_get_functiondef(r.sig);
    d := replace(d, 'Marvin Bank', 'PTB TBK');
    d := replace(d, 'Marvin', 'PTB');
    d := replace(d, 'marvinbank.com', 'ptbtbk.com');
    execute d;
    raise notice 'rebrand: redefined %', r.sig;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Stored display text: every text/jsonb column in the public schema
-- ---------------------------------------------------------------------------
do $$
declare
  c   record;
  n   bigint;
  sql text;
begin
  for c in
    select table_name, column_name, data_type
      from information_schema.columns
     where table_schema = 'public'
       and data_type in ('text', 'jsonb')
     order by table_name, column_name
  loop
    if c.data_type = 'jsonb' then
      sql := format(
        'update public.%I set %I = replace(replace(replace(%I::text,
           $a$Marvin Bank$a$, $a$PTB TBK$a$), $a$Marvin$a$, $a$PTB$a$),
           $a$marvinbank.com$a$, $a$ptbtbk.com$a$)::jsonb
          where %I::text like $a$%%Marvin%%$a$ or %I::text like $a$%%marvinbank.com%%$a$',
        c.table_name, c.column_name, c.column_name, c.column_name, c.column_name);
    else
      sql := format(
        'update public.%I set %I = replace(replace(replace(%I,
           $a$Marvin Bank$a$, $a$PTB TBK$a$), $a$Marvin$a$, $a$PTB$a$),
           $a$marvinbank.com$a$, $a$ptbtbk.com$a$)
          where %I like $a$%%Marvin%%$a$ or %I like $a$%%marvinbank.com%%$a$',
        c.table_name, c.column_name, c.column_name, c.column_name, c.column_name);
    end if;
    execute sql;
    get diagnostics n = row_count;
    if n > 0 then
      raise notice 'rebrand: %.% (+% rows)', c.table_name, c.column_name, n;
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. E-mail identities (auth schema)
-- ---------------------------------------------------------------------------
do $$
declare
  n bigint;
begin
  update auth.users
     set email = replace(lower(email), '@marvinbank.com', '@ptbtbk.com')
   where lower(email) like '%@marvinbank.com';
  get diagnostics n = row_count;
  raise notice 'rebrand: auth.users.email (+% rows)', n;

  if exists (select 1 from information_schema.columns
              where table_schema = 'auth' and table_name = 'identities'
                and column_name = 'provider_id') then
    update auth.identities
       set provider_id = replace(lower(provider_id), '@marvinbank.com', '@ptbtbk.com')
     where lower(provider_id) like '%@marvinbank.com';
    get diagnostics n = row_count;
    raise notice 'rebrand: auth.identities.provider_id (+% rows)', n;
  end if;

  if exists (select 1 from information_schema.columns
              where table_schema = 'auth' and table_name = 'identities'
                and column_name = 'identity_data') then
    update auth.identities
       set identity_data = replace(identity_data::text,
             '@marvinbank.com', '@ptbtbk.com')::jsonb
     where identity_data::text like '%@marvinbank.com%';
    get diagnostics n = row_count;
    raise notice 'rebrand: auth.identities.identity_data (+% rows)', n;
  end if;

  if exists (select 1 from information_schema.columns
              where table_schema = 'auth' and table_name = 'identities'
                and column_name = 'email'
                and is_generated = 'NEVER') then
    execute $q$
      update auth.identities
         set email = replace(lower(email), '@marvinbank.com', '@ptbtbk.com')
       where lower(email) like '%@marvinbank.com'
    $q$;
  end if;

  if exists (select 1 from information_schema.columns
              where table_schema = 'auth' and table_name = 'users'
                and column_name = 'raw_user_meta_data') then
    update auth.users
       set raw_user_meta_data = replace(raw_user_meta_data::text,
             '@marvinbank.com', '@ptbtbk.com')::jsonb
     where raw_user_meta_data::text like '%@marvinbank.com%';
    get diagnostics n = row_count;
    raise notice 'rebrand: auth.users.raw_user_meta_data (+% rows)', n;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Verify
-- ---------------------------------------------------------------------------
do $$
declare
  c    record;
  hits bigint;
begin
  if exists (
       select 1 from pg_proc p
         join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.prosrc like '%Marvin%'
     ) then
    raise exception 'REBRAND_INCOMPLETE: function bodies still reference the old name';
  end if;

  for c in
    select table_name, column_name
      from information_schema.columns
     where table_schema = 'public' and data_type in ('text', 'jsonb')
     order by table_name, column_name
  loop
    execute format(
      'select count(*) from public.%I where %I::text like $a$%%Marvin%%$a$ or %I::text like $a$%%marvinbank.com%%$a$',
      c.table_name, c.column_name, c.column_name) into hits;
    if hits > 0 then
      raise exception 'REBRAND_INCOMPLETE: public.%.% still has % old-brand row(s)',
                      c.table_name, c.column_name, hits;
    end if;
  end loop;

  if exists (select 1 from auth.users where lower(email) like '%@marvinbank.com') then
    raise exception 'REBRAND_INCOMPLETE: auth.users still has old-domain addresses';
  end if;

  raise notice 'rebrand: verification passed';
end;
$$;
