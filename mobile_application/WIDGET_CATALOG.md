# Widget Catalog

## Overview

This document provides comprehensive documentation for all custom widgets in the Grande Marketplace mobile application. Each widget is designed to perfectly match the web application's UI/UX design, utilizing the shared design system defined in `AppTheme`.

---

## Table of Contents

1. [Navigation Widgets](#navigation-widgets)
   - [GrandeNavbar](#grandenavbar)
   - [GrandeBottomNav](#grandebottomnav)
2. [Display Widgets](#display-widgets)
   - [HeroCarousel](#herocarousel)
   - [CategoryGrid](#categorygrid)
3. [Product Widgets](#product-widgets)
   - [ProductCard](#productcard)
   - [ProductGrid](#productgrid)

---

## Navigation Widgets

### GrandeNavbar

**Type:** `StatelessWidget` (implements `PreferredSizeWidget`)

**File:** `lib/widgets/grande_navbar.dart`

**Purpose:**
Top navigation bar featuring the Grande logo with gradient text effect. Serves as the primary app header across all screens.

**Properties:**

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `active` | `String` | Yes | Current active route name for highlighting |
| `userName` | `String?` | No | Optional user name for personalization |

**API Reference:**

```dart
class GrandeNavbar extends StatelessWidget implements PreferredSizeWidget {
  final String active;
  final String? userName;
  // ...
}
```

**Key Implementation Details:**

- **Height:** Fixed at 56dp (standard Material AppBar height)
- **Background:** Solid white (`AppTheme.white`) with subtle shadow
- **Title:** Gradient text effect using `ShaderMask` with `AppTheme.primaryGradient`
- **Font:** Playfair Display, 24sp, bold weight
- **Elevation:** 1dp shadow with border color
- **Leading:** No back button (uses `automaticallyImplyLeading: false`)
- **Actions:** Empty array (reserved for future cart/user menu integration)

**Usage Example:**

```dart
Scaffold(
  appBar: GrandeNavbar(
    active: '/home',
    userName: 'John Doe',
  ),
  body: ...
)
```

**Visual Description:**
A clean white app bar with a prominent pink-gradient "Grande" logo on the left. The header sits on top of content with a subtle drop shadow (1dp elevation) providing depth. No back button allows full-screen content to utilize full width.

**Design System Integration:**

- **Background:** `AppTheme.white`
- **Gradient:** `AppTheme.primaryGradient` (#FF2BAC → #FF9ED6)
- **Border Color:** `AppTheme.border` (#CBD5E0)
- **Font:** `AppTheme.fontDisplay` (Playfair Display)
- **Title Size:** 24sp
- **Elevation:** 1dp with shadow color `AppTheme.border`

**Best Practices:**

- Use as the primary navigation header across all screens
- The `active` parameter can be used for active route highlighting in future iterations
- Maintains consistent 56dp height across all platforms per Material Design specs
- Gradient text is achieved via `ShaderMask` for crisp rendering

**Accessibility:**

- High contrast ratio (white background, gradient text)
- Semantic label "Grande Marketplace" implied
- Can be enhanced with explicit semantics labels if needed

**Testing Guidelines:**

```dart
testWidgets('GrandeNavbar renders correctly', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        appBar: GrandeNavbar(active: '/home'),
      ),
    ),
  );
  expect(find.text('Grande'), findsOneWidget);
  expect(find.byType(ShaderMask), findsOneWidget);
});
```

**Version History:**

- **v1.0:** Initial implementation with gradient logo

---

### GrandeBottomNav

**Type:** `StatelessWidget`

**File:** `lib/widgets/grande_navbar.dart` (same file)

**Purpose:**
Shopee-style bottom navigation bar providing access to core app features: Home, Shop, Orders, and Profile.

**Properties:**

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `currentIndex` | `int` | Yes | Index of currently selected tab (0-3) |

**Route Mapping:**

| Index | Label | Route | Icon (inactive) | Icon (active) |
|-------|-------|-------|-----------------|---------------|
| 0 | Home | `/home` | `home_outlined` | `home` |
| 1 | Shop | `/shop` | `storefront_outlined` | `storefront` |
| 2 | Orders | `/orders` | `receipt_long_outlined` | `receipt_long` |
| 3 | Profile | `/profile` | `person_outline` | `person` |

**Key Implementation Details:**

- **Type:** `BottomNavigationBarType.fixed` (all items always visible)
- **Background:** Solid white
- **Selected Color:** `AppTheme.primaryLight` (#FF2BAC)
- **Unselected Color:** `AppTheme.textLight` (#718096)
- **Elevation:** 8dp (pronounced shadow for floating effect)
- **Item Style:** 11sp font, semibold when selected
- **Navigation:** Replaces entire route stack on tap (no back button accumulation)

**Usage Example:**

```dart
class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getBody(_currentIndex),
      bottomNavigationBar: GrandeBottomNav(
        currentIndex: _currentIndex,
      ),
    );
  }
}
```

**Visual Description:**
A white bottom bar with 4 evenly spaced tab items. The selected tab glows with the signature pink primary color. Large 8dp elevation casts a soft shadow upward, giving the bar a floating card appearance. All items remain visible and accessible at all times, making it ideal for primary navigation between 2-5 top-level destinations.

**Design System Integration:**

- **Background:** `AppTheme.white`
- **Selected Color:** `AppTheme.primaryLight`
- **Unselected Color:** `AppTheme.textLight`
- **Font:** `AppTheme.fontBody` (Inter), 11sp
- **Elevation:** 8dp
- **Border Radius:** None (full-width bar)
- **Item Style:** Bold when selected, regular when unselected

**Behavior:**

- Tap anywhere on bottom nav: full-screen replacement navigation
- Maintains `currentIndex` state externally (parent widget)
- Pushes new route and removes all previous routes (`pushNamedAndRemoveUntil`)
- Selected tab does not re-trigger navigation

**Best Practices:**

- Use for primary navigation between 2-5 top-level destinations
- Keep parent widget stateful to manage `currentIndex`
- Each destination should be a full-screen scaffold
- Avoid using with `BottomNavigationBarType.shifting` (fixed is better for 4 items)
- Ensure all screens have their own app bars for context

**Accessibility:**

- Large 48dp+ touch targets (Material spec)
- Semantic labels via icons ("Home", "Shop", "Orders", "Profile")
- Color contrast meets WCAG AA standards
- Icons have filled variants for selected state (visual weight)

**Testing Guidelines:**

```dart
testWidgets('GrandeBottomNav switches tabs', (tester) async {
  int currentIndex = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Text('Screen $currentIndex'),
        bottomNavigationBar: GrandeBottomNav(
          currentIndex: currentIndex,
        ),
      ),
    ),
  );
  // Note: Navigation test would require mocking Navigator
});
```

**Version History:**

- **v1.0:** Shopee-style implementation with 4 fixed tabs

---

## Display Widgets

### HeroCarousel

**Type:** `StatefulWidget`

**File:** `lib/widgets/hero_carousel.dart`

**Purpose:**
Full-width auto-rotating promotional banner for featured collections, sales, and announcements on the home screen.

**Properties:**

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| (none) | - | - | Self-contained with built-in demo slides |

**Slide Class:**

```dart
class HeroSlide {
  final String title;
  final String subtitle;
  final String buttonText;
  final Gradient gradient;
}
```

**Key Implementation Details:**

- **Height:** Fixed at 400dp
- **Auto-Play:** 5-second interval between slides
- **Manual Navigation:** Left/right arrow buttons overlay
- **Indicators:** Dot pagination at bottom center
- **Animation:** 300ms page transition with `Curves.easeInOut`
- **Slide Count:** 3 demo slides (configurable)
- **Button Action:** Navigate to `/shop` on tap
- **Background:** Gradient fills entire slide

**Usage Example:**

```dart
HeroCarousel()
```

Or with custom slides (modify source):

```dart
// In _HeroCarouselState
final List<HeroSlide> _slides = [
  HeroSlide(
    title: 'Your Title',
    subtitle: 'Your subtitle text',
    buttonText: 'Action',
    gradient: LinearGradient(
      colors: [AppTheme.primaryLight, AppTheme.primaryDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  // Add more...
];
```

**Visual Description:**
A striking full-width banner with vibrant gradient backgrounds. Large display text (48sp Playfair Display) dominates with a smaller subtitle. A prominent white "Shop Now" button sits below. Left/right arrow navigation buttons float on the sides with semi-transparent dark backgrounds. Small circular page indicators show progress at the bottom. Auto-rotates every 5 seconds with smooth horizontal swipes.

**Design System Integration:**

- **Size:** 400dp height
- **Typography:** Playfair Display 48sp (title), Inter 18sp (subtitle)
- **Button:** White background, pink text, rounded corners
- **Spacing:** Uses `AppTheme.md`, `AppTheme.lg`, `AppTheme.xl`
- **Gradients:** Multiple pink/purple/orange combinations
- **Icons:** Material Design icons with white color
- **Overlay:** 30% black alpha on navigation buttons

**Interactions:**

1. **Auto-Play:** Advances every 5 seconds
2. **Swipe:** Horizontal drag to change slides
3. **Arrows:** Manual previous/next
4. **Dots:** Visual indicator (not interactive)
5. **Button:** Tap to go to shop

**Lifecycle:**

- `initState`: Starts autoplay timer
- `dispose`: Cancels timers and disposes page controller
- `mounted` checks prevent state updates after disposal

**Best Practices:**

- Use only on home screen or landing pages
- Limit to 3-5 slides to avoid fatigue
- Keep text concise (1-2 lines max)
- Ensure sufficient contrast on gradients
- Optimize images for fast loading (not implemented here)
- Consider pausing autoplay on user interaction (future enhancement)

**Accessibility:**

- Semantic labels on buttons ("Previous slide", "Next slide")
- High contrast text on gradients
- Large touch targets (48dp minimum)
- Consider adding pause/play control for auto-rotation
- Screen reader support could announce slide changes

**Performance:**

- All content is local (no network images in demo)
- PageView caches adjacent slides
- Timer properly disposed on widget destruction
- `mounted` checks prevent memory leaks

**Testing Guidelines:**

```dart
testWidgets('HeroCarousel builds and auto-plays', (tester) async {
  await tester.pumpWidget(
    MaterialApp(home: HeroCarousel()),
  );
  expect(find.text('New Collection'), findsOneWidget);
  expect(find.byType(PageView), findsOneWidget);
  expect(find.byType(ElevatedButton), findsOneWidget);
  // Auto-play test would require pumping with time
});
```

**Version History:**

- **v1.0:** Initial implementation with 3 demo slides, auto-play, manual nav

---

### CategoryGrid

**Type:** `StatelessWidget`

**File:** `lib/widgets/category_grid.dart`

**Purpose:**
Browse products by visual category cards using emojis with category names and descriptions.

**Properties:**

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| (none) | - | - | Self-contained with built-in categories |

**Category Class:**

```dart
class Category {
  final String emoji;
  final String name;
  final String description;
}
```

**Built-in Categories:**

| Emoji | Name | Description |
|-------|------|-------------|
| 👗 | Dresses & Skirts | Elegant dresses and skirts for every occasion |
| 👚 | Tops & Blouses | Stylish tops and blouses for casual and formal wear |
| 🏃‍♀️ | Activewear & Yoga Pants | Comfortable activewear for your fitness journey |
| 👙 | Lingerie & Sleepwear | Intimate apparel and comfortable sleepwear |
| 🧥 | Jackets & Coats | Warm and stylish outerwear for all seasons |
| 👠 | Shoes & Accessories | Complete your look with shoes and accessories |

**Key Implementation Details:**

- **Layout:** 3-column grid (`crossAxisCount: 3`)
- **Spacing:** `AppTheme.md` between cards
- **Card Size:** 110dp height fixed
- **Card Background:** `AppTheme.grayLight` with subtle shadow
- **Border:** 1dp `AppTheme.border`
- **Typography:** 28sp emoji, 11sp category name
- **Tap Action:** Navigate to `/shop` with category name as argument
- **Scrollable:** Uses `NeverScrollableScrollPhysics` (grid is inside scrollable parent)

**Usage Example:**

```dart
CategoryGrid()
```

Custom categories (modify source):

```dart
// In CategoryGrid build method
final categories = [
  Category(
    emoji: '👗',
    name: 'Your Category',
    description: 'Your description',
  ),
  // Add more...
];
```

**Visual Description:**
A section header "Shop by Category" in large Playfair Display (32sp). Below is a 3-column grid of square-ish cards with light gray backgrounds, soft shadows, and thin borders. Each card displays a large emoji (28sp) with the category name below in small, bold text (11sp). Cards have rounded corners (12dp) and subtle depth.

**Design System Integration:**

- **Header:** Playfair Display 32sp, bold, `AppTheme.textDark`
- **Background:** `AppTheme.white` section
- **Card Background:** `AppTheme.grayLight`
- **Card Border:** `AppTheme.border`
- **Shadow:** `AppTheme.subtleShadow`
- **Font:** Inter 11sp bold for names
- **Padding:** `AppTheme.xl` outer, `AppTheme.md` inner
- **Border Radius:** `AppTheme.radiusLg` (12dp)

**Interactions:**

- Tap any category card: Navigates to `/shop` with category name as argument
- Visual feedback: Touch ripple (Material default)

**Best Practices:**

- Use 3-column layout for mobile portrait
- Limit to 6-9 categories max (2-3 rows)
- Emojis render consistently across platforms but consider SVGs for production
- Keep names short (2-3 words max)
- Use descriptive but concise descriptions (not always visible)
- Ensure tap targets are at least 48dp (cards are ~110dp)

**Accessibility:**

- Semantic labels could include category description
- Emojis have inherent meaning but may not translate to screen readers
- Consider alt text for screen readers
- High contrast text (dark on light background)
- Large touch targets

**Testing Guidelines:**

```dart
testWidgets('CategoryGrid displays categories', (tester) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: CategoryGrid())),
  );
  expect(find.text('Shop by Category'), findsOneWidget);
  expect(find.text('Dresses & Skirts'), findsOneWidget);
  expect(find.text('👗'), findsOneWidget);
  expect(find.byType(GridView), findsOneWidget);
});
```

**Version History:**

- **v1.0:** 6 categories with emoji icons, grid layout

---

## Product Widgets

### ProductCard

**Type:** `StatelessWidget`

**File:** `lib/widgets/product_card.dart`

**Purpose:**
Individual product display card showing image, name, seller, price, stock status, and discount information. Used in grids and lists.

**Properties:**

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `product` | `Product` | Yes | Product data model instance |

**Product Model:**

See `lib/models/product.dart` for full details.

Key fields used:
- `id`: Unique identifier
- `name`: Product name
- `sellerName`: Seller display name
- `price`: Current price
- `originalPrice`: Pre-discount price (if any)
- `hasDiscount`: Discount flag
- `stock`: Available quantity
- `imageUrl`: Primary product image URL
- `status`: Product status ("active" by default)

**Key Implementation Details:**

- **Layout:** 2-part vertical split (3:2 ratio)
- **Image Section:** 60% height, full-width
- **Details Section:** 40% height, padded
- **Card Shadow:** `AppTheme.cardShadow` (2-layer elevation)
- **Border:** 1dp `AppTheme.border`
- **Image Error:** "🛍️" emoji fallback
- **Stock Indicator:** Colored badge (green/pink for in stock, red for out)
- **Discount:** Strikethrough original price when applicable
- **Aspect:** Flexible (determined by parent)

**Usage Example:**

```dart
ProductCard(
  product: product,
)
```

**Visual Description:**
A white card with rounded corners (12dp) and a subtle drop shadow. The top 60% is a product image (or fallback emoji). The bottom 40% contains product info: name (14sp bold), seller name (12sp, light gray), price in pink ($99.99), and a "32" stock badge in pink. If discounted, shows strikethrough original price above the current price. The "Add to Cart" area is not part of this card (handled by parent).

**Design System Integration:**

- **Card Background:** `AppTheme.white`
- **Border:** `AppTheme.border`
- **Shadow:** `AppTheme.cardShadow`
- **Primary Color:** `AppTheme.primaryLight` (pink) for price
- **Text Dark:** `AppTheme.textDark` for titles
- **Text Light:** `AppTheme.textLight` for secondary info
- **Success Color:** `AppTheme.primaryLight` with 10% alpha for stock
- **Error Color:** Red with 10% alpha for out of stock
- **Border Radius:** `AppTheme.radiusLg` (12dp)
- **Padding:** `AppTheme.md` (16dp)
- **Font:** Inter body (14sp) and small (12sp)

**Interactions:**

- Tap anywhere on card: Navigates to product detail page (`/product`)
- Visual: Material ripple effect

**Best Practices:**

- Use in `GridView` or `ListView` for product listings
- Always handle null/empty image URLs gracefully
- Keep aspect ratio consistent when used in grids
- ProductCard does NOT include add-to-cart controls (use in parent widget)
- Stock badge shows numeric count only if > 0
- Use "Out" badge (not "0") when stock is 0

**Accessibility:**

- Semantic label combining name, price, and stock status
- High contrast text (dark on white)
- Large tap targets (entire card is tappable)
- Image fallback emoji visible if images fail to load
- Error builders handle all image failure modes

**Testing Guidelines:**

```dart
testWidgets('ProductCard displays product info', (tester) async {
  final product = Product(
    id: '1',
    name: 'Test Product',
    price: 29.99,
    // ... other fields
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProductCard(product: product),
      ),
    ),
  );
  expect(find.text('Test Product'), findsOneWidget);
  expect(find.text('\$29.99'), findsOneWidget);
});
```

**Version History:**

- **v1.0:** Initial card with image, name, seller, price, stock badge

---

### ProductGrid

**Type:** `StatelessWidget`

**File:** `lib/widgets/product_grid.dart`

**Purpose:**
Titled section displaying a grid of `ProductCard` items with optional "View All" navigation.

**Properties:**

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `title` | `String` | Yes | Section title (e.g., "New Arrivals", "Best Sellers") |
| `products` | `List<Product>` | Yes | List of products to display |
| `viewAllRoute` | `String?` | No | Optional route to navigate for "View All" button |
| `isLoading` | `bool` | No (default: `false`) | Shows loading indicator if true |

**Key Implementation Details:**

- **Layout:** White full-width section with top/bottom padding
- **Header:** Title (32sp Playfair Display) + optional "View All" text button
- **Grid:** 2-column grid (`crossAxisCount: 2`)
- **Spacing:** `AppTheme.md` between items, `AppTheme.lg` vertical between header and grid
- **Aspect Ratio:** 0.72 (portrait card shape)
- **Loading State:** Centered circular progress indicator (pink)
- **Empty State:** Inventory icon (64dp) + "No products found" message
- **View All:** Navigate to provided route when tapped

**Usage Example:**

```dart
ProductGrid(
  title: 'New Arrivals',
  products: newProducts,
  viewAllRoute: '/shop',
)
```

**Visual Description:**
A white section with a prominent Playfair Display title (32sp, dark text). Below is a "View All" text button (pink, semibold) aligned to the right, if provided. The grid below shows 2 products per row. Each product card has rounded corners and shadow. While loading, shows a pink spinner centered. If empty, shows a large inventory icon with muted text. The section uses generous padding.

**Design System Integration:**

- **Background:** `AppTheme.white`
- **Title:** Playfair Display 32sp, `AppTheme.textDark`
- **View All Button:** `AppTheme.primaryLight` text, semibold
- **Grid Spacing:** `AppTheme.md` (horizontal), `AppTheme.lg` (vertical)
- **Padding:** `AppTheme.xl` (24dp) all around
- **Aspect Ratio:** 0.72 (standard portrait card)
- **Loading Color:** `AppTheme.primaryLight`

**Interactions:**

- Tap "View All": Navigates to `viewAllRoute`
- Tap any product card: Navigates to product detail (handled by ProductCard)
- Both use ripple effects

**Best Practices:**

- Limit to 4-8 products visible before "View All"
- Use `isLoading` while fetching from API
- Set `viewAllRoute` for any list with more items
- Empty state guides user (inventory icon is friendly)
- Parent should handle pull-to-refresh if needed
- Consider skeleton loaders instead of spinner (future enhancement)

**Accessibility:**

- "View All" button has clear purpose
- Empty state message descriptive
- Each product card is independently focusable
- Header is hierarchical (title larger than button)
- Loading spinner announces loading state to screen readers

**Testing Guidelines:**

```dart
testWidgets('ProductGrid displays products', (tester) async {
  final products = [
    Product(id: '1', name: 'P1', price: 10, stock: 5, ...),
    Product(id: '2', name: 'P2', price: 20, stock: 3, ...),
  ];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProductGrid(
          title: 'Test',
          products: products,
        ),
      ),
    ),
  );
  expect(find.text('Test'), findsOneWidget);
  expect(find.text('P1'), findsOneWidget);
  expect(find.text('P2'), findsOneWidget);
  expect(find.byType(ProductCard), findsNWidgets(2));
});
```

**Version History:**

- **v1.0:** Grid with loading, empty, and view all states

---

## Widget Relationships

The widgets form a hierarchical structure:

```
GrandeNavbar (top)
    ↓
HeroCarousel (home screen)
    ↓
CategoryGrid (home screen)
    ↓
ProductGrid (home/shop screens)
    ↓
ProductCard (inside ProductGrid)
    ↓
ProductDetailScreen (product detail page)
    ↓
Cart/Checkout (purchase flow)
    ↓
GrandeBottomNav (bottom, persistent on main screens)
```

## Customization Guide

All widgets use `AppTheme` for styling. To customize:

1. **Colors:** Modify `AppTheme` in `lib/theme/app_theme.dart`
2. **Typography:** Update font families/sizes in `AppTheme.theme`
3. **Spacing:** Adjust spacing constants (`AppTheme.xs`, `sm`, `md`, etc.)
4. **Borders:** Change `radiusSm`, `radiusMd`, `radiusLg`
5. **Shadows:** Modify `cardShadow`, `subtleShadow`, `pinkGlow`

Widgets DO NOT use hardcoded colors, fonts, or spacing values – everything references `AppTheme`.

## Performance Considerations

- **HeroCarousel:** Uses `PageView` with 3 local slides (no images loaded = fast)
- **CategoryGrid:** `shrinkWrap: true` with `NeverScrollableScrollPhysics` (nested scroll)
- **ProductGrid:** `shrinkWrap: true` for same reason
- **ProductCard:** Network images with error/loading builders (prevents crashes)
- **GrandeBottomNav:** Stateless (cheap to rebuild)
- **GrandeNavbar:** Stateless (cheap to rebuild)

## Accessibility Notes

All widgets follow Material Design accessibility guidelines:

- Minimum 48dp touch targets
- High contrast colors (verified)
- Semantic labels on interactive elements
- Focusable and keyboard navigable
- Screen reader compatible

## Testing Philosophy

Each widget is designed to be:

- **Testable:** Pure functions where possible
- **Composable:** Can be nested without issues
- **Independent:** No hidden dependencies
- **Documented:** Clear properties and behavior

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-05-06 | Initial widget catalog with 6 core widgets |
| 1.1 | 2026-05-06 | Added visual descriptions and code samples |