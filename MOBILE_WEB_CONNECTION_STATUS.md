# Mobile App ↔ Web App Connection Status

## ✅ CONFIRMED: Both Apps Are Connected

Your Flutter mobile app and web application are **fully integrated** and share the same backend infrastructure.

---

## Shared Infrastructure

### 1. **Same Flask Backend** (`app.py`)
- **Web routes**: `/admin`, `/seller`, `/buyer`, `/rider` (session-based)
- **Mobile API routes**: `/api/*` (token-based)
- Both registered in the same Flask app instance

### 2. **Same Supabase Database**
```
URL: https://opusrotqhtkhmeefvydh.supabase.co
```
- **Tables**: `users`, `products`, `orders`, `cart_items`, `applications`, `addresses`, etc.
- Both mobile and web read/write to the same database

### 3. **Unified Authentication**
- **Web**: Session cookies (`session['user_id']`)
- **Mobile**: JWT Bearer tokens (`Authorization: Bearer <token>`)
- Both methods validated by `api_helpers.py::get_current_user()`

---

## API Endpoints Used by Mobile App

### Authentication (`/api/auth/*`)
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/auth/login` | POST | Login (returns JWT token) |
| `/api/auth/register` | POST | Register new user |
| `/api/auth/send-otp` | POST | Send OTP to email |
| `/api/auth/verify-otp` | POST | Verify OTP |
| `/api/auth/me` | GET | Get current user info |
| `/api/auth/logout` | POST | Logout |

### Products (`/api/products/*`)
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/products` | GET | List all products |
| `/api/products/<id>` | GET | Get product details |

### Cart (`/api/cart/*`) — Requires Token
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/cart` | GET | Get cart items |
| `/api/cart` | POST | Add to cart |
| `/api/cart/<item_id>` | PATCH | Update quantity |
| `/api/cart/<item_id>` | DELETE | Remove item |
| `/api/cart/merge` | POST | Merge guest cart on login |

### Orders (`/api/orders/*`) — Requires Token
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/orders` | GET | List buyer orders |
| `/api/orders` | POST | Create order |
| `/api/orders/<id>` | GET | Get order details |
| `/api/orders/<id>/cancel` | POST | Cancel order |
| `/api/addresses` | GET | Get saved addresses |

### Seller (`/api/seller/*`) — Requires Seller Role
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/seller/dashboard` | GET | Seller stats |
| `/api/seller/products` | GET | List seller products |
| `/api/seller/products` | POST | Create product |
| `/api/seller/products/<id>` | PUT | Update product |
| `/api/seller/products/<id>` | DELETE | Delete product |
| `/api/seller/orders` | GET | Seller orders |
| `/api/seller/orders/<id>/status` | POST | Update order status |

### Rider (`/api/rider/*`) — Requires Rider Role
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/rider/dashboard` | GET | Rider stats + map data |
| `/api/rider/deliveries` | GET | Available + assigned deliveries |
| `/api/rider/deliveries/<id>/accept` | POST | Accept delivery |
| `/api/rider/deliveries/<id>/delivered` | POST | Mark as delivered |
| `/api/rider/earnings` | GET | Earnings history |

### Admin (`/api/admin/*`) — Requires Admin Role
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/admin/dashboard` | GET | Admin stats |
| `/api/admin/applications` | GET | List applications |
| `/api/admin/applications/<id>/status` | POST | Approve/reject |
| `/api/admin/users` | GET | List all users |
| `/api/admin/products` | GET | List all products |
| `/api/admin/products/<id>/status` | POST | Approve/reject product |
| `/api/admin/orders` | GET | List all orders |
| `/api/admin/orders/<id>/status` | POST | Update order status |

---

## Data Flow Example

### Scenario: User adds product to cart on mobile

1. **Mobile app** (`cart_screen.dart`):
   ```dart
   ApiService.addToCart(productId, quantity)
   ```

2. **API call** (`api_service.dart`):
   ```dart
   POST http://192.168.123.36:5000/api/cart
   Headers: Authorization: Bearer <token>
   Body: {"product_id": "...", "quantity": 1}
   ```

3. **Backend** (`cart_api.py`):
   ```python
   @cart_api_bp.post('/cart')
   @token_required
   def add_to_cart():
       # Validates token
       # Writes to Supabase cart_items table
   ```

4. **Database** (Supabase):
   ```sql
   INSERT INTO cart_items (user_id, product_id, quantity, ...)
   ```

5. **Web app** can now see the same cart:
   - User logs in on web browser
   - `/buyer/cart` route queries same `cart_items` table
   - Cart synced across devices

---

## Real-Time Sync Points

### ✅ Synced Across Mobile & Web:
- **User accounts** — Login on mobile, same account on web
- **Products** — Seller adds product on web, visible on mobile instantly
- **Cart** — Add to cart on mobile, see it on web (after refresh)
- **Orders** — Place order on mobile, admin sees it on web dashboard
- **Order status** — Seller updates on web, buyer sees on mobile
- **Applications** — Submit seller application on mobile, admin approves on web

### ⚠️ Not Real-Time (Requires Refresh):
- Cart changes (no WebSocket/polling yet)
- Order status updates (no push notifications yet)
- Product inventory changes

---

## Connection Verification Checklist

### Backend (Flask)
- [x] Flask server running on `http://192.168.123.36:5000`
- [x] CORS enabled for mobile (`FLASK_HOST=0.0.0.0`)
- [x] API routes registered (`/api/*`)
- [x] Token authentication working (`api_helpers.py`)

### Mobile App (Flutter)
- [x] `flaskBaseUrl` set to `http://192.168.123.36:5000`
- [x] API service configured (`api_service.dart`)
- [x] Token stored in SharedPreferences
- [x] All screens use `ApiService` methods

### Database (Supabase)
- [x] Same database URL in both apps
- [x] Service role key used by Flask backend
- [x] RLS policies allow backend access
- [x] Tables shared: `users`, `products`, `orders`, `cart_items`, etc.

---

## Testing the Connection

### 1. **Login Test**
```bash
# Mobile app
1. Open login screen
2. Enter: yasona.ryan11@gmail.com / password
3. Should redirect to home screen

# Web app
1. Go to http://192.168.123.36:5000/login
2. Enter same credentials
3. Should see same user dashboard
```

### 2. **Cart Sync Test**
```bash
# Mobile app
1. Add product to cart
2. Check cart screen

# Web app
1. Login with same account
2. Go to /buyer/cart
3. Should see same items (after refresh)
```

### 3. **Order Flow Test**
```bash
# Mobile app (Buyer)
1. Add items to cart
2. Checkout → Create order
3. Note order ID

# Web app (Seller)
1. Login as seller
2. Go to /seller/orders
3. Should see the order from mobile

# Web app (Admin)
1. Login as admin
2. Go to /admin/orders
3. Should see all orders including mobile orders
```

---

## Network Configuration

### Current Setup
```
PC IP: 192.168.123.36
Flask: http://192.168.123.36:5000
Mobile: Same WiFi network
```

### For Android Emulator
Change `flaskBaseUrl` to:
```dart
defaultValue: 'http://10.0.2.2:5000'
```

### For Production
1. Deploy Flask to cloud (AWS, Heroku, etc.)
2. Update `flaskBaseUrl` to production URL
3. Set `ALLOWED_ORIGINS` in `.env` to production domain

---

## Troubleshooting

### Mobile can't connect to backend
1. Check PC and phone on same WiFi
2. Verify Flask running: `http://192.168.123.36:5000/api/products`
3. Check firewall allows port 5000
4. Restart Flask with `FLASK_HOST=0.0.0.0`

### Token expired errors
- Tokens expire after 7 days
- User must login again
- Check `api_helpers.py::issue_token()` for TTL

### Cart not syncing
- Mobile uses token auth, web uses session
- Both write to same database
- Refresh web page to see mobile changes
- Consider adding WebSocket for real-time sync

---

## Summary

✅ **Your mobile and web apps are fully connected**
- Same backend (Flask)
- Same database (Supabase)
- Same business logic (models, services)
- Different auth methods (token vs session) but same user accounts
- All data synced through shared database tables

**No additional configuration needed** — they're already integrated!
