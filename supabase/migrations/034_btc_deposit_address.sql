-- Migration 034: designated Bitcoin deposit address
--
-- Sets the single shared Bitcoin address customers send deposits to. It is
-- read by btc_deposit_config() (frontend QR / address / copy) and by the
-- monitor-btc-deposits edge function (on-chain verification), so the displayed
-- address and the address being watched are always the same value.
--
-- Idempotent: safe to re-run.

insert into public.system_settings (key, value, description, updated_at)
values (
  'btc_deposit_address',
  '"bc1q0ns73w658xahfvn8fv3a36drs99yna7zwuv4ww"',
  'Bitcoin address customers send deposits to',
  now()
)
on conflict (key) do update
  set value       = excluded.value,
      description = excluded.description,
      updated_at  = now();

do $$
begin
  if (select value #>> '{}' from public.system_settings where key = 'btc_deposit_address')
     <> 'bc1q0ns73w658xahfvn8fv3a36drs99yna7zwuv4ww' then
    raise exception 'BTC_ADDRESS_NOT_SET';
  end if;
  raise notice 'btc deposit address configured';
end;
$$;
