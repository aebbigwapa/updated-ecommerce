# Registration Location Auto-Fill via Pin Drop

## Implementation Summary

### Status: ✅ ENHANCED EXISTING FEATURE

The reverse geocoding auto-fill functionality was **already implemented** in the system. This enhancement adds:
- Debouncing and rate limiting
- Loading indicators
- User feedback (success/error messages)
- Field highlighting on auto-fill
- Improved error handling

---

## System Architecture

### Map Library
**Leaflet 1.9.4** - Open-source JavaScript library for interactive maps

### Geocoding Service
**Nominatim (OpenStreetMap)** - Free reverse geocoding API
- Base URL: `https://nominatim.openstreetmap.org`
- Rate limit: 1 request per second
- User-Agent header: `Grande-ECommerce-Registration/1.0`

### Location Data Source
**PSGC API** - Philippine Standard Geographic Code
- Base URL: `https://psgc.gitlab.io/api`

---

## Address Component Mapping

| Nominatim Field | Form Field | Example |
|----------------|------------|---------|
| `house_number` + `road` | Street / House No. | "123 Rizal St" |
| `postcode` | ZIP Code | "1127" |
| `state` / `region` | Region | "National Capital Region" |
| `province` / `county` | Province | "Metro Manila" |
| `city` / `town` | City/Municipality | "Quezon City" |
| `suburb` / `neighbourhood` | Barangay | "Barangay Commonwealth" |

---

## Enhancements Made

### 1. Debouncing (500ms)
Prevents excessive API calls during rapid pin movement.

### 2. Rate Limiting (1 req/sec)
Respects Nominatim usage policy.

### 3. Loading States
- Disables street and ZIP fields during geocoding
- Shows "🔄 Fetching address..." instruction

### 4. User Feedback
- Success toast: "✅ Address auto-filled from map location!"
- Error toast: "⚠️ Could not determine address. Please fill manually."
- Field highlighting (green background for 1.5s)

### 5. Error Handling
- Graceful degradation on API failure
- Fields re-enabled after error
- Existing values preserved

---

## Configuration

### Rate Limits (psgc.js)
```javascript
const REVERSE_GEOCODE_DEBOUNCE = 500;  // ms
const NOMINATIM_RATE_LIMIT = 1000;     // ms
```

### User-Agent Header
```javascript
headers: {
    'User-Agent': 'Grande-ECommerce-Registration/1.0'
}
```

---

## Testing Locations

### Metro Manila (NCR)
- Quezon City, Commonwealth
- Expected: Region=NCR, City=Quezon City, Barangay=Commonwealth

### Cebu
- Cebu City, Lahug
- Expected: Region=Region VII, Province=Cebu, City=Cebu City

### Davao
- Davao City, Poblacion
- Expected: Region=Region XI, Province=Davao del Sur, City=Davao City

---

## Troubleshooting

### Address not auto-filling
1. Check browser console for errors
2. Verify Nominatim API status
3. Try urban location (better coverage)

### Dropdowns not matching
1. Check console logs for matching attempts
2. User can manually select correct option

---

## Files Modified

- `static/js/psgc.js` - Enhanced reverse geocoding
- `static/css/psgc.css` - Added disabled state styling

---

## License & Attribution

- **Leaflet**: BSD 2-Clause License
- **OpenStreetMap/Nominatim**: ODbL License, © OpenStreetMap contributors
- **PSGC API**: Public Domain, Philippine Statistics Authority
