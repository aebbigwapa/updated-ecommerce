# E-Commerce System - Cart & Checkout

## Architecture

### Frontend
- React SPA with TypeScript
- Guest cart: localStorage + secure cookie fallback
- Auth state management with JWT

### Backend
- Node.js + Express
- PostgreSQL database
- JWT authentication
- Guest cart merge on login

## Key Features

1. **Unauthenticated Cart**: Browse, add, view, update, remove items without login
2. **Persistent Guest Cart**: Survives browser restarts via guest token
3. **Login Gate at Buy Now**: Mandatory auth before checkout, preserves cart
4. **Secure Checkout**: All checkout endpoints require valid JWT
5. **Cart Merge**: Guest cart merges with user cart on login

## Project Structure

```
/backend
  /src
    /models       - Database models
    /routes       - API endpoints
    /middleware   - Auth & validation
    /services     - Business logic
    server.ts     - Entry point

/frontend
  /src
    /components   - React components
    /services     - API client
    /hooks        - Custom hooks
    /types        - TypeScript types
    App.tsx       - Main app
```

## API Endpoints

### Products
- GET /api/products - List products
- GET /api/products/:id - Product detail

### Cart (Guest)
- POST /api/cart/guest - Add to guest cart
- GET /api/cart/guest/:guestToken - Get guest cart
- PUT /api/cart/guest/:guestToken - Update guest cart
- DELETE /api/cart/guest/:guestToken/item/:itemId - Remove item

### Cart (User - requires JWT)
- GET /api/cart - Get user cart
- POST /api/cart - Add to user cart
- PUT /api/cart - Update user cart
- DELETE /api/cart/item/:itemId - Remove item

### Auth
- POST /api/auth/signup - Register
- POST /api/auth/login - Login (merges guest cart)
- POST /api/auth/logout - Logout

### Checkout (requires JWT)
- POST /api/checkout/initiate - Start checkout
- POST /api/checkout/order - Place order
