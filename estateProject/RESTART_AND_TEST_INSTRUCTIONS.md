# CRITICAL: Server Restart and Testing Instructions

## ⚠️ IMPORTANT: You MUST restart Django server for URL changes to take effect!

The URL routing changes in `DRF/urls.py` will NOT work until the Django development server is restarted.

## Step 1: Restart Django Server

### Stop the current server:
Press `Ctrl + C` in the terminal running Django

### Start fresh:
```bash
cd c:\Users\HP\Documents\VictorGodwin\RE\MAIN\RealEstateMSApp\estateProject
python manage.py runserver
```

## Step 2: Verify Server Logs

After restarting, when you make requests, you should see these logs:

### For Estate List (badges):
```
🏢 Estate 1 (Estate Name): 2 promotional offers
🏷️ First promo for Estate Name: {'id': 1, 'name': 'Spring Sale', 'discount': 15.0, 'discount_pct': 15, 'is_active': True, 'active': True, ...}
📦 Full estate data being sent: {'id': 1, 'name': 'Estate Name', 'promotional_offers': [...]}
```

### For Modal (plot sizes):
```
🏢 MODAL DATA for Estate 1 (Estate Name):
   📏 Sizes count: 3
   📐 First size: {'size': '600 SQM', 'amount': 5000000.0, 'current': 5000000.0, 'discounted': 4250000.0, ...}
   🏷️ Promo: {'active': True, 'is_active': True, 'discount_pct': 15, ...}
   📦 Full promotional_offers: [...]
```

## Step 3: Test in Flutter App

### A. Test Promo Badges on Estate Cards

1. Open Flutter app and navigate to Estates List
2. **Check Flutter console logs** for:
```
=== Extracting promotional offers for estate: [Estate Name] ===
Estate [Name]: Found 2 promotional offers
✅ ACTIVE: Spring Sale (15%)
⏰ INACTIVE: Summer Deal (10%)
Summary: 1 active, 1 inactive promos
_promotionalOffers state updated with 2 items
```

3. **Visual check on estate cards:**
   - ✅ Green badge: "1 active" (has active promos)
   - ✅ Grey badge: "2 promos" (has only inactive promos)
   - ✅ No badge: (no promos at all)

**If badges still don't show:**
- Check if `_promotionalOffers` list is empty in logs
- Verify estate data has `promotional_offers` key
- Do hot restart in Flutter (press `r` in terminal)

### B. Test Plot Sizes in Modal

1. Click "View Details" on any estate card
2. **Check Flutter console logs** for:
```
Loading estate details for ID: 1
Estate details response: {estate_name: Estate Name, sizes: [...], promo: {...}}
Estate details parsed: estate_name=Estate Name, sizes count=3, promo={...}
```

3. **Visual check in modal:**
   - ✅ Estate name displays at top
   - ✅ Active promo badge shows (green with discount %)
   - ✅ Plot sizes list appears with:
     - Size name (e.g., "600 SQM")
     - Price (struck through if promo active)
     - Discounted price (green if promo active)
     - Promo percentage badge

**If plot sizes don't show:**
- Check if sizes array is empty in logs
- Verify estate has PropertyPrice entries in database
- Check "NO SIZES DATA!" warning in Django logs

## Step 4: Test API Endpoints Directly

### Test Estate List Endpoint:
```bash
curl -H "Authorization: Token YOUR_TOKEN" http://10.215.112.72:8000/api/estates/
```

**Expected response (should include promotional_offers):**
```json
{
  "count": 10,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 1,
      "name": "Estate Name",
      "location": "Location",
      "created_at": "2024-01-15",
      "promos_count": 2,
      "promotional_offers": [
        {
          "id": 1,
          "name": "Spring Sale",
          "discount": 15.0,
          "discount_pct": 15,
          "is_active": true,
          "active": true,
          "start": "2024-01-01",
          "end": "2024-12-31"
        }
      ]
    }
  ]
}
```

### Test Estate Modal Endpoint:
```bash
curl -H "Authorization: Token YOUR_TOKEN" "http://10.215.112.72:8000/api/estates/?estate_id=1"
```

**Expected response (should include sizes with amount/current):**
```json
{
  "id": 1,
  "name": "Estate Name",
  "estate_id": 1,
  "estate_name": "Estate Name",
  "location": "Location",
  "promo": {
    "active": true,
    "is_active": true,
    "id": 1,
    "name": "Spring Sale",
    "discount": 15.0,
    "discount_pct": 15,
    "start": "2024-01-01",
    "end": "2024-12-31"
  },
  "promotional_offers": [...],
  "sizes": [
    {
      "plot_unit_id": 1,
      "size": "600 SQM",
      "amount": 5000000.0,
      "current": 5000000.0,
      "discounted": 4250000.0,
      "promo_price": 4250000.0,
      "discount_pct": 15,
      "discount": 15
    }
  ]
}
```

## Step 5: Common Issues and Solutions

### Issue: Badges still not showing after server restart

**Check 1: Verify URL is using correct view**
```python
# In Django console, verify this import is active:
from DRF.clients.api_views.client_dashboard_views import EstateListAPIView
```

**Check 2: Test endpoint directly**
```bash
# Should return promotional_offers in response
curl -H "Authorization: Token YOUR_TOKEN" http://10.215.112.72:8000/api/estates/ | python -m json.tool
```

**Check 3: Verify estates have promos in database**
- Go to Django Admin: http://10.215.112.72:8000/admin/
- Check PromotionalOffer table
- Verify at least one promo is linked to an estate
- Verify start/end dates cover today's date

### Issue: Plot sizes showing "No plot sizes available"

**Check 1: Verify PropertyPrice entries exist**
```python
# In Django shell:
python manage.py shell
from estateApp.models import Estate, PropertyPrice
estate = Estate.objects.first()
print(estate.property_prices.count())  # Should be > 0
```

**Check 2: Verify plot_unit relationships**
```python
# Each PropertyPrice should have a plot_unit:
pp = PropertyPrice.objects.first()
print(pp.plot_unit)  # Should not be None
print(pp.plot_unit.plot_size)  # Should not be None
print(pp.current)  # Should have a value
```

**Check 3: Check Django logs for "NO SIZES DATA!" warning**
- If you see this, the issue is in database relationships
- Ensure PropertyPrice entries have valid plot_unit_id
- Ensure PlotUnit entries have valid plot_size_id

### Issue: Promo badge colors are wrong

**Check**: Badge logic uses `is_active` or `active` field:
- `is_active: true` → Green badge "X active"
- `is_active: false` → Grey badge "X promos"
- Verify dates: `start <= today <= end` should be true

### Issue: Modal shows prices but no discount

**Check**: Promo must be active AND amount must exist:
```json
{
  "amount": 5000000.0,  // Must be present and not null
  "discounted": 4250000.0,  // Will be null if no active promo
  "discount_pct": 15  // Will be null if no active promo
}
```

## Step 6: Force Refresh Everything

If issues persist after server restart:

```bash
# 1. Stop Django server
Ctrl + C

# 2. Clear Python cache
find . -type d -name __pycache__ -exec rm -rf {} +

# 3. Restart Django
python manage.py runserver

# 4. In Flutter app, do hot restart (not hot reload)
Press R in Flutter terminal (capital R for full restart)

# 5. Or rebuild Flutter app completely
flutter clean
flutter pub get
flutter run
```

## Step 7: Verify Changes Applied

Run this checklist:

- [ ] Django server restarted
- [ ] Can see emoji logs (🏢 🏷️ 📦) in Django console
- [ ] `/api/estates/` returns `promotional_offers` array
- [ ] `/api/estates/?estate_id=1` returns `sizes` array with `amount` and `current`
- [ ] Flutter console shows "Extracting promotional offers" logs
- [ ] Flutter console shows "Estate details response" logs
- [ ] Badges visible on estate cards
- [ ] Plot sizes visible in modal
- [ ] Promo pricing shows correctly (strikethrough + green price)

## Need More Help?

### Check exact API endpoint Flutter is calling:
Look for this in Flutter logs:
```
Estates -> loading page=1 q=""
Estates -> response type: _InternalLinkedHashMap<String, dynamic>
Loading estate details for ID: 1
```

### Check Django is receiving the requests:
Django logs should show:
```
"GET /api/estates/ HTTP/1.1" 200
"GET /api/estates/?estate_id=1 HTTP/1.1" 200
```

### Verify authentication:
If getting 401 errors, token authentication might be failing:
```dart
// Check token is valid in Flutter:
debugPrint('Using token: ${widget.token}');
```
