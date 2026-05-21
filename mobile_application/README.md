# Grande Marketplace - Mobile App

A modern e-commerce Flutter application that perfectly matches your web app's UI/UX design, providing a seamless cross-platform shopping experience.

---

## 📖 Overview

**Grande Marketplace** is a production-ready mobile commerce application built with Flutter, connecting to the Grande Flask backend. The app delivers complete e-commerce functionality with a beautiful, consistent design across iOS, Android, and Web.

### Key Features

- ✅ **Cross-Platform**: Single codebase for iOS, Android, Web
- ✅ **Design Consistency**: Shares exact design system with web app
- ✅ **Role-Based Access**: Buyer, Seller, Rider, Admin experiences
- ✅ **Real-Time Updates**: WebSocket integration for live order tracking
- ✅ **Performance**: 60fps smooth scrolling and animations
- ✅ **Type-Safe**: Full null-safety and strong typing
- ✅ **Offline-First Ready**: Smart caching architecture

### Tech Stack

| Layer | Technology |
|-------|------------|
| **Framework** | Flutter 3.19+ |
| **Language** | Dart 3.3+ |
| **State** | Provider / `setState` (lightweight) |
| **API** | REST + Supabase (Realtime) |
| **Backend** | Flask (Python) |
| **Database** | PostgreSQL + Supabase |
| **Auth** | JWT + Supabase Auth |
| **Storage** | Supabase Storage |

---

## 📱 Project Structure

```
mobile_application/
├── lib/
│   ├── main.dart                      # App entry point & routing
│   │
│   ├── theme/
│   │   └── app_theme.dart            # Design system (colors, typography, spacing)
│   │
│   ├── widgets/                      # Reusable UI components
│   │   ├── grande_navbar.dart        # Top navigation bar
│   │   ├── grande_bottom_nav.dart    # Bottom navigation (in grande_navbar.dart)
│   │   ├── hero_carousel.dart        # Auto-rotating promotional carousel
│   │   ├── category_grid.dart        # Category browsing grid
│   │   ├── product_card.dart         # Individual product card
│   │   └── product_grid.dart         # Product listing grid
│   │
│   ├── screens/                      # Feature-specific pages
│   │   ├── auth/                     # Authentication flow
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   │
│   │   ├── buyer/                    # Buyer-facing features
│   │   │   ├── home_screen.dart
│   │   │   ├── shop_screen.dart
│   │   │   ├── product_detail_screen.dart
│   │   │   ├── cart_screen.dart
│   │   │   ├── checkout_screen.dart
│   │   │   ├── orders_screen.dart
│   │   │   └── profile_screen.dart
│   │   │
│   │   ├── seller/                   # Seller dashboard
│   │   │   ├── seller_dashboard_screen.dart
│   │   │   ├── seller_products_screen.dart
│   │   │   ├── seller_add_product_screen.dart
│   │   │   ├── seller_orders_screen.dart
│   │   │   ├── seller_earnings_screen.dart
│   │   │   ├── seller_store_profile_screen.dart
│   │   │   ├── seller_shipping_screen.dart
│   │   │   └── seller_reviews_screen.dart
│   │   │
│   │   ├── rider/                    # Rider delivery interface
│   │   │   └── rider_dashboard_screen.dart
│   │   │
│   │   └── admin/                    # Admin panel
│   │       ├── admin_dashboard_screen.dart
│   │       ├── admin_products_screen.dart
│   │       ├── admin_users_screen.dart
│   │       ├── admin_sellers_screen.dart
│   │       ├── admin_riders_screen.dart
│   │       └── admin_orders_screen.dart
│   │
│   ├── models/                      # Data models with JSON serialization
│   │   ├── product.dart
│   │   └── ...
│   │
│   └── services/                    # API and external service integration
│       ├── api_service.dart         # REST API client
│       ├── realtime_service.dart    # Supabase Realtime
│       ├── psgc_service.dart        # Location data (Philippines)
│       └── navigation_service.dart  # Navigation helper
│
├── android/                         # Android platform code
├── ios/                             # iOS platform code
├── web/                             # Web platform files
├── test/                            # Widget and integration tests
├── pubspec.yaml                     # Dependencies and configuration
└── analysis_options.yaml            # Linting and analysis rules
```

---

## 🎨 Design System

Perfect pixel-perfect match with your web app's design system.

### Color Palette

| Name | Hex | Usage |
|------|-----|-------|
| **Primary Light** | `#FF2BAC` | Main accents, buttons, badges |
| **Primary Mid** | `#FF6BCE` | Gradients, hover states |
| **Primary Dark** | `#FF9ED6` | Gradients, subtle backgrounds |
| **Accent Beige** | `#F5E6D3` | Cards, placeholders |
| **Text Dark** | `#2D3748` | Primary text |
| **Text Light** | `#718096` | Secondary text |
| **White** | `#FFFFFF` | Card backgrounds |
| **Gray Light** | `#F7FAFC` | Form fields, empty states |
| **Border** | `#CBD5E0` | Borders, dividers |

**Primary Gradient:** `#FF2BAC` → `#FF9ED6` (left-top to right-bottom)

### Typography

| Font | Usage | Examples |
|------|-------|----------|
| **Playfair Display** | Headlines, emphasis | Titles, logos, hero text |
| **Inter** | UI text, labels | Body, buttons, forms |

### Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| **XS** | 4dp | Icon spacing, tight gaps |
| **SM** | 8dp | Small padding, grid gaps |
| **MD** | 16dp | Standard padding, margins |
| **LG** | 24dp | Section padding, large gaps |
| **XL** | 32dp | Hero sections, page padding |
| **XXL** | 48dp | Hero sections, large containers |
| **XXXL** | 64dp | Full-screen heroes |

### Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| **SM** | 4dp | Buttons, chips |
| **MD** | 8dp | Cards, dialogs |
| **LG** | 12dp | Product cards, modals |
| **XL** | 16dp | Page containers |

### Shadows

| Name | Usage |
|------|-------|
| **Card Shadow** | Product cards, modals |
| **Subtle Shadow** | Hover states, subtle lifts |
| **Pink Glow** | Primary buttons, featured items |

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** 3.19.0 or higher
- **Dart** 3.3.0 or higher
- **Backend Server** Running Grande API (see root directory)
- **IDE**: Android Studio, VS Code, or IntelliJ with Flutter/Dart plugins
- **Mobile Device**: Android 5.0+ or iOS 12+ (for physical testing)

### Installation

1. **Clone the repository**

   ```bash
   cd mobile_application
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure API endpoint**

   Edit `lib/services/api_service.dart`:
   
   ```dart
   static const String flaskBaseUrl = 'http://YOUR_SERVER_IP:5000';
   ```
   
   - **Android Emulator**: Use `http://10.0.2.2:5000`
   - **Physical Device**: Use your machine's local IP (e.g., `http://192.168.1.172:5000`)
   - **iOS Simulator**: Use `http://localhost:5000`

4. **Initialize Supabase** (optional, for realtime)
   
   The app uses Supabase for realtime updates. Update in `lib/services/api_service.dart`:
   
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_ANON_KEY';
   ```

5. **Download fonts** (optional)
   
   The app uses system fallback fonts if custom fonts aren't available. For best results:
   - Download [Playfair Display](https://fonts.google.com/specimen/Playfair+Display)
   - Download [Inter](https://fonts.google.com/specimen/Inter)
   - Add to `fonts/` directory and update `pubspec.yaml`

6. **Run the app**

   ```bash
   # Android
   flutter run -d android
   
   # iOS
   flutter run -d ios
   
   # Web
   flutter run -d web
   ```

---

## 🔧 Development

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run with coverage
flutter test --coverage

# Generate coverage report
lcov --capture --directory . --output-file coverage.info
lcov --remove coverage.info '**/*.g.dart' --output-file coverage.info
```

### Code Generation

No code generation required. The project uses manual JSON serialization for transparency and control.

### Linting

The project uses strict linting rules defined in `analysis_options.yaml`:

```bash
# Analyze code for issues
flutter analyze

# Auto-fix common issues
flutter format .
```

### Hot Reload vs Hot Restart

- **Hot Reload** (`r`): Preserves app state, injects updated source
  - Use for: UI changes, widget tweaks, style adjustments
  
- **Hot Restart** (`Shift+r`): Rebuilds widget tree, resets state
  - Use for: Stateful logic changes, initialization updates

### Running with Backend

The Flutter app requires the Grande Flask backend:

```bash
# Terminal 1: Start Flutter app
cd mobile_application
flutter run -d chrome  # or android/ios

# Terminal 2: Start Flask backend
cd /path/to/project/root
python app.py
```

---

## 🏗️ Architecture Patterns

### State Management

The app uses a **lightweight state management approach**:

- **Local State:** `StatefulWidget` with `setState()` for screen-specific state
- **Navigation State:** Managed through `MaterialApp` named routes
- **Session State:** `SharedPreferences` for auth tokens and user data
- **API State:** Singleton `ApiService` for centralized HTTP requests

**Why not Provider/Bloc/Riverpod?**

For this scale, `setState()` provides:
- Lower learning curve for new developers
- Less boilerplate
- Direct control over updates
- Easier debugging

Future scaling could introduce provider patterns for complex shared state.

### Navigation Pattern

**Declarative routing** with named routes:

```dart
MaterialApp(
  initialRoute: '/auth',
  routes: {
    '/home': (context) => HomeScreen(),
    '/product': (context) {
      final id = ModalRoute.of(context)?.settings.arguments as String;
      return ProductDetailScreen(productId: id);
    },
  },
)
```

**Navigation features:**
- All routes defined centrally in `main.dart`
- Arguments via `ModalRoute.of(context)?.settings.arguments`
- Deep linking support (ready for future enhancement)
- Named routes enable easy A/B testing and analytics

### API Integration Pattern

**Singleton service pattern** (`ApiService`):

```dart
class ApiService {
  static Future<List<Product>> getProducts() async {
    final token = await getAuthToken();
    final res = await http.get(...);
    return parseProducts(res.body);
  }
}
```

**Benefits:**
- Single instance across the app
- Automatic header injection (auth tokens)
- Centralized error handling
- Easy mocking for testing
- Consistent timeout and retry logic

### Data Flow

```
UI (Widget)
    ↓
setState() triggers rebuild
    ↓
ApiService method call
    ↓
HTTP Request (REST + JSON)
    ↓
Backend API (Flask)
    ↓
Database (PostgreSQL)
    ↓
JSON Response
    ↓
Model.fromJson()
    ↓
setState() with new data
    ↓
UI rebuilds with fresh data
```

### Folder Structure Philosophy

**Feature-based organization:**

- Screens are grouped by user role (buyer/seller/rider/admin)
- Widgets are reusable across features
- Models are domain-agnostic
- Services are layer-agnostic

**Why not by layer (MVC)?**

Feature organization makes it easier to:
- Understand what belongs together
- Navigate related code
- Add/remove features
- Work on independent modules

---

## 📝 Widget Documentation

See **[WIDGET_CATALOG.md](./WIDGET_CATALOG.md)** for comprehensive documentation of all custom widgets:

### Navigation Widgets
- **GrandeNavbar** - Top app bar with gradient logo
- **GrandeBottomNav** - Shopee-style bottom navigation

### Display Widgets
- **HeroCarousel** - Auto-rotating promotional banners
- **CategoryGrid** - Browse by category with emojis

### Product Widgets
- **ProductCard** - Individual product display
- **ProductGrid** - Product collections with "View All"

---

## 🎯 Features

### ✅ Buyer Experience

- **Browse & Discover:** Categories, search, filters
- **Product Details:** Images, variants, pricing, stock
- **Shopping Cart:** Add/remove, quantity adjustment
- **Checkout:** Address selection, payment methods
- **Order Tracking:** Real-time status updates
- **Order History:** Past orders with details
- **Profile Management:** Account info, settings

### ✅ Seller Dashboard

- **Product Management:** CRUD with images
- **Order Fulfillment:** Status updates, shipping
- **Sales Analytics:** Earnings, stats, trends
- **Store Profile:** Branding, description
- **Shipping Settings:** Configurable options
- **Customer Reviews:** View and respond

### ✅ Rider Dashboard

- **Earnings Overview:** Total, today, weekly, monthly earnings display
- **Delivery Statistics:** Total, completed, active deliveries, and rate per delivery
- **Recent Deliveries:** List of latest orders with status indicators (pending, in_transit, delivered)
- **Quick Actions:** One-tap access to deliveries, earnings, and profile sections
- **Pull-to-Refresh:** Real-time data synchronization
- **Delivery Status Tracking:** Color-coded status badges for order visibility
- **Profile Management:** Access to rider profile and settings
- **Logout:** Secure session termination

### ✅ Authentication

- **Email/Password Login:** Secure authentication
- **New User Registration:** Multi-role signup
- **Session Persistence:** Auto-login on app start
- **Token-Based Security:** JWT validation
- **Password Reset:** Email-based recovery (backend)

### ✅ Role-Based Access

| Role | Access |
|------|--------|
| **Buyer** | Browse, cart, checkout, orders, profile |
| **Seller** | Product/order management, analytics, reviews |
| **Rider** | Delivery management, earnings tracking, order pickup/delivery, stats dashboard |
| **Admin** | Full system oversight, user management |

---

## 🔐 Authentication Flow

```
1. User opens app
   ↓
2. AuthWrapper checks SharedPreferences for token
   ↓
   ├─ Token exists → Validate silently (no network)
   │                ↓
   │                Navigate to HomeScreen (guest mode)
   │
   └─ No token → Navigate to LoginScreen
                         ↓
                  User logs in
                         ↓
              Token saved to SharedPreferences
                         ↓
              Navigate to HomeScreen
                         ↓
       Subsequent launches skip login
```

**Note:** The current implementation uses a **guest-first** approach where users can browse without logging in. Login is required for cart, checkout, and order history.

---

## 📊 Testing Strategy

### What's Tested

- **Widget Rendering:** UI components build correctly
- **User Interactions:** Taps, swipes, form inputs
- **Navigation:** Route transitions, argument passing
- **Form Validations:** Required fields, formats
- **API Error Handling:** Network failures, server errors
- **Empty States:** No data, loading states
- **Edge Cases:** Null safety, boundary conditions

### Test Coverage Goals

| Category | Target | Current |
|----------|--------|---------|
| Widget tests | 80% | ~60% |
| Integration tests | 10+ flows | 3 flows |
| Critical paths | 100% | 90% |

**Critical Paths:**
1. Login → Browse → Cart → Checkout
2. Product search → Details → Add to cart
3. Order placement → Confirmation → Tracking

---

## 🚀 Deployment

### Android Build

```bash
# Generate release APK (for direct distribution)
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Generate App Bundle (for Play Store)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

**Play Store Requirements:**
- App signing (configure `android/key.properties`)
- Target API level 34+ (Android 14)
- Privacy policy URL
- Screenshots for all device sizes

### iOS Build

```bash
# Build for release
flutter build ios --release

# Archive and distribute via Xcode
open ios/Runner.xcworkspace
# Xcode → Product → Archive → Distribute App
```

**Apple Store Requirements:**
- Apple Developer account ($99/year)
- App Store Connect setup
- Privacy manifest files
- App tracking transparency (if using ads)

### Web Build

```bash
flutter build web --release
# Output: build/web
```

**Deployment Options:**
- Firebase Hosting
- Netlify / Vercel
- GitHub Pages
- Any static file host

**Note:** Web requires CORS configuration on backend:
```python
# Flask CORS setup
CORS(app, origins=['https://your-domain.com'])
```

---

## 🔍 Troubleshooting

### Common Issues

**"Target of URI doesn't exist"**
```bash
flutter pub get
flutter clean
flutter pub get
```

**"Failed to build for iOS"**
```bash
cd ios
pod install
pod update
cd ..
```

**"Network image not loading"**
- Check API base URL configuration
- Verify backend is running and accessible
- Test with a known-good image URL
- Check CORS headers on backend
- For Android emulator, use `10.0.2.2` for localhost

**"Android build fails - Gradle version"**
```bash
cd android
./gradlew wrapper --gradle-version=8.0
cd ..
```

**"iOS build fails - CocoaPods"**
```bash
cd ios
rm -rf Pods Podfile.lock
pod cache clean --all
pod install
cd ..
```

**"App crashes on startup"**
- Check SharedPreferences initialization
- Verify Supabase URL and keys
- Review logs: `flutter run --verbose`
- Ensure all required permissions in `AndroidManifest.xml`/`Info.plist`

**"Images fail to load from backend"**
- Check Flask static file serving
- Verify `MEDIA_URL` and `MEDIA_ROOT` in Flask config
- Ensure CORS allows image requests
- Check file permissions on server

---

## 📚 Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Documentation](https://dart.dev/guides)
- [Material Design Guidelines](https://material.io/design)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook)
- [API Documentation](../README.md)
- [Widget Catalog](./WIDGET_CATALOG.md)

---

## 🤝 Contributing

### Code Style

- Follow existing patterns and conventions
- Use `AppTheme` for all styling (no hardcoded values)
- Keep widgets small and focused (< 300 lines ideally)
- Add widget tests for new features
- Document public APIs with DartDoc comments
- Use `const` constructors where possible
- Handle null safety explicitly (avoid `!` unless certain)

### Pull Request Process

1. **Create feature branch** from `main`
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Implement feature** with tests
   - Write widget tests for UI changes
   - Test on multiple screen sizes
   - Verify accessibility

3. **Run quality checks**
   ```bash
   flutter analyze  # No errors
   flutter format .  # Properly formatted
   flutter test     # All tests pass
   ```

4. **Submit PR**
   - Clear title and description
   - Screenshots for UI changes
   - Link to related issues
   - Checklist of what was tested

### Code Review Checklist

- ✅ Follows project style guidelines
- ✅ No hardcoded colors/fonts/spacing
- ✅ Null safety handled properly
- ✅ Widgets are testable
- ✅ Error states handled
- ✅ Loading states handled
- ✅ Empty states handled
- ✅ Accessibility considered
- ✅ Performance impact evaluated

---

## 📄 License

This project is part of the Grande Marketplace ecosystem. See root directory for license details.

The Flutter app is provided as-is for educational and commercial use under the project's terms.

---

## 🌟 Acknowledgments

- **Flutter Team** for the amazing framework
- **Material Design** for design inspiration
- **Community Contributors** and testers
- **Open Source Libraries** that make this possible

---

**Built with Flutter** 🎨 | **Version 1.0** | **Last Updated: 2026-05-07**

For questions or issues, please refer to the project documentation or contact the development team.