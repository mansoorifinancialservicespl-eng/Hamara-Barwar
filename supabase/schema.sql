-- Hamara-Barwar marketplace starter schema
-- Review and apply in a NEW Supabase development project first.
-- This is not a complete production payment integration.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete restrict,
  business_name text not null check (char_length(business_name) between 2 and 120),
  proprietor_name text not null check (char_length(proprietor_name) between 2 and 120),
  business_phone text not null check (char_length(business_phone) between 10 and 20),
  category text not null,
  address text not null check (char_length(address) between 5 and 400),
  delivery_areas text,
  opening_hours text,
  description text,
  image_path text,
  upi_id text,
  qr_image_path text,
  status text not null default 'pending' check (status in ('pending','active','rejected','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 160),
  description text,
  price_paise bigint not null check (price_paise >= 0),
  unit text not null default 'piece',
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  image_path text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete cascade,
  recipient_name text not null,
  phone text not null,
  address_line text not null,
  landmark text,
  locality text not null,
  city text not null default 'Barwar',
  state text not null default 'Uttar Pradesh',
  postal_code text,
  delivery_instructions text,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number bigint generated always as identity unique,
  customer_id uuid not null references auth.users(id) on delete restrict,
  shop_id uuid not null references public.shops(id) on delete restrict,
  address_id uuid references public.customer_addresses(id) on delete set null,
  delivery_name text not null,
  delivery_phone text not null,
  delivery_address text not null,
  delivery_landmark text,
  delivery_locality text not null,
  delivery_city text not null,
  delivery_state text not null,
  delivery_postal_code text,
  customer_note text,
  status text not null default 'pending' check (status in ('pending','accepted','preparing','out_for_delivery','delivered','cancelled','rejected')),
  payment_method text not null check (payment_method in ('cod','online')),
  payment_status text not null default 'pending' check (payment_status in ('pending','paid','failed','refunded','partially_refunded')),
  subtotal_paise bigint not null default 0 check (subtotal_paise >= 0),
  delivery_fee_paise bigint not null default 0 check (delivery_fee_paise >= 0),
  total_paise bigint not null default 0 check (total_paise >= 0),
  currency text not null default 'INR' check (currency = 'INR'),
  fulfillment_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name_snapshot text not null,
  unit_price_paise bigint not null check (unit_price_paise >= 0),
  quantity integer not null check (quantity between 1 and 1000),
  line_total_paise bigint not null check (line_total_paise >= 0),
  created_at timestamptz not null default now()
);

-- Provider references only; no card/UPI PIN/OTP data belongs in this table.
-- Writes should be performed only by trusted server-side Edge Functions/webhooks.
create table if not exists public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  provider text not null,
  provider_order_id text unique,
  provider_payment_id text unique,
  amount_paise bigint not null check (amount_paise >= 0),
  status text not null default 'created' check (status in ('created','pending','succeeded','failed','refunded')),
  webhook_event_id text unique,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists shops_owner_id_idx on public.shops(owner_id);
create index if not exists shops_public_listing_idx on public.shops(status, category);
create index if not exists products_shop_id_idx on public.products(shop_id);
create index if not exists products_public_listing_idx on public.products(is_active, shop_id);
create index if not exists addresses_customer_id_idx on public.customer_addresses(customer_id);
create index if not exists orders_customer_id_idx on public.orders(customer_id, created_at desc);
create index if not exists orders_shop_id_idx on public.orders(shop_id, created_at desc);
create index if not exists order_items_order_id_idx on public.order_items(order_id);
create index if not exists payments_order_id_idx on public.payment_transactions(order_id);

alter table public.profiles enable row level security;
alter table public.shops enable row level security;
alter table public.products enable row level security;
alter table public.customer_addresses enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payment_transactions enable row level security;

drop policy if exists "profile owner reads own profile" on public.profiles;
create policy "profile owner reads own profile" on public.profiles for select to authenticated using (id = (select auth.uid()));
drop policy if exists "profile owner updates own profile" on public.profiles;
create policy "profile owner updates own profile" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

drop policy if exists "public sees active shops" on public.shops;
create policy "public sees active shops" on public.shops for select to anon, authenticated using (status = 'active');
drop policy if exists "owner sees own shops" on public.shops;
create policy "owner sees own shops" on public.shops for select to authenticated using (owner_id = (select auth.uid()));
drop policy if exists "authenticated user registers own pending shop" on public.shops;
create policy "authenticated user registers own pending shop" on public.shops for insert to authenticated with check (owner_id = (select auth.uid()) and status = 'pending');
drop policy if exists "owner edits own shop details" on public.shops;
create policy "owner edits own shop details" on public.shops for update to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

-- Owners may edit shop listing fields but cannot change approval status from the browser.
revoke update on public.shops from authenticated;
grant update (business_name, proprietor_name, business_phone, category, address, delivery_areas, opening_hours, description, image_path, upi_id, qr_image_path, updated_at) on public.shops to authenticated;

drop policy if exists "public sees products from active shops" on public.products;
create policy "public sees products from active shops" on public.products for select to anon, authenticated using (
  is_active = true and exists (select 1 from public.shops s where s.id = shop_id and s.status = 'active')
);
drop policy if exists "shop owner reads own products" on public.products;
create policy "shop owner reads own products" on public.products for select to authenticated using (
  exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = (select auth.uid()))
);
drop policy if exists "shop owner adds products" on public.products;
create policy "shop owner adds products" on public.products for insert to authenticated with check (
  exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = (select auth.uid()))
);
drop policy if exists "shop owner updates products" on public.products;
create policy "shop owner updates products" on public.products for update to authenticated using (
  exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = (select auth.uid()))
) with check (
  exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = (select auth.uid()))
);
drop policy if exists "shop owner deletes products" on public.products;
create policy "shop owner deletes products" on public.products for delete to authenticated using (
  exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = (select auth.uid()))
);

drop policy if exists "customer manages own addresses" on public.customer_addresses;
create policy "customer manages own addresses" on public.customer_addresses for all to authenticated
using (customer_id = (select auth.uid())) with check (customer_id = (select auth.uid()));

drop policy if exists "customer reads own orders" on public.orders;
create policy "customer reads own orders" on public.orders for select to authenticated using (customer_id = (select auth.uid()));
drop policy if exists "shop owner reads shop orders" on public.orders;
create policy "shop owner reads shop orders" on public.orders for select to authenticated using (
  exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = (select auth.uid())
  )
);
drop policy if exists "shop owner updates fulfillment fields" on public.orders;
create policy "shop owner updates fulfillment fields" on public.orders for update to authenticated using (
  exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = (select auth.uid()))
) with check (
  exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = (select auth.uid()))
);
-- Clients can only change fulfillment status/note; payment and totals stay server-controlled.
revoke update on public.orders from authenticated;
grant update (status, fulfillment_note, updated_at) on public.orders to authenticated;

drop policy if exists "customer reads own order items" on public.order_items;
create policy "customer reads own order items" on public.order_items for select to authenticated using (
  exists (select 1 from public.orders o where o.id = order_id and o.customer_id = (select auth.uid()))
);
drop policy if exists "shop owner reads own order items" on public.order_items;
create policy "shop owner reads own order items" on public.order_items for select to authenticated using (
  exists (select 1 from public.orders o join public.shops s on s.id = o.shop_id where o.id = order_id and s.owner_id = (select auth.uid()))
);

drop policy if exists "customer reads own payment transactions" on public.payment_transactions;
create policy "customer reads own payment transactions" on public.payment_transactions for select to authenticated using (
  exists (select 1 from public.orders o where o.id = order_id and o.customer_id = (select auth.uid()))
);
drop policy if exists "shop owner reads payment status for own orders" on public.payment_transactions;
create policy "shop owner reads payment status for own orders" on public.payment_transactions for select to authenticated using (
  exists (select 1 from public.orders o join public.shops s on s.id = o.shop_id where o.id = order_id and s.owner_id = (select auth.uid()))
);

-- Important: no client-side insert/update/delete policies exist for orders, order_items,
-- or payment_transactions. Create orders and verify payments using trusted Edge Functions.
-- Before production, add audited admin-only shop approval and a server-side create-order
-- function that validates product IDs/stock, calculates totals from DB prices, reserves
-- stock atomically, and records delivery/fee snapshots. Add webhook signature verification,
-- idempotency, cancellation/refund logic and tests before accepting real money.
