#!/usr/bin/env python
"""
Diagnostic script to verify promotional offers and estate data.
Run this to check if database has the required data structure.

Usage:
    python check_promo_data.py
"""

import os
import sys
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'estateProject.settings')
django.setup()

from django.utils import timezone
from estateApp.models import Estate, PromotionalOffer, PropertyPrice, PlotSizeUnits

def check_promotional_offers():
    """Check promotional offers in database"""
    print("\n" + "="*60)
    print("CHECKING PROMOTIONAL OFFERS")
    print("="*60)
    
    promos = PromotionalOffer.objects.all()
    print(f"\n📊 Total Promotional Offers: {promos.count()}")
    
    today = timezone.localdate()
    active_promos = PromotionalOffer.objects.filter(
        start__lte=today, 
        end__gte=today
    )
    print(f"✅ Active Promos (valid today): {active_promos.count()}")
    
    if promos.exists():
        print("\n📋 Promotional Offers List:")
        for promo in promos[:10]:  # Show first 10
            is_active = promo.start <= today <= promo.end
            status = "✅ ACTIVE" if is_active else "⏰ INACTIVE"
            print(f"\n  {status}")
            print(f"  ID: {promo.id}")
            print(f"  Name: {promo.name}")
            print(f"  Discount: {promo.discount}%")
            print(f"  Valid: {promo.start} to {promo.end}")
            print(f"  Estates: {promo.estates.count()}")
            if promo.estates.exists():
                estate_names = [e.name for e in promo.estates.all()[:3]]
                print(f"    - {', '.join(estate_names)}")
    else:
        print("\n⚠️  NO PROMOTIONAL OFFERS FOUND IN DATABASE")
        print("   Create some promotional offers in Django Admin first!")
    
    return promos.count()

def check_estates_with_promos():
    """Check which estates have promotional offers"""
    print("\n" + "="*60)
    print("CHECKING ESTATES WITH PROMOTIONS")
    print("="*60)
    
    estates = Estate.objects.all()
    print(f"\n📊 Total Estates: {estates.count()}")
    
    estates_with_promos = 0
    estates_with_active_promos = 0
    today = timezone.localdate()
    
    if estates.exists():
        print("\n📋 Estates List:")
        for estate in estates[:10]:  # Show first 10
            promos = estate.promotional_offers.all()
            active_promos = promos.filter(start__lte=today, end__gte=today)
            
            if promos.exists():
                estates_with_promos += 1
            if active_promos.exists():
                estates_with_active_promos += 1
            
            print(f"\n  Estate ID: {estate.id}")
            print(f"  Name: {estate.name}")
            print(f"  Location: {estate.location}")
            print(f"  Total Promos: {promos.count()}")
            print(f"  Active Promos: {active_promos.count()}")
            
            if active_promos.exists():
                for promo in active_promos:
                    print(f"    ✅ {promo.name} (-{promo.discount}%)")
            elif promos.exists():
                for promo in promos:
                    print(f"    ⏰ {promo.name} (-{promo.discount}%)")
    else:
        print("\n⚠️  NO ESTATES FOUND IN DATABASE")
    
    print(f"\n📈 Summary:")
    print(f"  Estates with any promos: {estates_with_promos}")
    print(f"  Estates with active promos: {estates_with_active_promos}")
    
    return estates_with_promos

def check_property_prices():
    """Check property prices for modal plot sizes"""
    print("\n" + "="*60)
    print("CHECKING PROPERTY PRICES (FOR MODAL)")
    print("="*60)
    
    estates = Estate.objects.all()[:5]  # Check first 5 estates
    
    for estate in estates:
        print(f"\n🏢 Estate: {estate.name}")
        prices = estate.property_prices.select_related('plot_unit__plot_size').all()
        print(f"   PropertyPrice entries: {prices.count()}")
        
        if prices.exists():
            for i, pp in enumerate(prices[:3], 1):  # Show first 3
                plot_unit = getattr(pp, 'plot_unit', None)
                if plot_unit:
                    plot_size = getattr(plot_unit, 'plot_size', None)
                    size_name = getattr(plot_size, 'size', 'Unknown') if plot_size else 'Unknown'
                    print(f"   {i}. Size: {size_name}")
                    print(f"      Plot Unit ID: {plot_unit.id}")
                    print(f"      Current Price: ₦{pp.current:,.2f}" if pp.current else "      Current Price: None")
                else:
                    print(f"   {i}. ⚠️ PropertyPrice has no plot_unit!")
        else:
            print(f"   ⚠️ NO PROPERTY PRICES FOUND")
            print(f"   This estate will show 'No plot sizes available' in modal")

def check_api_response_structure():
    """Simulate what the API would return"""
    print("\n" + "="*60)
    print("SIMULATING API RESPONSE")
    print("="*60)
    
    estates = Estate.objects.all()[:2]  # Check first 2
    today = timezone.localdate()
    
    for estate in estates:
        print(f"\n🏢 Estate: {estate.name}")
        print(f"   API would return:")
        
        # Simulate estate list response
        promos = estate.promotional_offers.all()
        promo_data = []
        for p in promos:
            is_active = p.start <= today <= p.end
            promo_data.append({
                'id': p.id,
                'name': p.name,
                'discount': float(p.discount) if p.discount else None,
                'discount_pct': int(p.discount) if p.discount else None,
                'is_active': is_active,
                'active': is_active,
                'start': str(p.start),
                'end': str(p.end)
            })
        
        print(f"   promotional_offers: {promo_data}")
        
        # Simulate modal response
        prices = estate.property_prices.select_related('plot_unit__plot_size').all()[:3]
        sizes_data = []
        for pp in prices:
            plot_unit = getattr(pp, 'plot_unit', None)
            if plot_unit:
                plot_size = getattr(plot_unit, 'plot_size', None)
                size_name = getattr(plot_size, 'size', None) if plot_size else None
                amount = float(pp.current) if pp.current else None
                
                # Check for active promo
                active_promo = promos.filter(start__lte=today, end__gte=today).first()
                discounted = None
                discount_pct = None
                if active_promo and amount:
                    discount_pct = int(active_promo.discount)
                    discounted = amount * (100 - active_promo.discount) / 100
                
                sizes_data.append({
                    'plot_unit_id': plot_unit.id,
                    'size': size_name,
                    'amount': amount,
                    'current': amount,
                    'discounted': discounted,
                    'promo_price': discounted,
                    'discount_pct': discount_pct,
                    'discount': discount_pct
                })
        
        print(f"   sizes: {sizes_data}")

def main():
    """Run all checks"""
    print("\n" + "="*60)
    print("PROMOTIONAL OFFERS & ESTATE DATA DIAGNOSTIC")
    print("="*60)
    
    promo_count = check_promotional_offers()
    estates_with_promos = check_estates_with_promos()
    check_property_prices()
    check_api_response_structure()
    
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    
    if promo_count == 0:
        print("\n❌ ISSUE: No promotional offers in database")
        print("   SOLUTION: Create promotional offers in Django Admin")
        print("   URL: http://localhost:8000/admin/estateApp/promotionaloffer/")
    elif estates_with_promos == 0:
        print("\n❌ ISSUE: Promotional offers exist but not linked to any estates")
        print("   SOLUTION: Edit promos in Django Admin and add estates")
    else:
        print("\n✅ Database structure looks good!")
        print("   If badges still don't show, check:")
        print("   1. Django server restarted?")
        print("   2. Flutter app restarted (capital R)?")
        print("   3. Check Django logs for emoji icons (🏢 🏷️ 📦)")
        print("   4. Check Flutter console logs for 'Extracting promotional offers'")
    
    print("\n" + "="*60)

if __name__ == "__main__":
    main()
