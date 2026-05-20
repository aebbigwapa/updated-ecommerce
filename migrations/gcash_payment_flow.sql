-- GCash Payment Flow Migration

-- Add payment proof columns to orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_proof_url TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_verified_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_verified_by UUID REFERENCES users(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_rejection_reason TEXT;

-- Update orders status constraint to include pending_payment
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE orders ADD CONSTRAINT orders_status_check 
CHECK (status IN (
    'pending_payment',   -- Waiting for payment proof upload/verification
    'pending',           -- Payment verified, waiting for seller to process
    'processing',        -- Seller is preparing the order
    'ready_for_pickup',  -- Ready for rider to pick up
    'in_transit',        -- Rider is delivering
    'delivered',         -- Order completed
    'cancelled'          -- Order cancelled
));

-- Create index for payment verification queries
CREATE INDEX IF NOT EXISTS idx_orders_payment_verified ON orders(payment_verified);
CREATE INDEX IF NOT EXISTS idx_orders_payment_proof ON orders(payment_proof_url) WHERE payment_proof_url IS NOT NULL;
