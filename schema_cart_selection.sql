-- ============================================================
-- MIGRATION: Cart item selection + order idempotency
-- Run once on existing databases.
-- ============================================================

-- 1. Add is_selected flag to cart_items (default false = unselected)
alter table cart_items
    add column if not exists is_selected boolean not null default false;

-- 2. Add idempotency_key to orders to prevent duplicate submissions
alter table orders
    add column if not exists idempotency_key text unique;

create index if not exists idx_orders_idempotency on orders(idempotency_key);
create index if not exists idx_cart_items_selected on cart_items(user_id, is_selected);
