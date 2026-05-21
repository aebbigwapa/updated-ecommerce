-- Add shipping fee configuration to admin_settings

-- Insert shipping fee settings
INSERT INTO admin_settings (key, value) VALUES
    ('shipping_base_fee', '40'),
    ('shipping_per_km_rate', '10'),
    ('shipping_min_fee', '50')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- Add shipping_fee column to orders table if not exists
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipping_fee NUMERIC(10, 2) DEFAULT 0;

-- Add distance_km column to orders table if not exists
ALTER TABLE orders ADD COLUMN IF NOT EXISTS distance_km NUMERIC(10, 2) DEFAULT 0;

-- Update existing orders with default shipping fee
UPDATE orders SET shipping_fee = 50 WHERE shipping_fee = 0 OR shipping_fee IS NULL;
