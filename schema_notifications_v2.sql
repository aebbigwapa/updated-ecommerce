-- ============================================================
-- MIGRATION: Enhanced Notifications System
-- Adds data JSON column and extends type enum for Shopee/Lazada-style notifications
-- Run once on existing databases.
-- ============================================================

-- 1. Extend notification type enum to include granular event types
DO $$
BEGIN
    ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

ALTER TABLE notifications
    ADD CONSTRAINT notifications_type_check
    CHECK (type IN (
        'new_order',              -- Seller: buyer placed order
        'status_update',          -- Buyer: order status changed
        'cancellation_request',   -- Seller: buyer requested cancellation
        'cancellation_approved',  -- Buyer: seller approved cancellation
        'cancellation_rejected',  -- Buyer: seller rejected cancellation
        'chat',                   -- Buyer/Seller: chat message received
        -- Legacy types (backward compatibility)
        'order', 'promo', 'delivery', 'system'
    ));

-- 2. Add data JSON column for flexible payloads
ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS data jsonb DEFAULT NULL;

-- 3. Indexes on JSON fields (double parentheses required)
CREATE INDEX IF NOT EXISTS idx_notifications_data_order_id 
    ON notifications USING GIN ((data -> 'order_id'));

CREATE INDEX IF NOT EXISTS idx_notifications_data_conversation_id
    ON notifications USING GIN ((data -> 'conversation_id'));

-- 4. Fill null data with empty objects
UPDATE notifications SET data = '{}' WHERE data IS NULL;

-- 5. Row-Level Security policies (drop first, then create)
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role full access on notifications" ON notifications;
CREATE POLICY "Service role full access on notifications"
    ON notifications FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Users can read own notifications" ON notifications;
CREATE POLICY "Users can read own notifications"
    ON notifications FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Prevent direct user notification insertion (use service layer)" ON notifications;
CREATE POLICY "Prevent direct user notification insertion (use service layer)"
    ON notifications FOR INSERT WITH CHECK (false);