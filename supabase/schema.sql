-- MCTY Marketplace: private applications + public approved directory
-- Run in a fresh Supabase project SQL Editor. Never expose service_role in the browser.
create extension if not exists pgcrypto;

-- Private application inbox. Anonymous visitors can INSERT only; only the MCTY admin can SELECT/update.
create table if not exists public.business_applications (
 id uuid primary key default gen_random_uuid(),
 name text not null check(char_length(name) between 2 and 100),
 category text not null check(char_length(category) between 2 and 80),
 country_code text not null default 'UG' check(country_code ~ '^[A-Z]{2}$'),
 currency_code text not null default 'UGX' check(currency_code ~ '^[A-Z]{3}$'),
 town text not null check(char_length(town) between 2 and 80),
 address text not null check(char_length(address) between 3 and 240),
 phone text not null check(phone ~ '^[0-9]{11,15}$'),
 email text not null check(email=lower(email)),
 registration_number text check(registration_number is null or char_length(registration_number)<=100),
 order_whatsapp text not null check(order_whatsapp ~ '^[0-9]{11,15}$'),
 description text not null check(char_length(description) between 10 and 1200),
 advertisement text check(advertisement is null or char_length(advertisement)<=500),
 products jsonb not null default '[]'::jsonb check(jsonb_typeof(products)='array'),
 website_url text,
 social_url text,
 documents text[] not null default '{}',
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 submitted_at timestamptz not null default now(),
 reviewed_at timestamptz,
 reviewed_by uuid references auth.users(id),
 review_note text
);
create index if not exists mcty_app_status_date_idx on public.business_applications(status,submitted_at desc);
alter table public.business_applications add column if not exists documents text[] not null default '{}';
alter table public.business_applications add column if not exists registration_number text;
alter table public.business_applications enable row level security;
drop policy if exists "Admin reads applications" on public.business_applications;
create policy "Admin reads applications" on public.business_applications for select to authenticated using(lower(auth.jwt()->>'email')='mclintonahairwe9@gmail.com');
drop policy if exists "Admin updates applications" on public.business_applications;
create policy "Admin updates applications" on public.business_applications for update to authenticated using(lower(auth.jwt()->>'email')='mclintonahairwe9@gmail.com') with check(lower(auth.jwt()->>'email')='mclintonahairwe9@gmail.com');
drop policy if exists "Public submits applications" on public.business_applications;
create policy "Public submits applications" on public.business_applications for insert to anon,authenticated with check(status='pending' and reviewed_at is null and reviewed_by is null and review_note is null);
grant insert on public.business_applications to anon,authenticated;
grant select,update on public.business_applications to authenticated;

-- Only approved businesses live here. Sensitive application documents and review notes never enter this table.
create table if not exists public.businesses (
 id uuid primary key default gen_random_uuid(),
 application_id uuid unique references public.business_applications(id) on delete set null,
 name text not null,
 category text not null,
 country_code text not null default 'UG',
 currency_code text not null default 'UGX',
 town text not null,
 address text not null,
 phone text not null,
 owner_email text not null,
 order_whatsapp text not null,
 description text not null,
 advertisement text,
 products jsonb not null default '[]'::jsonb check(jsonb_typeof(products)='array'),
 image_url text,
 maps_url text,
 website_url text,
 social_url text,
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
-- Additive migration for an earlier MCTY starter schema, if one was already installed.
alter table public.businesses add column if not exists application_id uuid references public.business_applications(id) on delete set null;
alter table public.businesses add column if not exists country_code text not null default 'UG';
alter table public.businesses add column if not exists currency_code text not null default 'UGX';
alter table public.businesses add column if not exists is_active boolean not null default true;
alter table public.businesses add column if not exists created_at timestamptz not null default now();
alter table public.businesses add column if not exists updated_at timestamptz not null default now();
alter table public.businesses add column if not exists website_url text;
alter table public.businesses add column if not exists social_url text;
-- If an earlier status-based table exists, only previously approved rows remain public.
do $$ begin
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='businesses' and column_name='status') then
  execute 'update public.businesses set is_active=(status=''approved'')';
 end if;
end $$;
alter table public.businesses drop constraint if exists businesses_category_check;
drop policy if exists "Public read approved businesses" on public.businesses;
drop policy if exists "Public submit pending application" on public.businesses;
drop policy if exists "MCTY admin manage businesses" on public.businesses;
drop policy if exists "Owners update own approved business" on public.businesses;

create index if not exists mcty_business_owner_idx on public.businesses(lower(owner_email));
create index if not exists mcty_business_browse_idx on public.businesses(country_code,category,town,created_at desc);
alter table public.businesses enable row level security;
drop policy if exists "Owners read own business" on public.businesses;
create policy "Owners read own business" on public.businesses for select to authenticated using(lower(owner_email)=lower(auth.jwt()->>'email'));
drop policy if exists "Admin reads businesses" on public.businesses;
create policy "Admin reads businesses" on public.businesses for select to authenticated using(lower(auth.jwt()->>'email')='mclintonahairwe9@gmail.com');
drop policy if exists "Owners update own business" on public.businesses;
create policy "Owners update own business" on public.businesses for update to authenticated using(lower(owner_email)=lower(auth.jwt()->>'email')) with check(lower(owner_email)=lower(auth.jwt()->>'email'));
grant select on public.businesses to authenticated;
revoke update on public.businesses from authenticated;
grant update(description,order_whatsapp,advertisement,products,website_url,social_url,image_url) on public.businesses to authenticated;

-- Public, read-only projection: only approved business contact and catalogue fields; no owner email, application documents, or admin review notes.
drop view if exists public.public_business_directory;
create view public.public_business_directory as
select id,name,category,country_code,currency_code,town,address,phone,order_whatsapp,description,advertisement,products,image_url,maps_url,website_url,social_url,created_at
from public.businesses where is_active=true;
grant select on public.public_business_directory to anon,authenticated;

-- Only admin can approve/reject applications; approval atomically creates the public business listing.
create or replace function public.mcty_review_application(p_application_id uuid,p_decision text,p_note text default null)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare a public.business_applications%rowtype; new_id uuid;
begin
 if lower(coalesce(auth.jwt()->>'email','')) <> 'mclintonahairwe9@gmail.com' then raise exception 'Administrator access required'; end if;
 if p_decision not in ('approved','rejected') then raise exception 'Invalid review decision'; end if;
 select * into a from public.business_applications where id=p_application_id for update;
 if not found then raise exception 'Application not found'; end if;
 if a.status <> 'pending' then raise exception 'This application has already been reviewed'; end if;
 update public.business_applications set status=p_decision,reviewed_at=now(),reviewed_by=auth.uid(),review_note=left(coalesce(p_note,''),1000) where id=a.id;
 if p_decision='approved' then
  insert into public.businesses(application_id,name,category,country_code,currency_code,town,address,phone,owner_email,order_whatsapp,description,advertisement,products,website_url,social_url)
  values(a.id,a.name,a.category,a.country_code,a.currency_code,a.town,a.address,a.phone,a.email,a.order_whatsapp,a.description,a.advertisement,a.products,a.website_url,a.social_url)
  returning id into new_id;
 end if;
 return jsonb_build_object('ok',true,'decision',p_decision,'business_id',new_id);
end; $$;
revoke all on function public.mcty_review_application(uuid,text,text) from public;
grant execute on function public.mcty_review_application(uuid,text,text) to authenticated;

-- Audit trail is private and records every review decision and visibility change.
create table if not exists public.business_review_audit(
 id bigint generated always as identity primary key,
 application_id uuid references public.business_applications(id) on delete set null,
 business_id uuid references public.businesses(id) on delete set null,
 admin_user_id uuid not null references auth.users(id),
 action text not null,
 note text,
 created_at timestamptz not null default now()
);
alter table public.business_review_audit add column if not exists application_id uuid references public.business_applications(id) on delete set null;
alter table public.business_review_audit add column if not exists action text;
alter table public.business_review_audit add column if not exists old_status text;
alter table public.business_review_audit add column if not exists new_status text;
alter table public.business_review_audit alter column business_id drop not null;
alter table public.business_review_audit alter column old_status drop not null;
alter table public.business_review_audit alter column new_status drop not null;
alter table public.business_review_audit alter column action drop not null;
alter table public.business_review_audit enable row level security;
drop policy if exists "Admin audit only" on public.business_review_audit;
create policy "Admin audit only" on public.business_review_audit for all to authenticated using(lower(auth.jwt()->>'email')='mclintonahairwe9@gmail.com') with check(lower(auth.jwt()->>'email')='mclintonahairwe9@gmail.com');
grant select,insert on public.business_review_audit to authenticated;

-- Admin-only suspend/restore RPC; owners cannot change their own listing visibility.
create or replace function public.mcty_set_business_active(p_business_id uuid,p_active boolean)
returns void language plpgsql security definer set search_path=public,auth as $$
begin
 if lower(coalesce(auth.jwt()->>'email','')) <> 'mclintonahairwe9@gmail.com' then raise exception 'Administrator access required'; end if;
 update public.businesses set is_active=p_active,updated_at=now() where id=p_business_id;
 if not found then raise exception 'Business not found'; end if;
 insert into public.business_review_audit(business_id,admin_user_id,action,note) values(p_business_id,auth.uid(),case when p_active then 'restored' else 'suspended' end,'Administrator changed public visibility');
end; $$;
revoke all on function public.mcty_set_business_active(uuid,boolean) from public;
grant execute on function public.mcty_set_business_active(uuid,boolean) to authenticated;


-- Minimal WhatsApp order-intent metrics. Not proof of payment or fulfilment.
create table if not exists public.order_intents(
 id uuid primary key default gen_random_uuid(),
 business_id uuid references public.businesses(id) on delete set null,
 business_name text not null,
 reference text not null,
 item_count integer not null check(item_count between 1 and 500),
 total_amount numeric(14,2) not null check(total_amount>=0),
 items jsonb not null default '[]'::jsonb check(jsonb_typeof(items)='array'),
 channel text not null default 'whatsapp' check(channel='whatsapp'),
 created_at timestamptz not null default now()
);
create index if not exists mcty_order_intents_created_idx on public.order_intents(created_at desc);
alter table public.order_intents enable row level security;
create or replace function public.mcty_is_active_business(p_business_id uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.businesses where id=p_business_id and is_active=true) $$;
revoke all on function public.mcty_is_active_business(uuid) from public;
grant execute on function public.mcty_is_active_business(uuid) to anon,authenticated;
drop policy if exists "MCTY admin read order intents" on public.order_intents;
drop policy if exists "Public log WhatsApp order intent" on public.order_intents;
drop policy if exists "Public logs order intent for active business" on public.order_intents;
create policy "Public logs order intent for active business" on public.order_intents for insert to anon,authenticated with check(channel='whatsapp' and public.mcty_is_active_business(business_id));
drop policy if exists "Admin reads order intents" on public.order_intents;
create policy "Admin reads order intents" on public.order_intents for select to authenticated using(lower(auth.jwt()->>'email')='mclintonahairwe9@gmail.com');
grant insert on public.order_intents to anon,authenticated;
grant select on public.order_intents to authenticated;

-- Private audit writes from security-definer RPCs.
create or replace function public.mcty_audit_review() returns trigger language plpgsql security definer set search_path=public,auth as $$
begin
 if old.status is distinct from new.status then
  insert into public.business_review_audit(application_id,admin_user_id,action,note)
  values(new.id,auth.uid(),new.status,new.review_note);
 end if;
 return new;
end; $$;
drop trigger if exists mcty_application_review_audit on public.business_applications;
create trigger mcty_application_review_audit after update of status on public.business_applications for each row execute function public.mcty_audit_review();

-- No anonymous SELECT on private tables. Never put a service_role key in config.js.
revoke all on public.business_applications from anon;
grant insert on public.business_applications to anon,authenticated;
revoke all on public.businesses from anon;
revoke insert on public.businesses from authenticated;
revoke all on public.business_review_audit from anon;
revoke all on public.order_intents from anon;
grant insert on public.order_intents to anon;


-- Private supporting-document storage. The bucket is not public; only the admin can read objects.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('mcty-private-applications','mcty-private-applications',false,8388608,array['application/pdf','image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=8388608,allowed_mime_types=array['application/pdf','image/jpeg','image/png','image/webp'];
drop policy if exists "Applicants upload private supporting docs" on storage.objects;
create policy "Applicants upload private supporting docs" on storage.objects for insert to anon,authenticated with check(bucket_id='mcty-private-applications' and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$');
drop policy if exists "Only MCTY admin reads private supporting docs" on storage.objects;
create policy "Only MCTY admin reads private supporting docs" on storage.objects for select to authenticated using(bucket_id='mcty-private-applications' and lower(auth.jwt()->>'email')='mclintonahairwe9@gmail.com');


-- Public business photos are separate from private application documents.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('mcty-business-media','mcty-business-media',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists "Business owners upload own public images" on storage.objects;
create policy "Business owners upload own public images" on storage.objects for insert to authenticated with check(bucket_id='mcty-business-media' and exists(select 1 from public.businesses b where b.id::text=(storage.foldername(name))[1] and lower(b.owner_email)=lower(auth.jwt()->>'email')));
