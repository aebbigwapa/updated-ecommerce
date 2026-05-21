-- ============================================================
-- MIGRATION: Orders enhancements
-- Cancel, Confirm Received, Return/Refund, Review support
-- Run once on existing databases.
-- ============================================================

-- 1. Extend orders status to include cancelled, return_requested, completed
DO $$
BEGIN
    ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

ALTER TABLE orders
    ADD CONSTRAINT orders_status_check
    CHECK (status IN (
        'pending', 'processing', 'ready_for_pickup',
        'in_transit', 'delivered', 'completed',
        'cancelled', 'return_requested'
    ));

-- 2. Add delivery confirmation timestamp and cancellation fields
ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS confirmed_at     timestamptz,
    ADD COLUMN IF NOT EXISTS cancelled_at     timestamptz,
    ADD COLUMN IF NOT EXISTS cancel_reason    text,
    ADD COLUMN IF NOT EXISTS cancel_idem_key  text UNIQUE;

CREATE INDEX IF NOT EXISTS idx_orders_cancel_idem ON orders(cancel_idem_key);

-- 3. Add reviewed flag to order_items
ALTER TABLE order_items
    ADD COLUMN IF NOT EXISTS is_reviewed boolean NOT NULL DEFAULT false;

-- 4. Return requests table
CREATE TABLE IF NOT EXISTS return_requests (
    id              uuid        NOT NULL DEFAULT gen_random_uuid(),
    order_id        uuid        NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    buyer_id        uuid        NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    reason          text        NOT NULL,
    description     text,
    status          text        NOT NULL DEFAULT 'pending_review'
                    CHECK (status IN ('pending_review','approved','rejected','refunded','closed')),
    idempotency_key text        UNIQUE,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_return_requests_order   ON return_requests(order_id);
CREATE INDEX IF NOT EXISTS idx_return_requests_buyer   ON return_requests(buyer_id);
CREATE INDEX IF NOT EXISTS idx_return_requests_status  ON return_requests(status);
CREATE INDEX IF NOT EXISTS idx_return_requests_idem    ON return_requests(idempotency_key);

-- 5. Return request items (which items + quantities are being returned)
CREATE TABLE IF NOT EXISTS return_request_items (
    id                uuid    NOT NULL DEFAULT gen_random_uuid(),
    return_request_id uuid    NOT NULL REFERENCES return_requests(id) ON DELETE CASCADE,
    order_item_id     uuid    NOT NULL REFERENCES order_items(id)     ON DELETE CASCADE,
    product_id        uuid    NOT NULL REFERENCES products(id)        ON DELETE CASCADE,
    quantity          integer NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_rri_return_request ON return_request_items(return_request_id);

-- 6. Return request images
CREATE TABLE IF NOT EXISTS return_request_images (
    id                uuid NOT NULL DEFAULT gen_random_uuid(),
    return_request_id uuid NOT NULL REFERENCES return_requests(id) ON DELETE CASCADE,
    image_url         text NOT NULL,
    created_at        timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_rri_images_request ON return_request_images(return_request_id);

-- 7. Cancellation requests table for approval-required cancellations
CREATE TABLE IF NOT EXISTS cancellation_requests (
    id              uuid        NOT NULL DEFAULT gen_random_uuid(),
    order_id        uuid        NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    order_item_id   uuid        REFERENCES order_items(id) ON DELETE CASCADE, -- NULL for full order cancellation
    requested_by    uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason          text        NOT NULL,
    status          text        NOT NULL DEFAULT 'pending',
    approved_by     uuid        REFERENCES users(id) ON DELETE SET NULL,
    approved_at     timestamptz,
    rejected_reason text,
    idempotency_key text        UNIQUE,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT status_check CHECK (status IN ('pending','approved','rejected')),
    PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_cancellation_requests_order   ON cancellation_requests(order_id);
CREATE INDEX IF NOT EXISTS idx_cancellation_requests_item    ON cancellation_requests(order_item_id);
CREATE INDEX IF NOT EXISTS idx_cancellation_requests_status  ON cancellation_requests(status);
CREATE INDEX IF NOT EXISTS idx_cancellation_requests_idem    ON cancellation_requests(idempotency_key);

-- 8. Extend order_items for partial cancellation
ALTER TABLE order_items
    ADD COLUMN IF NOT EXISTS status text DEFAULT 'active'
        CHECK (status IN ('active', 'cancelled', 'return_requested')),
    ADD COLUMN IF NOT EXISTS cancelled_at timestamptz,
    ADD COLUMN IF NOT EXISTS cancel_reason text;

-- 9. RLS policies for cancellation_requests
ALTER TABLE cancellation_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access on cancellation_requests"
    ON cancellation_requests FOR ALL USING (true) WITH CHECK (true);
