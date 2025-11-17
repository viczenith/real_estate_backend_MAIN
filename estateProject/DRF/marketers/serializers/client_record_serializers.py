from rest_framework import serializers
from django.utils import timezone
from estateApp.models import ClientUser, Transaction, PlotAllocation, Estate, PlotSize, PlotNumber
from decimal import Decimal


class PlotSizeSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlotSize
        fields = ('id', 'size')


class PlotNumberSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlotNumber
        fields = ('id', 'number')


class EstateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Estate
        fields = ('id', 'name', 'location')


class AllocationSerializer(serializers.ModelSerializer):
    estate = EstateSerializer(read_only=True)
    plot_size = serializers.SerializerMethodField()
    plot_number = PlotNumberSerializer(read_only=True)

    class Meta:
        model = PlotAllocation
        fields = ('id', 'estate', 'plot_size', 'plot_number', 'payment_type')

    def get_plot_size(self, obj):
        if getattr(obj, "plot_size", None):
            return {'id': obj.plot_size.id, 'size': obj.plot_size.size}
        return None


class TransactionListSerializer(serializers.ModelSerializer):
    allocation = AllocationSerializer(read_only=True)
    status = serializers.SerializerMethodField()
    transaction_date = serializers.DateField(format="%b %d, %Y", read_only=True)
    total_amount = serializers.DecimalField(max_digits=12, decimal_places=2)

    class Meta:
        model = Transaction
        fields = ('id', 'reference_code', 'total_amount', 'status', 'payment_method',
                  'transaction_date', 'allocation')

    def get_status(self, obj):
        try:
            # prefer model property if defined
            return obj.status
        except Exception:
            return 'Unknown'


class ClientSummarySerializer(serializers.ModelSerializer):
    total_transactions = serializers.SerializerMethodField()
    assigned_marketer = serializers.SerializerMethodField()
    phone_number = serializers.SerializerMethodField()
    profile_image = serializers.SerializerMethodField()
    date_registered = serializers.DateTimeField(format="%B %d, %Y")

    class Meta:
        model = ClientUser
        fields = ('id', 'full_name', 'email', 'phone_number', 'profile_image', 'address',
                  'date_registered', 'total_transactions', 'assigned_marketer')

    def get_total_transactions(self, obj):
        # prefer annotated value if present
        tx_count = getattr(obj, 'tx_count', None)
        if tx_count is not None:
            try:
                return int(tx_count)
            except Exception:
                pass
        return obj.transactions.count()

    def get_assigned_marketer(self, obj):
        m = getattr(obj, 'assigned_marketer', None)
        if m:
            return {'id': m.id, 'full_name': m.full_name}
        return None

    def get_phone_number(self, obj):
        # template expects phone_number
        return getattr(obj, 'phone', '')

    def get_profile_image(self, obj):
        img = getattr(obj, 'profile_image', None)
        if img:
            request = self.context.get('request')
            try:
                url = img.url
                return request.build_absolute_uri(url) if request else url
            except Exception:
                return None
        return None


class ClientDetailSerializer(serializers.ModelSerializer):
    total_transactions = serializers.SerializerMethodField()
    transactions_by_estate = serializers.SerializerMethodField()
    phone_number = serializers.SerializerMethodField()
    profile_image = serializers.SerializerMethodField()
    date_registered = serializers.DateTimeField(format="%B %d, %Y")

    class Meta:
        model = ClientUser
        fields = ('id', 'full_name', 'email', 'phone_number', 'profile_image', 'address',
                  'date_registered', 'total_transactions', 'transactions_by_estate')

    def get_total_transactions(self, obj):
        return obj.transactions.count()

    def get_phone_number(self, obj):
        return getattr(obj, 'phone', '')

    def get_profile_image(self, obj):
        img = getattr(obj, 'profile_image', None)
        if img:
            request = self.context.get('request')
            try:
                url = img.url
                return request.build_absolute_uri(url) if request else url
            except Exception:
                return None
        return None

    def get_transactions_by_estate(self, obj):
        # Expect 'transactions_qs' in context for efficiency (set in view)
        transactions_qs = self.context.get('transactions_qs')
        if transactions_qs is None:
            transactions_qs = Transaction.objects.filter(client=obj).select_related(
                'allocation__estate', 'allocation__plot_size', 'allocation__plot_number'
            ).order_by('-transaction_date')

        grouped = {}
        for txn in transactions_qs:
            allocation = getattr(txn, 'allocation', None)
            estate = getattr(allocation, 'estate', None) if allocation else None
            estate_key = estate.id if estate else 0

            if estate_key not in grouped:
                grouped[estate_key] = {
                    'estate': {'id': estate.id, 'name': estate.name} if estate else {'id': 0, 'name': 'Unknown'},
                    'transactions': []
                }

            grouped[estate_key]['transactions'].append({
                'id': txn.id,
                'reference_code': txn.reference_code,
                'total_amount': str(txn.total_amount.quantize(Decimal('0.01'))),
                'status': getattr(txn, 'status', 'Unknown'),
                'payment_type': allocation.payment_type if allocation else None,
                'plot_size': allocation.plot_size.size if allocation and allocation.plot_size else None,
                'plot_number': allocation.plot_number.number if allocation and allocation.plot_number else None,
                'transaction_date': txn.transaction_date.strftime('%b %d, %Y'),
            })

        # return list preserving insertion order (convert from dict)
        return list(grouped.values())
