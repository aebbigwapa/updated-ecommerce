# 🚧 GCASH IMPLEMENTATION - MISSING ITEMS

## ✅ Already Done (Backend Logic - 70%)
- Database schema with payment columns
- Order model methods (upload_payment_proof, verify_payment)
- Order service logic (pending_payment status)

---

## ❌ Still Missing (Frontend & Routes - 30%)

### 1. **Buyer Upload Payment Proof Page**
**File:** `templates/buyer/upload_payment_proof.html`
- Form to upload GCash screenshot
- Shows order ID and total amount
- Submit button to upload receipt

### 2. **Buyer Upload Route**
**File:** `routes/buyer_routes.py`
- Route: `POST /buyer/orders/<order_id>/upload-proof`
- Handles file upload to Supabase storage
- Updates order with payment_proof_url
- Validates order belongs to buyer

### 3. **Seller Payment Verification Page**
**File:** `templates/seller/verify_payment.html`
- Lists all orders with status = 'pending_payment'
- Displays uploaded GCash screenshot
- Shows buyer info and order details
- Approve/Reject buttons

### 4. **Seller Verification Routes**
**File:** `routes/seller_routes.py`
- Route: `GET /seller/verify-payments` - Show pending payments
- Route: `POST /seller/orders/<order_id>/verify-payment` - Approve/reject
- Handles payment approval (deduct stock, change status)
- Handles payment rejection (cancel order, add reason)

### 5. **Checkout Redirect Logic**
**File:** `routes/buyer_routes.py` (checkout endpoint)
- After order creation, check payment method
- If GCash → redirect to upload proof page
- If COD → redirect to order summary

### 6. **SQL Migration Execution**
**File:** `migrations/gcash_payment_flow.sql`
- Run in Supabase SQL Editor
- Adds payment columns to orders table

---

## 📋 Quick Implementation Checklist

- [ ] Run SQL migration in Supabase
- [ ] Create `templates/buyer/upload_payment_proof.html`
- [ ] Add upload route in `routes/buyer_routes.py`
- [ ] Create `templates/seller/verify_payment.html`
- [ ] Add verification routes in `routes/seller_routes.py`
- [ ] Update checkout redirect logic
- [ ] Test full flow: checkout → upload → verify → approve

---

## ⏱️ Estimated Time: 1-2 hours

**Priority Order:**
1. Run SQL migration (5 min)
2. Create buyer upload page + route (30 min)
3. Create seller verification page + routes (45 min)
4. Update checkout redirect (10 min)
5. Testing (30 min)

---

## 🎯 What Happens After Completion:

**Buyer Flow:**
1. Checkout with GCash → Order created (pending_payment)
2. Upload GCash screenshot → Seller notified
3. Wait for seller verification

**Seller Flow:**
1. See pending payments with screenshots
2. Verify GCash receipt matches amount
3. Approve → Stock deducted, order proceeds
4. Reject → Order cancelled, buyer notified

---

**Ready to implement the missing items?**
