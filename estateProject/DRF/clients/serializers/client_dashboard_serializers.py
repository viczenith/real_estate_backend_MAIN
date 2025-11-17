from rest_framework import serializers
from decimal import Decimal, InvalidOperation
from django.utils import timezone

from estateApp.models import (
    PromotionalOffer, Estate, PropertyPrice, PriceHistory
)

class EstateSizeDetailSerializer(serializers.Serializer):
    plot_unit_id = serializers.IntegerField(allow_null=True)
    size = serializers.CharField(allow_blank=True, allow_null=True)
    amount = serializers.FloatField(allow_null=True)
    discounted = serializers.FloatField(allow_null=True)
    discount_pct = serializers.IntegerField(allow_null=True)

class EstateDetailSerializer(serializers.ModelSerializer):
    id = serializers.IntegerField(source='pk', read_only=True)
    estate_id = serializers.SerializerMethodField()
    estate_name = serializers.SerializerMethodField()
    promo = serializers.SerializerMethodField()
    promotional_offers = serializers.SerializerMethodField()
    sizes = serializers.SerializerMethodField()

    class Meta:
        model = Estate
        fields = ['id','name','estate_id','estate_name','location','promo','promotional_offers','sizes']

    def get_estate_id(self, obj):
        return obj.id

    def get_estate_name(self, obj):
        return obj.name

    def _promo_dict(self, promo):
        if not promo:
            return {
                "active": False,
                "is_active": False,
                "name": None,
                "discount_pct": None
            }
        is_active_now = (promo.start <= timezone.localdate() <= promo.end)
        return {
            "active": is_active_now,
            "is_active": is_active_now,  # Include both for compatibility
            "id": promo.id,
            "name": promo.name,
            "discount": promo.discount,
            "discount_pct": int(promo.discount) if promo.discount is not None else None,
            "start": promo.start,
            "end": promo.end
        }
    

    def get_promo(self, estate):
        today = timezone.localdate()
        promo = PromotionalOffer.objects.filter(estates=estate, start__lte=today, end__gte=today).order_by('-discount', '-start').first()
        return self._promo_dict(promo)

    def get_promotional_offers(self, estate):
        # re-use your simple serializer for a consistent representation
        # Order by: highest discount first, then newest start date
        qs = estate.promotional_offers.all().order_by('-discount', '-start')
        return PromotionalOfferSimpleSerializer(qs, many=True, context=self.context).data

    def _calc_discounted(self, amount, pct):
        try:
            if amount is None or pct is None:
                return None
            discounted = (Decimal(amount) * (Decimal(100) - Decimal(pct))) / Decimal(100)
            return float(discounted.quantize(Decimal('0.01')))
        except (InvalidOperation, Exception):
            return None

    def get_sizes(self, estate):
        # Prefetch expected relation before calling serializer to minimize DB hits
        # (caller should have prefetched property_prices__plot_unit__plot_size)
        out = []
        promo = None
        today = timezone.localdate()
        maybe_promo = PromotionalOffer.objects.filter(
            estates=estate, 
            start__lte=today, 
            end__gte=today
        ).order_by('-discount', '-start').first()
        if maybe_promo:
            promo = maybe_promo

        # Get the latest price for each unique plot unit to avoid duplicates
        # This matches the Django template logic in promotions_list.html
        seen_plot_units = set()
        
        # Order by created_at descending to get latest prices first
        prices = estate.property_prices.select_related('plot_unit__plot_size').all().order_by('-created_at')
        
        for pp in prices:
            plot_unit = getattr(pp, 'plot_unit', None)
            if not plot_unit:
                continue
                
            # Skip if we've already processed this plot unit
            plot_unit_id = plot_unit.id
            if plot_unit_id in seen_plot_units:
                continue
            seen_plot_units.add(plot_unit_id)
            
            # Get plot size name
            plot_size = getattr(plot_unit, 'plot_size', None)
            size_name = getattr(plot_size, 'size', None) if plot_size else None
            if not size_name:
                size_name = f"Plot Unit {plot_unit_id}"
            
            # Get current amount - ensure we return the value consistently
            amount = None
            current_value = None
            if pp.current is not None:
                try:
                    amount = float(pp.current)
                    current_value = amount  # Flutter expects both 'amount' and 'current'
                except (ValueError, TypeError):
                    amount = None
                    current_value = None
            
            # Calculate discounted price if promo exists
            discounted = None
            discount_pct = None
            promo_price = None
            if promo and amount is not None:
                try:
                    discount_pct = int(promo.discount) if promo.discount is not None else None
                    if discount_pct is not None:
                        discounted = self._calc_discounted(pp.current, promo.discount)
                        promo_price = discounted  # Flutter expects both 'discounted' and 'promo_price'
                except Exception as e:
                    discounted = None
                    discount_pct = None
                    promo_price = None

            out.append({
                "plot_unit_id": plot_unit_id,
                "size": size_name,
                "amount": amount,
                "current": current_value,  # Include for compatibility with Django templates
                "discounted": discounted,
                "promo_price": promo_price,  # Include for compatibility
                "discount_pct": discount_pct,
                "discount": discount_pct  # Include both fields for compatibility
            })
        return out


class PromotionalOfferSimpleSerializer(serializers.ModelSerializer):
    discount_pct = serializers.SerializerMethodField()
    is_active = serializers.SerializerMethodField()
    active = serializers.SerializerMethodField()  # Alias for 'is_active' for compatibility
    start = serializers.DateField(format="%Y-%m-%d")
    end = serializers.DateField(format="%Y-%m-%d")

    class Meta:
        model = PromotionalOffer
        fields = ['id', 'name', 'discount', 'discount_pct', 'start', 'end', 'is_active', 'active']

    def get_discount_pct(self, obj):
        return int(obj.discount) if getattr(obj, 'discount', None) is not None else None

    def get_is_active(self, obj):
        try:
            today = timezone.localdate()
            return obj.start <= today <= obj.end
        except Exception:
            return False
    
    def get_active(self, obj):
        # Alias for is_active for compatibility with Flutter app
        return self.get_is_active(obj)

class PromoEstateSizeSerializer(serializers.Serializer):
    plot_unit_id = serializers.IntegerField()
    size = serializers.CharField()
    current = serializers.FloatField(allow_null=True)
    promo_price = serializers.FloatField(allow_null=True)

class PromotionDashboardSerializer(serializers.ModelSerializer):
    estates = serializers.SerializerMethodField()
    is_active = serializers.SerializerMethodField()
    discount_pct = serializers.SerializerMethodField()

    class Meta:
        model = PromotionalOffer
        fields = ['id', 'name', 'discount', 'discount_pct', 'start', 'end', 'description', 'estates', 'is_active']

    def get_estates(self, promo):
        estates = []
        # prefetch expected relations
        for e in promo.estates.all().prefetch_related('property_prices__plot_unit__plot_size'):
            sizes = []
            
            # Get the latest price for each unique plot unit to avoid duplicates
            seen_plot_units = set()
            
            for pp in e.property_prices.select_related('plot_unit__plot_size').all().order_by('-created_at'):
                plot_unit = getattr(pp, 'plot_unit', None)
                if not plot_unit:
                    continue
                    
                # Skip if we've already processed this plot unit
                plot_unit_id = plot_unit.id
                if plot_unit_id in seen_plot_units:
                    continue
                seen_plot_units.add(plot_unit_id)
                
                # Get plot size name
                plot_size = getattr(plot_unit, 'plot_size', None)
                size_name = getattr(plot_size, 'size', '') if plot_size else ''
                
                sizes.append({
                    "plot_unit_id": plot_unit_id,
                    "size": size_name,
                    "current": float(pp.current) if pp.current is not None else None
                })
            
            # also include a small list of promotional offers for each estate to mirror the template
            estates.append({
                "id": e.id,
                "name": e.name,
                "sizes": sizes,
                "location": getattr(e, 'location', None)
            })
        return estates

    def get_is_active(self, promo):
        try:
            today = timezone.localdate()
            return promo.start <= today <= promo.end
        except Exception:
            return False

    def get_discount_pct(self, obj):
        return int(obj.discount) if getattr(obj, 'discount', None) is not None else None

class PromotionListItemSerializer(serializers.ModelSerializer):
    is_active = serializers.SerializerMethodField()
    estates_preview = serializers.SerializerMethodField()
    discount_pct = serializers.SerializerMethodField()

    class Meta:
        model = PromotionalOffer
        fields = ['id', 'name', 'discount', 'discount_pct', 'description', 'start', 'end', 'is_active', 'estates_preview']

    def get_is_active(self, obj):
        today = timezone.localdate()
        return obj.start <= today <= obj.end

    def get_estates_preview(self, obj):
        return [e.name for e in obj.estates.all()[:2]]

    def get_discount_pct(self, obj):
        return int(obj.discount) if getattr(obj, 'discount', None) is not None else None

class PromotionDetailSerializer(serializers.ModelSerializer):
    estates = serializers.SerializerMethodField()
    is_active = serializers.SerializerMethodField()
    discount_pct = serializers.SerializerMethodField()

    class Meta:
        model = PromotionalOffer
        fields = ['id', 'name', 'discount', 'discount_pct', 'start', 'end', 'description', 'created_at', 'is_active', 'estates']

    def get_is_active(self, obj):
        today = timezone.localdate()
        return obj.start <= today <= obj.end

    def get_discount_pct(self, obj):
        return int(obj.discount) if getattr(obj, 'discount', None) is not None else None

    def _promo_price_for(self, value, pct):
        if value is None or pct is None:
            return None
        try:
            discounted = (Decimal(value) * (Decimal(100) - Decimal(pct))) / Decimal(100)
            return float(discounted.quantize(Decimal('0.01')))
        except Exception:
            return None

    def get_estates(self, promo):
        estates_out = []
        for estate in promo.estates.prefetch_related('property_prices__plot_unit__plot_size').all():
            sizes = []
            
            # Get the latest price for each unique plot unit to avoid duplicates
            seen_plot_units = set()
            
            for pp in estate.property_prices.select_related('plot_unit__plot_size').all().order_by('-created_at'):
                plot_unit = getattr(pp, 'plot_unit', None)
                if not plot_unit:
                    continue
                    
                # Skip if we've already processed this plot unit
                plot_unit_id = plot_unit.id
                if plot_unit_id in seen_plot_units:
                    continue
                seen_plot_units.add(plot_unit_id)
                
                # Get plot size name
                plot_size = getattr(plot_unit, 'plot_size', None)
                size_name = getattr(plot_size, 'size', '') if plot_size else ''
                
                # Get current amount and calculate promo price
                current = float(pp.current) if pp.current is not None else None
                promo_price = self._promo_price_for(pp.current, promo.discount) if promo.discount else None
                
                sizes.append({
                    "plot_unit_id": plot_unit_id,
                    "size": size_name,
                    "current": current,
                    "promo_price": promo_price,
                })
            
            estates_out.append({
                "id": estate.id,
                "name": estate.name,
                "location": estate.location,
                "sizes": sizes
            })
        return estates_out

class PriceHistoryListSerializer(serializers.ModelSerializer):
    estate_name = serializers.SerializerMethodField()
    plot_unit = serializers.SerializerMethodField()

    price = serializers.SerializerMethodField()

    previous = serializers.SerializerMethodField()
    current = serializers.SerializerMethodField()
    percent_change = serializers.SerializerMethodField()
    effective = serializers.DateField(format="%Y-%m-%d")
    recorded_at = serializers.DateTimeField(format="%Y-%m-%dT%H:%M:%SZ")
    notes = serializers.CharField(allow_blank=True, allow_null=True)
    promo = serializers.SerializerMethodField()
    promo_price = serializers.SerializerMethodField()

    class Meta:
        model = PriceHistory
        fields = [
            'id', 'price', 'estate_name', 'plot_unit', 'previous', 'current', 'percent_change',
            'effective', 'recorded_at', 'notes', 'promo', 'promo_price'
        ]

    def get_estate_name(self, obj):
        return getattr(obj.price.estate, 'name', None)

    def get_plot_unit(self, obj):
        try:
            pu = obj.price.plot_unit
            return {"id": pu.id, "size": getattr(pu.plot_size, 'size', None)}
        except Exception:
            return None

    def get_price(self, obj):
        """
        Return a nested price object matching templates' expectations:
        update.price.estate.name
        update.price.plot_unit.plot_size.size
        """
        try:
            price_obj = getattr(obj, 'price', None)
            if not price_obj:
                return None

            estate = getattr(price_obj, 'estate', None)
            plot_unit = getattr(price_obj, 'plot_unit', None)
            plot_size = getattr(plot_unit, 'plot_size', None) if plot_unit is not None else None

            return {
                "estate": {
                    "id": getattr(estate, 'id', None),
                    "name": getattr(estate, 'name', None)
                } if estate is not None else None,
                "plot_unit": {
                    "id": getattr(plot_unit, 'id', None),
                    "plot_size": {
                        "id": getattr(plot_size, 'id', None),
                        "size": getattr(plot_size, 'size', None)
                    } if plot_size is not None else None
                } if plot_unit is not None else None
            }
        except Exception:
            return None

    def get_previous(self, obj):
        return float(obj.previous) if obj.previous is not None else None

    def get_current(self, obj):
        return float(obj.current) if obj.current is not None else None

    def get_percent_change(self, obj):
        try:
            prev = Decimal(obj.previous or 0)
            cur = Decimal(obj.current or 0)
            if prev == 0:
                return None
            pct = (cur - prev) / prev * Decimal(100)
            return float(pct.quantize(Decimal('0.01')))
        except Exception:
            return None

    def _active_promo_for_estate(self, estate):
        today = timezone.localdate()
        return PromotionalOffer.objects.filter(estates=estate, start__lte=today, end__gte=today).order_by('-discount').first()

    def get_promo(self, obj):
        try:
            estate = obj.price.estate
            today = timezone.localdate()
            promo = PromotionalOffer.objects.filter(estates=estate, start__lte=today, end__gte=today).order_by('-discount').first()
            if promo:
                return {
                    "id": promo.id,
                    "name": promo.name,
                    "discount": promo.discount,
                    "discount_pct": int(promo.discount) if promo.discount is not None else None,
                    "start": promo.start,
                    "end": promo.end,
                    "active": (promo.start <= today <= promo.end)
                }
        except Exception:
            pass
        return None

    def get_promo_price(self, obj):
        try:
            promo = self.get_promo(obj)
            if not promo:
                return None
            cur = obj.current
            if cur is None:
                return None
            discounted = (Decimal(cur) * (Decimal(100) - Decimal(promo['discount']))) / Decimal(100)
            return float(discounted.quantize(Decimal('0.01')))
        except Exception:
            return None

class EstateSizePriceSerializer(serializers.Serializer):
    plot_unit_id = serializers.IntegerField()
    size = serializers.CharField()
    amount = serializers.FloatField(allow_null=True)
    discounted = serializers.FloatField(allow_null=True)
    discount_pct = serializers.IntegerField(allow_null=True)


