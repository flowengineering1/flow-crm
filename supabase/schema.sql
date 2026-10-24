-- Flow CRM ภาคสนาม · โครงสร้างฐานข้อมูล Supabase
-- วิธีใช้: เปิด Supabase Dashboard → SQL Editor → New query → วางทั้งไฟล์นี้ → Run
-- รันซ้ำได้ (idempotent) ถ้าแก้ไขภายหลัง

-- ---------- ตาราง ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text not null default '',
  code text not null default '',
  dept text not null default '',
  phone text not null default '',
  plate text not null default '',
  vehicle text not null default 'car',
  role text not null default 'sales' check (role in ('sales','manager','owner')),
  status text not null default 'pending' check (status in ('pending','active','disabled','rejected')),
  custom_actions jsonb not null default '[]'::jsonb,
  invite_code text not null default '',
  note text not null default '',
  registered_at bigint,
  approved_at bigint,
  approved_by uuid,
  approved_by_name text,
  updated_at bigint
);

create table if not exists public.customers (
  id text primary key,
  name text not null default '',
  data jsonb not null,
  updated_at bigint
);

create table if not exists public.visits (
  id text primary key,
  created_by uuid not null,
  created_at bigint not null,
  staff_name text,
  customer text,
  customer_id text,
  claim_status text not null default 'claimed',
  total numeric not null default 0,
  km_round_trip numeric not null default 0,
  data jsonb not null,
  updated_at bigint
);
create index if not exists visits_created_by_idx on public.visits (created_by, created_at desc);
create index if not exists visits_created_at_idx on public.visits (created_at desc);

create table if not exists public.approvals (
  visit_id text primary key,
  status text not null check (status in ('pending','approved','rejected')),
  note text not null default '',
  by_id uuid,
  by_name text,
  at bigint
);

create table if not exists public.settings (
  key text primary key,
  value jsonb not null,
  updated_at bigint
);
insert into public.settings (key, value) values ('settings', '{}'::jsonb), ('invites', '{"codes":{}}'::jsonb)
  on conflict (key) do nothing;

-- ---------- ฟังก์ชันช่วยตรวจสิทธิ์ ----------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role in ('manager','owner') and status = 'active');
$$;
create or replace function public.is_active() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and status = 'active');
$$;

-- ---------- ทริกเกอร์ป้องกันข้อมูลโปรไฟล์ ----------
-- 1) คนแรกที่ลงทะเบียนเป็นเจ้าของระบบโดยอัตโนมัติ
-- 2) ถ้าใส่รหัสเชิญที่ผู้จัดการสร้างไว้ หรืออีเมลตรงกับรหัสเชิญ ให้เปิดใช้งานทันทีและลบรหัสเชิญนั้น
-- 3) พนักงานขายแก้ role/status ของตัวเองไม่ได้ (เฉพาะผู้จัดการ/เจ้าของ)
create or replace function public.profiles_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare inv jsonb; codes jsonb;
begin
  if tg_op = 'INSERT' then
    new.email := coalesce(new.email, (select email from auth.users where id = new.id));
    if not exists (select 1 from public.profiles) then
      new.role := 'owner'; new.status := 'active';
    else
      new.role := 'sales'; new.status := 'pending';
      select value->'codes' into codes from public.settings where key = 'invites';
      if coalesce(new.invite_code, '') <> '' then inv := codes -> new.invite_code; end if;
      -- ไม่มีรหัส หรือรหัสไม่ตรง: ลองจับคู่ด้วยอีเมลที่ผู้จัดการใส่ไว้ตอนสร้างรหัสเชิญ
      if inv is null and coalesce(new.email, '') <> '' and codes is not null then
        select k, v into new.invite_code, inv from jsonb_each(codes) as t(k, v)
          where lower(coalesce(v->>'email', '')) = lower(new.email) limit 1;
      end if;
      if inv is not null then
        new.status := 'active';
        new.role := coalesce(inv->>'role', 'sales');
        if new.name = '' then new.name := coalesce(inv->>'name', ''); end if;
        if new.dept = '' then new.dept := coalesce(inv->>'dept', ''); end if;
        update public.settings set value = jsonb_set(value, '{codes}', codes - new.invite_code), updated_at = (extract(epoch from now()) * 1000)::bigint where key = 'invites';
      else
        new.invite_code := '';
      end if;
    end if;
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if not public.is_admin() then
      new.role := old.role; new.status := old.status; new.approved_at := old.approved_at;
      new.approved_by := old.approved_by; new.approved_by_name := old.approved_by_name; new.note := old.note;
    end if;
    return new;
  end if;
  return new;
end $$;
drop trigger if exists profiles_guard on public.profiles;
create trigger profiles_guard before insert or update on public.profiles
  for each row execute function public.profiles_guard();

-- ---------- Row Level Security ----------
alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.visits enable row level security;
alter table public.approvals enable row level security;
alter table public.settings enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles for insert to authenticated with check (id = auth.uid());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated using (id = auth.uid() or public.is_admin()) with check (id = auth.uid() or public.is_admin());
drop policy if exists profiles_delete on public.profiles;
create policy profiles_delete on public.profiles for delete to authenticated using (public.is_admin() and id <> auth.uid());

drop policy if exists customers_select on public.customers;
create policy customers_select on public.customers for select to authenticated using (public.is_active());
drop policy if exists customers_write on public.customers;
create policy customers_write on public.customers for insert to authenticated with check (public.is_active());
drop policy if exists customers_update on public.customers;
create policy customers_update on public.customers for update to authenticated using (public.is_active()) with check (public.is_active());
drop policy if exists customers_delete on public.customers;
create policy customers_delete on public.customers for delete to authenticated using (public.is_admin());

drop policy if exists visits_select on public.visits;
create policy visits_select on public.visits for select to authenticated using (created_by = auth.uid() or public.is_admin());
drop policy if exists visits_insert on public.visits;
create policy visits_insert on public.visits for insert to authenticated with check (created_by = auth.uid() and public.is_active());
drop policy if exists visits_update on public.visits;
create policy visits_update on public.visits for update to authenticated using ((created_by = auth.uid() and public.is_active()) or public.is_admin()) with check ((created_by = auth.uid() and public.is_active()) or public.is_admin());
drop policy if exists visits_delete on public.visits;
create policy visits_delete on public.visits for delete to authenticated using (public.is_admin());

drop policy if exists approvals_select on public.approvals;
create policy approvals_select on public.approvals for select to authenticated using (public.is_active());
drop policy if exists approvals_write on public.approvals;
create policy approvals_write on public.approvals for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists settings_select on public.settings;
create policy settings_select on public.settings for select to authenticated using (true);
drop policy if exists settings_write on public.settings;
create policy settings_write on public.settings for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------- ที่เก็บรูปและไฟล์แนบ ----------
insert into storage.buckets (id, name, public, file_size_limit)
  values ('attachments', 'attachments', false, 5242880)
  on conflict (id) do update set file_size_limit = 5242880;

drop policy if exists attachments_insert on storage.objects;
create policy attachments_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'attachments' and (storage.foldername(name))[1] = auth.uid()::text and public.is_active());
drop policy if exists attachments_select on storage.objects;
create policy attachments_select on storage.objects for select to authenticated
  using (bucket_id = 'attachments' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
drop policy if exists attachments_delete on storage.objects;
create policy attachments_delete on storage.objects for delete to authenticated
  using (bucket_id = 'attachments' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- ---------- Realtime (ให้หน้าจอทุกเครื่องอัปเดตเอง) ----------
do $$ begin
  begin alter publication supabase_realtime add table public.visits; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.approvals; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.profiles; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.customers; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.settings; exception when duplicate_object then null; end;
end $$;

-- เสร็จแล้ว: กลับไปตั้งค่า config.js ของแอปด้วย Project URL และ anon public key
