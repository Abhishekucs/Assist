create extension if not exists pgcrypto;

create table if not exists purchases (
  id uuid primary key default gen_random_uuid(),
  dodo_payment_id text not null unique,
  dodo_checkout_session_id text not null,
  status text not null,
  product_id text not null,
  amount integer not null,
  currency text not null,
  customer_email text not null,
  customer_name text,
  license_key text,
  purchased_at timestamptz not null,
  download_count integer not null default 0,
  last_downloaded_at timestamptz,
  dodo_payload jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists purchases_customer_email_idx
  on purchases (customer_email);

create index if not exists purchases_status_idx
  on purchases (status);

create unique index if not exists purchases_license_key_unique_idx
  on purchases (license_key)
  where license_key is not null;

create table if not exists purchase_events (
  id uuid primary key default gen_random_uuid(),
  dodo_webhook_id text not null unique,
  event_type text not null,
  dodo_payment_id text,
  payload jsonb not null,
  processed_at timestamptz not null default now()
);

create index if not exists purchase_events_payment_id_idx
  on purchase_events (dodo_payment_id);
