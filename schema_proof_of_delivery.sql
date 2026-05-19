-- ============================================================
-- MIGRATION: Proof of Delivery Enhancement
-- Adds proof_of_delivery_url column to orders table
-- Run once on existing databases.
-- ============================================================

-- Add proof of delivery URL column to orders table
ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS proof_of_delivery_url text,
    ADD COLUMN IF NOT EXISTS proof_uploaded_at timestamptz;

-- Create index for faster queries on orders with proof
CREATE INDEX IF NOT EXISTS idx_orders_proof_uploaded ON orders(proof_uploaded_at) WHERE proof_uploaded_at IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN orders.proof_of_delivery_url IS 'URL to proof of delivery image uploaded by rider';
COMMENT ON COLUMN orders.proof_uploaded_at IS 'Timestamp when rider uploaded proof of delivery';
