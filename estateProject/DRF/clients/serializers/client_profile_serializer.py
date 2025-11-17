from rest_framework import serializers
from django.conf import settings
from decimal import Decimal
from django.db.models import Sum
from estateApp.models import *

class ProfileSerializer(serializers.ModelSerializer):
    profile_image = serializers.SerializerMethodField()
    date_registered = serializers.DateTimeField(read_only=True)
    assigned_marketer = serializers.SerializerMethodField()
    properties_count = serializers.SerializerMethodField()
    total_value = serializers.SerializerMethodField()
    current_value = serializers.SerializerMethodField()
    appreciation_total = serializers.SerializerMethodField()
    average_growth = serializers.SerializerMethodField()
    highest_growth_property = serializers.SerializerMethodField()
    highest_growth_rate = serializers.SerializerMethodField()
    rank_tag = serializers.SerializerMethodField()

    class Meta:
        model = ClientUser
        fields = [
            'id','email','full_name','phone','address','date_of_birth','date_registered',
            'about','company','job','country','profile_image',
            'assigned_marketer',
            'properties_count','total_value','current_value',
            'appreciation_total','average_growth','highest_growth_property','highest_growth_rate',
            'rank_tag',
        ]
        read_only_fields = ['id', 'date_registered', 'email']

    def get_profile_image(self, obj):
        request = self.context.get('request', None)
        if obj.profile_image and hasattr(obj.profile_image, 'url'):
            url = obj.profile_image.url
            if request:
                return request.build_absolute_uri(url)
            return url
        return None

    def get_assigned_marketer(self, obj):
        m = getattr(obj, 'assigned_marketer', None)

        if m is None:
            try:
                client = ClientUser.objects.select_related('assigned_marketer').filter(pk=getattr(obj, 'pk', None)).first()
                if client:
                    m = getattr(client, 'assigned_marketer', None)
            except Exception:
                m = None

        if not m:
             return None

        request = self.context.get('request', None)
        profile_image = None
        try:
            if getattr(m, 'profile_image', None) and hasattr(m.profile_image, 'url'):
                url = m.profile_image.url
                profile_image = request.build_absolute_uri(url) if request else url
        except Exception:
            profile_image = None

        return {
            'id': getattr(m, 'id', None),
            'full_name': getattr(m, 'full_name', None) or getattr(m, 'name', None) or '',
            'phone': getattr(m, 'phone', None),
            'email': getattr(m, 'email', None),
            'profile_image': profile_image,
        }


    def _get_price_cache(self, obj):
        """Build a price cache to avoid N+1 queries. Call this once and reuse."""
        if not hasattr(self, '_price_cache'):
            # Get all unique (estate, plot_unit) pairs for this client
            allocations = PlotAllocation.objects.filter(client=obj).select_related('estate', 'plot_size_unit')
            
            price_keys = set()
            for a in allocations:
                if a.estate and a.plot_size_unit:
                    price_keys.add((a.estate.id, a.plot_size_unit.id))
            
            # Bulk fetch all relevant PropertyPrice objects
            self._price_cache = {}
            for estate_id, plot_unit_id in price_keys:
                pp = PropertyPrice.objects.filter(
                    estate_id=estate_id, 
                    plot_unit_id=plot_unit_id
                ).order_by('-created_at').first()
                if pp:
                    self._price_cache[(estate_id, plot_unit_id)] = Decimal(pp.current)
        
        return self._price_cache

    def get_properties_count(self, obj):
        return Transaction.objects.filter(client=obj).count()

    def get_total_value(self, obj):
        s = Transaction.objects.filter(client=obj).aggregate(total=Sum('total_amount'))['total'] or Decimal(0)
        return float(s)

    def get_current_value(self, obj):
        price_cache = self._get_price_cache(obj)
        total = Decimal(0)
        
        allocations = PlotAllocation.objects.filter(client=obj).select_related('estate', 'plot_size_unit')
        for a in allocations:
            if a.estate and a.plot_size_unit:
                price = price_cache.get((a.estate.id, a.plot_size_unit.id))
                if price:
                    total += price
        return float(total)

    def get_appreciation_total(self, obj):
        price_cache = self._get_price_cache(obj)
        total_app = Decimal(0)
        
        txs = Transaction.objects.filter(client=obj).select_related('allocation__estate', 'allocation__plot_size_unit')
        for t in txs:
            if t.allocation and t.allocation.estate and t.allocation.plot_size_unit:
                current_price = price_cache.get((t.allocation.estate.id, t.allocation.plot_size_unit.id))
                if current_price:
                    total_app += (current_price - Decimal(t.total_amount))
        return float(total_app)

    def get_average_growth(self, obj):
        price_cache = self._get_price_cache(obj)
        rates = []
        
        txs = Transaction.objects.filter(client=obj).select_related('allocation__estate', 'allocation__plot_size_unit')
        for t in txs:
            if t.allocation and t.allocation.estate and t.allocation.plot_size_unit and t.total_amount:
                current_price = price_cache.get((t.allocation.estate.id, t.allocation.plot_size_unit.id))
                if current_price:
                    r = (current_price - Decimal(t.total_amount)) / Decimal(t.total_amount) * Decimal(100)
                    rates.append(float(r))
        
        if not rates:
            return 0.0
        return sum(rates) / len(rates)

    def get_highest_growth_property(self, obj):
        price_cache = self._get_price_cache(obj)
        best = None
        best_rate = None
        
        txs = Transaction.objects.filter(client=obj).select_related('allocation__estate', 'allocation__plot_size_unit')
        for t in txs:
            if t.allocation and t.allocation.estate and t.allocation.plot_size_unit and t.total_amount:
                current_price = price_cache.get((t.allocation.estate.id, t.allocation.plot_size_unit.id))
                if current_price:
                    r = (current_price - Decimal(t.total_amount)) / Decimal(t.total_amount) * Decimal(100)
                    if best is None or r > best_rate:
                        best = t
                        best_rate = r
        
        if not best:
            return None
        return best.allocation.estate.name

    def get_highest_growth_rate(self, obj):
        price_cache = self._get_price_cache(obj)
        best_rate = None
        
        txs = Transaction.objects.filter(client=obj).select_related('allocation__estate', 'allocation__plot_size_unit')
        for t in txs:
            if t.allocation and t.allocation.estate and t.allocation.plot_size_unit and t.total_amount:
                current_price = price_cache.get((t.allocation.estate.id, t.allocation.plot_size_unit.id))
                if current_price:
                    r = (current_price - Decimal(t.total_amount)) / Decimal(t.total_amount) * Decimal(100)
                    if best_rate is None or r > best_rate:
                        best_rate = r
        
        return float(best_rate) if best_rate is not None else 0.0

    def get_rank_tag(self, obj):
        """
        Return the client's rank based on investment level and property count.
        Ranks:
        - Royal Elite: total_value ≥ ₦150,000,000 AND plot_count ≥ 5
        - Estate Ambassador: total_value ≥ ₦100,000,000 OR plot_count ≥ 4
        - Prime Investor: total_value ≥ ₦50,000,000 OR plot_count ≥ 3
        - Smart Owner: total_value ≥ ₦20,000,000 OR plot_count ≥ 2
        - First-Time Investor: else
        """
        try:
            return obj.rank_tag
        except Exception:
            return 'First-Time Investor'

class PlotAllocationSerializer(serializers.ModelSerializer):
    estate = serializers.SerializerMethodField()
    plot_number = serializers.SerializerMethodField()
    plot_size = serializers.SerializerMethodField()
    date_allocated = serializers.DateTimeField(format="%Y-%m-%dT%H:%M:%SZ", read_only=True)
    current_value = serializers.SerializerMethodField()
    payment_type = serializers.CharField(read_only=True)

    class Meta:
        model = PlotAllocation
        fields = [
            'id',
            'estate',
            'plot_size',
            'plot_number',
            'payment_type',
            'date_allocated',
            'current_value',
        ]

    def get_estate(self, obj):
        e = obj.estate
        return {
            "id": e.id,
            "name": e.name,
            "location": e.location,
            "title_deed": e.title_deed,
            "date_added": e.date_added.isoformat() if getattr(e, 'date_added', None) else None
        }

    def get_plot_number(self, obj):
        return obj.plot_number.number if obj.plot_number else None

    def get_plot_size(self, obj):
        try:
            return obj.plot_size_unit.plot_size.size
        except Exception:
            return obj.plot_size.size if obj.plot_size else None

    def get_current_value(self, obj):
        try:
            pp = PropertyPrice.objects.filter(estate=obj.estate, plot_unit=obj.plot_size_unit).order_by('-created_at').first()
            if pp:
                return float(pp.current)
        except Exception:
            pass
        return None

class AppreciationPointSerializer(serializers.Serializer):
    date = serializers.DateField()
    value = serializers.FloatField()

class TransactionSerializer(serializers.ModelSerializer):
    allocation = serializers.SerializerMethodField(read_only=True)
    estate_name = serializers.SerializerMethodField()
    plot_size = serializers.SerializerMethodField()
    plot_number = serializers.SerializerMethodField()
    purchase_price = serializers.SerializerMethodField()
    purchase_date = serializers.SerializerMethodField()
    paid_percent = serializers.SerializerMethodField()
    receipt_number = serializers.SerializerMethodField()

    id = serializers.IntegerField(read_only=True)
    transaction_date = serializers.DateField(format="%Y-%m-%d")
    total_amount = serializers.SerializerMethodField()
    current_value = serializers.SerializerMethodField()
    status = serializers.SerializerMethodField()
    appreciation = serializers.SerializerMethodField()
    abs_appreciation = serializers.SerializerMethodField()
    growth_rate = serializers.SerializerMethodField()
    abs_growth_rate = serializers.SerializerMethodField()
    payment_method = serializers.CharField()

    class Meta:
        model = Transaction
        fields = [
            "id",
            "estate_name",
            "plot_size",
            "plot_number",
            "purchase_price",
            "purchase_date",
            "paid_percent",
            "receipt_number",
            "allocation",
            "transaction_date",
            "total_amount",
            "current_value",
            "status",
            "appreciation",
            "abs_appreciation",
            "growth_rate",
            "abs_growth_rate",
            "payment_method",
            "reference_code",
        ]


    def get_allocation(self, obj):
        """
        Return a safe, JSON-serializable dict for allocation.
        Avoid returning model instances or __dict__ objects.
        """
        try:
            a = obj.allocation
        except Exception:
            return None

        estate_data = None
        try:
            estate = a.estate
            estate_data = {
                "id": estate.id,
                "name": estate.name,
                "location": getattr(estate, "location", None),
            }
        except Exception:
            estate_data = None


        plot_size_value = None
        try:
            if getattr(a, "plot_size_unit", None) and getattr(a.plot_size_unit, "plot_size", None):
                plot_size_value = getattr(a.plot_size_unit.plot_size, "size", None)
            elif getattr(a, "plot_size", None):
                plot_size_value = getattr(a.plot_size, "size", None)
        except Exception:
            plot_size_value = None

        plot_number_value = None
        try:
            plot_number_value = a.plot_number.number if getattr(a, "plot_number", None) else None
        except Exception:
            plot_number_value = None

        return {
            "estate": estate_data,
            "plot_size": plot_size_value,
            "plot_number": plot_number_value,
            "payment_type": getattr(a, "payment_type", None),
        }

    def get_estate_name(self, obj):
        try:
            return obj.allocation.estate.name
        except Exception:
            return None

    def get_plot_size(self, obj):
        try:
            return obj.allocation.plot_size_unit.plot_size.size
        except Exception:
            return getattr(getattr(obj.allocation, 'plot_size', None), 'size', None)

    def get_plot_number(self, obj):
        try:
            return obj.allocation.plot_number.number if obj.allocation.plot_number else "Reserved"
        except Exception:
            return "Reserved"

    def get_purchase_price(self, obj):
        return float(obj.total_amount) if obj.total_amount is not None else 0.0

    def get_purchase_date(self, obj):
        return obj.transaction_date.isoformat() if getattr(obj, 'transaction_date', None) else None

    def get_paid_percent(self, obj):
        try:
            total = Decimal(obj.total_amount or 0)
            if total == 0:
                return 0.0
            paid = Decimal(obj.total_paid or 0)
            pct = (paid / total) * Decimal(100)
            pct_val = float(max(0.0, min(pct, Decimal(100))))
            return round(pct_val, 2)
        except Exception:
            return 0.0

    def get_receipt_number(self, obj):
        prs = obj.payment_records.order_by('-payment_date')
        if prs.exists():
            rn = prs.first().receipt_number
            return rn if rn else None
        return None

    def get_total_amount(self, obj):
        return float(obj.total_amount) if obj.total_amount is not None else None

    def _get_latest_price(self, obj):
        try:
            pp = PropertyPrice.objects.filter(estate=obj.allocation.estate, plot_unit=obj.allocation.plot_size_unit).order_by('-created_at').first()
            if pp:
                return Decimal(pp.current)
        except Exception:
            pass
        return None

    def get_current_value(self, obj):
        v = self._get_latest_price(obj)
        return float(v) if v is not None else None

    def get_appreciation(self, obj):
        cur = self._get_latest_price(obj)
        if cur is None or obj.total_amount is None:
            return None
        return float(cur - Decimal(obj.total_amount))

    def get_abs_appreciation(self, obj):
        a = self.get_appreciation(obj)
        return abs(a) if a is not None else None

    def get_growth_rate(self, obj):
        cur = self._get_latest_price(obj)
        if cur is None or obj.total_amount in (None, 0):
            return None
        rate = (cur - Decimal(obj.total_amount)) / Decimal(obj.total_amount) * Decimal(100)
        return float(rate)

    def get_abs_growth_rate(self, obj):
        gr = self.get_growth_rate(obj)
        if gr is None:
            return None
        val = abs(gr)
        return float(min(val, 100.0))

    def get_status(self, obj):
        try:
            return obj.status
        except Exception:
            return None

class TransactionAllocationSerializer(serializers.ModelSerializer):
    estate = serializers.SerializerMethodField()
    plot_size = serializers.SerializerMethodField()
    plot_number = serializers.SerializerMethodField()
    payment_type = serializers.CharField(source='allocation.payment_type', read_only=True)

    class Meta:
        model = Transaction
        fields = [
            'estate',
            'plot_size',
            'plot_number',
            'payment_type',
        ]

    def get_estate(self, obj):
        a = obj.allocation
        e = a.estate
        return {"id": e.id, "name": e.name, "location": e.location}

    def get_plot_size(self, obj):
        try:
            return obj.allocation.plot_size_unit.plot_size.size
        except Exception:
            return getattr(obj.allocation.plot_size, 'size', None)

    def get_plot_number(self, obj):
        return obj.allocation.plot_number.number if obj.allocation.plot_number else None

class PaymentRecordSerializer(serializers.ModelSerializer):
    date = serializers.DateField(source='payment_date', format="%d %b %Y", read_only=True)
    amount = serializers.SerializerMethodField()
    method = serializers.SerializerMethodField()
    reference = serializers.CharField(source='reference_code', read_only=True)
    receipt_url = serializers.SerializerMethodField()
    installment = serializers.IntegerField(allow_null=True)

    class Meta:
        model = PaymentRecord
        fields = [
            "id",
            "date",
            "amount",
            "method",
            "installment",
            "reference",
            "receipt_url",
            "receipt_generated",
            "receipt_date",
            "receipt_number",
        ]

    def get_amount(self, obj):
        amt = getattr(obj, "amount_paid", None) or Decimal('0.00')
        return str(Decimal(amt).quantize(Decimal('0.01')))

    def get_method(self, obj):
        try:
            return obj.get_payment_method_display()
        except Exception:
            return getattr(obj, 'payment_method', '') or ''
    
    def get_receipt_url(self, obj):
        req = self.context.get('request')
        if not obj.reference_code or not req:
            return None
        direct = req.build_absolute_uri(reverse('client-receipt-download')) + f"?reference={obj.reference_code}"
        request_endpoint = req.build_absolute_uri(reverse('client-receipt-request'))
        return {
            'direct': direct,
        '    request': request_endpoint
    }

class PaymentGroupSerializer(serializers.Serializer):
    date = serializers.CharField()
    amount = serializers.CharField()
    method = serializers.CharField()
    installment = serializers.CharField()
    reference = serializers.CharField()
    receipt_url = serializers.CharField(allow_null=True)


