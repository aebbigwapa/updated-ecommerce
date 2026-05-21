# 🚚 SHIPPING FEE IMPLEMENTATION GUIDE

## ✅ Configuration: Base ₱40 + ₱10 per km

---

## STEP 1: Run SQL Migration (5 minutes)

### In Supabase SQL Editor:

Run the file: `migrations/add_shipping_fee.sql`

This will:
- ✅ Add shipping fee settings to admin_settings
- ✅ Add shipping_fee column to orders table
- ✅ Add distance_km column to orders table
- ✅ Set default shipping fee for existing orders

---

## STEP 2: How It Works

### Formula:
```
Shipping Fee = Base Fee + (Distance × Per KM Rate)
Shipping Fee = ₱40 + (distance_km × ₱10)
```

### Examples:
```
5 km  = ₱40 + (5 × ₱10)  = ₱90
10 km = ₱40 + (10 × ₱10) = ₱140
15 km = ₱40 + (15 × ₱10) = ₱190
20 km = ₱40 + (20 × ₱10) = ₱240
25 km = ₱40 + (25 × ₱10) = ₱290
30 km = ₱40 + (30 × ₱10) = ₱340
```

---

## STEP 3: Using the Calculator

### In Python (Backend):

```python
from services.shipping_calculator import ShippingFeeCalculator

# Calculate shipping fee
distance = 10  # kilometers
fee = ShippingFeeCalculator.calculate(distance)
print(f"Shipping fee for {distance}km: ₱{fee}")
# Output: Shipping fee for 10km: ₱140

# Get detailed breakdown
breakdown = ShippingFeeCalculator.get_breakdown(distance)
print(breakdown)
# Output: {
#   'distance_km': 10,
#   'base_fee': 40,
#   'distance_fee': 100,
#   'total': 140
# }
```

### In Flutter (Mobile):

```dart
double calculateShippingFee(double distanceKm) {
  const double baseFee = 40;
  const double perKmRate = 10;
  const double minFee = 50;
  
  if (distanceKm <= 0) return minFee;
  
  double total = baseFee + (distanceKm * perKmRate);
  total = total < minFee ? minFee : total;
  
  // Round to nearest 10
  return (total / 10).round() * 10;
}

// Usage:
double fee = calculateShippingFee(10); // Returns 140
```

---

## STEP 4: Integration Points

### A. Checkout Page

When user enters delivery address:
1. Calculate distance from seller to buyer
2. Calculate shipping fee using formula
3. Add to order total
4. Display breakdown to user

```python
# In checkout route
from services.shipping_calculator import ShippingFeeCalculator

# Get distance (from Google Maps API or calculate from coordinates)
distance_km = calculate_distance(seller_address, buyer_address)

# Calculate shipping fee
shipping_fee = ShippingFeeCalculator.calculate(distance_km)

# Add to order
order_total = cart_total + shipping_fee
```

### B. Order Creation

Save shipping fee and distance to database:

```python
order_data = {
    'buyer_id': buyer_id,
    'total_amount': cart_total,
    'shipping_fee': shipping_fee,
    'distance_km': distance_km,
    'shipping_address': address,
    # ... other fields
}
```

### C. Admin Settings

Allow admin to update rates:

```python
# Get current settings
settings = supabase.table('admin_settings').select('*').execute()

# Update settings
supabase.table('admin_settings').update({
    'value': '50'  # New base fee
}).eq('key', 'shipping_base_fee').execute()
```

---

## STEP 5: Distance Calculation

### Option 1: Google Maps Distance Matrix API (Recommended)

```python
import requests

def calculate_distance(origin, destination):
    """
    Calculate distance using Google Maps API
    
    Args:
        origin: "lat,lng" or address string
        destination: "lat,lng" or address string
    
    Returns:
        float: Distance in kilometers
    """
    api_key = os.getenv('GOOGLE_MAPS_API_KEY')
    url = 'https://maps.googleapis.com/maps/api/distancematrix/json'
    
    params = {
        'origins': origin,
        'destinations': destination,
        'key': api_key
    }
    
    response = requests.get(url, params=params)
    data = response.json()
    
    if data['status'] == 'OK':
        distance_meters = data['rows'][0]['elements'][0]['distance']['value']
        distance_km = distance_meters / 1000
        return round(distance_km, 2)
    
    return 0
```

### Option 2: Haversine Formula (Free, Less Accurate)

```python
import math

def calculate_distance_haversine(lat1, lon1, lat2, lon2):
    """
    Calculate distance between two coordinates using Haversine formula
    
    Returns:
        float: Distance in kilometers
    """
    R = 6371  # Earth's radius in kilometers
    
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    delta_lat = math.radians(lat2 - lat1)
    delta_lon = math.radians(lon2 - lon1)
    
    a = math.sin(delta_lat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon/2)**2
    c = 2 * math.asin(math.sqrt(a))
    
    distance = R * c
    return round(distance, 2)
```

---

## STEP 6: Display to Users

### Checkout Page:

```html
<div class="order-summary">
    <div class="line-item">
        <span>Subtotal</span>
        <span>₱{{ cart_total }}</span>
    </div>
    <div class="line-item">
        <span>Shipping ({{ distance_km }}km)</span>
        <span>₱{{ shipping_fee }}</span>
    </div>
    <div class="line-item total">
        <span>Total</span>
        <span>₱{{ order_total }}</span>
    </div>
</div>

<div class="shipping-breakdown">
    <small>
        Shipping: ₱40 base + ₱10/km × {{ distance_km }}km = ₱{{ shipping_fee }}
    </small>
</div>
```

---

## STEP 7: Admin Configuration Panel

Allow admin to change rates without code changes:

```html
<!-- Admin Settings Page -->
<form id="shipping-settings">
    <div class="form-group">
        <label>Base Fee (₱)</label>
        <input type="number" name="base_fee" value="40">
    </div>
    <div class="form-group">
        <label>Per KM Rate (₱)</label>
        <input type="number" name="per_km_rate" value="10">
    </div>
    <div class="form-group">
        <label>Minimum Fee (₱)</label>
        <input type="number" name="min_fee" value="50">
    </div>
    <button type="submit">Save Settings</button>
</form>
```

---

## 📊 PRICING TABLE (For Display)

| Distance | Base Fee | Distance Fee | Total |
|----------|----------|--------------|-------|
| 1 km | ₱40 | ₱10 | ₱50 |
| 5 km | ₱40 | ₱50 | ₱90 |
| 10 km | ₱40 | ₱100 | ₱140 |
| 15 km | ₱40 | ₱150 | ₱190 |
| 20 km | ₱40 | ₱200 | ₱240 |
| 25 km | ₱40 | ₱250 | ₱290 |
| 30 km | ₱40 | ₱300 | ₱340 |

---

## 🎯 TESTING

### Test the calculator:

```bash
cd services
python shipping_calculator.py
```

Expected output:
```
Shipping Fee Calculator
==================================================
Base Fee: ₱40
Per KM Rate: ₱10
==================================================

0 km:
  Base Fee: ₱40
  Distance Fee: ₱0.00
  Total: ₱50

5 km:
  Base Fee: ₱40
  Distance Fee: ₱50.00
  Total: ₱90

10 km:
  Base Fee: ₱40
  Distance Fee: ₱100.00
  Total: ₱140
...
```

---

## ✅ CHECKLIST

- [ ] Run SQL migration in Supabase
- [ ] Test shipping calculator
- [ ] Integrate distance calculation
- [ ] Update checkout page
- [ ] Update order creation
- [ ] Display shipping breakdown
- [ ] Test with real addresses
- [ ] Add admin configuration panel
- [ ] Update mobile app
- [ ] Test end-to-end

---

## 💡 FUTURE ENHANCEMENTS

### 1. Dynamic Pricing by Time
```python
# Peak hours (rush hour): +20%
# Late night: +30%
# Weekends: +10%
```

### 2. Promo Codes
```python
# Free shipping over ₱500
# 50% off shipping on first order
```

### 3. Multiple Delivery Options
```python
# Standard: Base + ₱10/km
# Express: Base + ₱15/km (faster)
# Economy: Base + ₱8/km (slower)
```

---

## 🆘 TROUBLESHOOTING

### Issue: Distance is 0
- Check if addresses have coordinates
- Verify Google Maps API key
- Use Haversine formula as fallback

### Issue: Shipping fee too high
- Check distance calculation
- Verify per_km_rate setting
- Consider max distance limit

### Issue: Riders complaining
- Review rates with actual riders
- Consider gas prices
- Adjust base fee or per_km_rate

---

## 📞 SUPPORT

For questions or issues:
1. Check calculator output
2. Verify database settings
3. Test with known distances
4. Review admin_settings table

---

**Ready to implement! Start with Step 1!** 🚀
