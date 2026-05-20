# GCash Payment Flow - Mobile App Implementation ✅

## Files Created

### 1. Buyer Upload Screen
**File:** `lib/screens/buyer/upload_payment_proof_screen.dart`
- Image picker (camera/gallery)
- Order info display
- Instructions for GCash payment
- Upload with progress indicator
- Drag & drop support

### 2. Seller Verification Screen
**File:** `lib/screens/seller/seller_verify_payments_screen.dart`
- Lists orders with `pending_payment` status
- Displays payment proof images
- Fullscreen image viewer
- Approve/Reject with reason
- Real-time refresh

### 3. API Service Updates
**File:** `lib/services/api_service.dart`
- `uploadPaymentProof(orderId, imageFile)` - Upload receipt
- `getPendingPaymentOrders()` - Get orders awaiting verification
- `verifyPayment(orderId, approved, reason)` - Approve/reject payment

### 4. Routes Added
**File:** `lib/main.dart`
- `/upload-payment-proof` - Buyer upload page
- `/seller/verify-payments` - Seller verification page

### 5. Checkout Flow Updated
**File:** `lib/screens/buyer/checkout_screen.dart`
- Detects GCash payment method
- Redirects to upload proof page after order creation
- Other payment methods go to order summary

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    BUYER FLOW                                │
└─────────────────────────────────────────────────────────────┘

1. Checkout with GCash
   ↓
2. Order created (status: pending_payment)
   ↓
3. Redirect to Upload Payment Proof Screen
   ↓
4. Take photo or select from gallery
   ↓
5. Upload GCash screenshot
   ↓
6. Wait for seller verification
   ↓
7. Redirect to Orders page


┌─────────────────────────────────────────────────────────────┐
│                   SELLER FLOW                                │
└─────────────────────────────────────────────────────────────┘

1. Navigate to "Verify Payments" menu
   ↓
2. See list of orders with uploaded proofs
   ↓
3. View payment screenshot (tap to zoom)
   ↓
4. Verify amount matches order total
   ↓
5. Approve → Stock deducted, order moves to "pending"
   OR
   Reject → Order cancelled, buyer notified
```

## Key Features

### Buyer Side
- ✅ Image picker with camera/gallery options
- ✅ Image preview before upload
- ✅ Order details display (ID, amount, payment method)
- ✅ Clear instructions for GCash payment
- ✅ Upload progress indicator
- ✅ Automatic redirect after successful upload

### Seller Side
- ✅ List of pending payment orders
- ✅ Payment proof image display
- ✅ Fullscreen image viewer with zoom
- ✅ Order details (buyer info, items, amount)
- ✅ Approve/Reject buttons
- ✅ Rejection reason input
- ✅ Confirmation dialogs
- ✅ Real-time notifications

## Backend Integration

All endpoints already exist in the Flask backend:
- `POST /buyer/orders/<order_id>/upload-proof` - Upload receipt
- `GET /seller/verify-payments` - List pending payments
- `POST /seller/orders/<order_id>/verify-payment` - Approve/reject

## Dependencies Required

Add to `pubspec.yaml`:
```yaml
dependencies:
  image_picker: ^1.0.0  # For camera/gallery access
```

## Testing Checklist

- [ ] Buyer can select GCash at checkout
- [ ] Order created with `pending_payment` status
- [ ] Buyer redirected to upload proof page
- [ ] Image picker works (camera & gallery)
- [ ] Image preview displays correctly
- [ ] Upload succeeds and shows success message
- [ ] Seller sees order in verify payments list
- [ ] Payment proof image displays correctly
- [ ] Fullscreen viewer works with zoom
- [ ] Approve button deducts stock and updates status
- [ ] Reject button cancels order
- [ ] Buyer receives notification after verification

## Notes

- Stock is NOT deducted until seller approves payment
- Orders stay in `pending_payment` until verified
- Rejected orders are automatically cancelled
- Buyer can only upload proof once per order
- Seller can only verify orders containing their products
