# Testing the Promo Display Fix

## Quick Test Commands

### 1. Test Estate List Endpoint (should now include promotional_offers)
```bash
# Replace YOUR_TOKEN with actual auth token
curl -H "Authorization: Token YOUR_TOKEN" http://localhost:8000/api/estates/
```

Expected response should include:
```json
{
  "results": [
    {
      "id": 1,
      "name": "Estate Name",
      "location": "Location",
      "promotional_offers": [  // ✅ This should now be present!
        {
          "id": 1,
          "name": "Promo Name",
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

### 2. Test Estate Modal Endpoint (should include proper sizes with amount/current fields)
```bash
# Replace YOUR_TOKEN and ESTATE_ID
curl -H "Authorization: Token YOUR_TOKEN" "http://localhost:8000/api/estates/?estate_id=ESTATE_ID"
```

Expected response should include:
```json
{
  "estate_name": "Estate Name",
  "promo": {
    "active": true,
    "is_active": true,  // ✅ Both fields present
    "discount_pct": 15
  },
  "sizes": [
    {
      "size": "600 SQM",
      "amount": 5000000.0,      // ✅ Present
      "current": 5000000.0,      // ✅ Present
      "discounted": 4250000.0,   // ✅ Present
      "promo_price": 4250000.0,  // ✅ Present
      "discount_pct": 15,
      "discount": 15
    }
  ]
}
```

## Flutter App Testing

### Test Promo Badges on Estate Cards
1. Open Flutter app
2. Navigate to Estates List page
3. **Look for badges on estate cards:**
   - Green badge with "X active" = Has active promotions
   - Grey badge with "X promos" = Has only inactive promotions
   - No badge = No promotions

### Test Plot Sizes in Modal
1. Click "View Details" button on any estate card
2. Modal should open showing:
   - Estate name at top
   - Active promo badge (if applicable) in green with discount percentage
   - List of plot sizes with:
     - Plot size name (e.g., "600 SQM")
     - Original price (struck through if promo active)
     - Discounted price (in green if promo active)
     - Promo percentage badge

## Django Admin Verification

### Create Test Data (if needed)
1. Go to Django Admin: http://localhost:8000/admin/
2. Create a Promotional Offer:
   - Name: "Test Spring Sale"
   - Discount: 15
   - Start: Today's date
   - End: Future date (e.g., 30 days from now)
   - Estates: Select 1-2 estates
3. Save and test in Flutter app

## Common Issues & Solutions

### Issue: Badges still not showing
- **Check:** Django server restarted after URL changes?
- **Check:** Token authentication working?
- **Check:** Run `python manage.py migrate` if needed

### Issue: Modal shows "No plot sizes available"
- **Check:** Estate has PropertyPrice entries in database
- **Check:** PropertyPrice entries have plot_unit relationships
- **Check:** plot_unit has plot_size relationship

### Issue: Prices showing "NO AMOUNT SET"
- **Check:** PropertyPrice.current field has a value
- **Verify:** In Django admin, check property_prices for the estate

## Debug Logging

The Flutter app logs promo data extraction. Check Flutter console for:
```
=== Extracting promotional offers for estate: [Estate Name] ===
Estate [Name]: Found X promotional offers
✅ ACTIVE: [Promo Name] (15%)
⏰ INACTIVE: [Promo Name] (10%)
```

The DRF view also logs. Check Django console for:
```
Estate X (Estate Name): Y promotional offers
First promo for Estate Name: {'id': 1, 'name': 'Spring Sale', ...}
```
