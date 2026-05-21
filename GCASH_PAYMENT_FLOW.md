# 🔧 GCASH PAYMENT FLOW - IMPLEMENTATION

## Current Problem:
- ❌ GCash creates order immediately (wrong!)
- ❌ No receipt upload
- ❌ No seller verification

## Correct Flow:

### 1. Buyer Checkout (GCash selected)
```
Order Status: "pending_payment"
- Order created but NOT confirmed
- Stock NOT deducted yet
- Buyer sees: "Upload GCash receipt to confirm order"
```

### 2. Buyer Uploads Receipt
```
- Upload screenshot of GCash payment
- Saved to: payment_proofs bucket
- Order status: still "pending_payment"
- Seller notified: "New payment proof to verify"
```

### 3. Seller Verifies Receipt
```
- Seller checks GCash receipt
- Options:
  ✅ Approve → Order status: "processing", stock deducted
  ❌ Reject → Order cancelled, buyer notified
```

### 4. Order Proceeds
```
- After approval: normal order flow
- Seller prepares order
- Rider delivers
```

---

## Database Changes Needed:

### Add columns to orders table:
```sql
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_proof_url TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_verified_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_verified_by UUID REFERENCES users(id);
```

---

## Implementation Steps:

### STEP 1: Update Order Status Options

Add new status: `pending_payment`

```sql
-- Update orders status check constraint
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE orders ADD CONSTRAINT orders_status_check 
CHECK (status IN (
    'pending_payment',  -- NEW: Waiting for payment proof
    'pending', 
    'processing', 
    'ready_for_pickup', 
    'in_transit', 
    'delivered',
    'cancelled'
));
```

### STEP 2: Update Checkout Flow

When GCash selected:
- Create order with status = 'pending_payment'
- DON'T deduct stock yet
- Show upload receipt page

### STEP 3: Create Receipt Upload Page

```html
<!-- templates/buyer/upload_payment_proof.html -->
<form id="uploadProofForm">
    <h3>Upload GCash Payment Proof</h3>
    <p>Order #{{ order_id }}</p>
    <p>Amount: ₱{{ total_amount }}</p>
    
    <div>
        <label>GCash Receipt Screenshot:</label>
        <input type="file" name="receipt" accept="image/*" required>
    </div>
    
    <button type="submit">Submit Proof</button>
</form>
```

### STEP 4: Create Seller Verification Page

```html
<!-- templates/seller/verify_payment.html -->
<div class="payment-proof">
    <img src="{{ payment_proof_url }}" alt="Payment Proof">
    
    <div class="order-details">
        <p>Order #{{ order_id }}</p>
        <p>Amount: ₱{{ total_amount }}</p>
        <p>Buyer: {{ buyer_name }}</p>
    </div>
    
    <div class="actions">
        <button onclick="approvePayment()">✅ Approve</button>
        <button onclick="rejectPayment()">❌ Reject</button>
    </div>
</div>
```

---

## Quick Fix (Temporary):

For now, you can:

### Option A: Disable GCash
Remove GCash option from checkout until proper flow is implemented.

### Option B: Treat GCash as COD
Change GCash to work like COD (pay on delivery).

### Option C: Implement Full Flow
Follow the implementation guide above.

---

## Recommendation:

**OPTION A (Quick):** Disable GCash for now
- Remove from checkout.html
- Add note: "Coming soon"
- Implement properly later

**OPTION C (Proper):** Implement full flow
- Takes 2-3 hours
- Proper payment verification
- Better user experience

---

**Ano gusto mo?**

A. **Disable GCash muna** (5 minutes)
B. **Implement full GCash flow** (2-3 hours)
C. **Keep as-is** (treat as COD)
