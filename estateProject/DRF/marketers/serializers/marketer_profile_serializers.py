from rest_framework import serializers
from decimal import Decimal
from datetime import date
from django.urls import reverse
from django.db.models import Sum, Q
from estateApp.models import *

class SmallMarketerSerializer(serializers.ModelSerializer):
    profile_image = serializers.SerializerMethodField()

    class Meta:
        model = MarketerUser
        fields = ["id", "full_name", "email", "phone", "profile_image"]

    def get_profile_image(self, obj):
        req = self.context.get("request")
        if getattr(obj, "profile_image", None) and hasattr(obj.profile_image, "url"):
            url = obj.profile_image.url
            return req.build_absolute_uri(url) if req else url
        return None


class MarketerPerformanceSerializer(serializers.Serializer):
    closed_deals = serializers.IntegerField()
    total_sales = serializers.DecimalField(max_digits=14, decimal_places=2)
    commission_earned = serializers.DecimalField(max_digits=14, decimal_places=2)
    commission_rate = serializers.DecimalField(max_digits=5, decimal_places=2)
    yearly_target = serializers.DecimalField(max_digits=14, decimal_places=2, allow_null=True)
    yearly_target_achievement = serializers.FloatField(allow_null=True)


class MarketerProfileSerializer(serializers.ModelSerializer):
    profile_image = serializers.SerializerMethodField()
    date_registered = serializers.DateTimeField(read_only=True)
    performance = serializers.SerializerMethodField()
    top3 = serializers.SerializerMethodField()
    user_entry = serializers.SerializerMethodField()
    current_year = serializers.SerializerMethodField()

    class Meta:
        model = MarketerUser
        fields = [
            "id", "email", "full_name", "phone", "job", "company", "country", "about",
            "profile_image", "date_registered",
            "performance", "top3", "user_entry", "current_year", "address",
        ]
        read_only_fields = ["id", "email", "date_registered"]

    def get_profile_image(self, obj):
        req = self.context.get("request")
        if getattr(obj, "profile_image", None) and hasattr(obj.profile_image, "url"):
            url = obj.profile_image.url
            return req.build_absolute_uri(url) if req else url
        return None

    def get_current_year(self, obj):
        return date.today().year

    def _latest_commission_rate(self, marketer):
        """
        return Decimal commission rate (%) for marketer or global default or Decimal(0)
        """
        qs = MarketerCommission.objects.filter(Q(marketer=marketer) | Q(marketer__isnull=True)).order_by('-effective_date')
        if qs.exists():
            return qs.first().rate
        return Decimal('0.00')

    def _get_yearly_target_for(self, marketer, year):
        qs = MarketerTarget.objects.filter(
            Q(marketer=marketer) | Q(marketer__isnull=True),
            period_type='annual',
            specific_period=str(year)
        ).order_by('-created_at')
        if qs.exists():
            return qs.first().target_amount
        return None

    def _sales_for_marketer_year(self, marketer, year):
        qs = Transaction.objects.filter(
            marketer=marketer,
            transaction_date__year=year
        ).aggregate(sum=Sum('total_amount'))
        return Decimal(qs['sum'] or 0)


    def get_performance(self, obj):
        year = date.today().year
        perf = MarketerPerformanceRecord.objects.filter(marketer=obj, specific_period=str(year)).first()
        if perf:
            closed_deals = perf.closed_deals
            total_sales = perf.total_sales or Decimal('0.00')
            commission_earned = perf.commission_earned or Decimal('0.00')
        else:
            txs = Transaction.objects.filter(marketer=obj, transaction_date__year=year)
            closed_deals = txs.count()
            total_sales = Decimal(txs.aggregate(sum=Sum('total_amount'))['sum'] or 0)
            commission_earned = Decimal('0.00')

        commission_rate = self._latest_commission_rate(obj) or Decimal('0.00')
        if commission_earned == Decimal('0.00') and total_sales:
            try:
                commission_earned = (total_sales * commission_rate) / Decimal(100)
            except Exception:
                commission_earned = Decimal('0.00')

        yearly_target = self._get_yearly_target_for(obj, year)
        yearly_target_achievement = None
        if yearly_target:
            try:
                actual_sales = self._sales_for_marketer_year(obj, year)
                yearly_target_achievement = float((actual_sales / yearly_target) * Decimal(100)) if yearly_target > 0 else None
                yearly_target_achievement = max(0.0, min(yearly_target_achievement, 100.0))
            except Exception:
                yearly_target_achievement = None

        return {
            "closed_deals": closed_deals,
            "total_sales": total_sales.quantize(Decimal("0.01")) if isinstance(total_sales, Decimal) else total_sales,
            "commission_earned": Decimal(commission_earned).quantize(Decimal("0.01")),
            "commission_rate": Decimal(commission_rate).quantize(Decimal("0.01")),
            "yearly_target": yearly_target.quantize(Decimal('0.01')) if isinstance(yearly_target, Decimal) else yearly_target,
            "yearly_target_achievement": round(yearly_target_achievement, 2) if yearly_target_achievement is not None else None,
        }

    def _build_leaderboard_entry(self, marketer, rank, year):
        """
        Return structure expected by template:
        { rank, marketer: SmallMarketerSerializer, has_target, diff_pct (ABS), category }
        Category values: "Above Target", "On Target", "Below Target"
        diff_pct is the absolute percent difference (non-signed)
        """
        total_sales = self._sales_for_marketer_year(marketer, year)
        target = self._get_yearly_target_for(marketer, year)
        has_target = target is not None

        diff_pct = None
        category = None

        if has_target and target and target > 0:
            # signed difference: positive means above target, negative means below
            signed_diff = (Decimal(total_sales) - Decimal(target)) / Decimal(target) * Decimal(100)
            # absolute percent for display (so template can prefix "+")
            diff_pct = float(abs(signed_diff))
            # category tells direction
            # treat exact zero (within tiny epsilon) as "On Target"
            eps = Decimal('0.000001')
            if signed_diff.copy_abs() <= eps:
                category = "On Target"
            elif signed_diff > 0:
                category = "Above Target"
            else:
                category = "Below Target"

        return {
            "rank": rank,
            "marketer": SmallMarketerSerializer(marketer, context=self.context).data,
            "has_target": has_target,
            "diff_pct": round(diff_pct, 2) if diff_pct is not None else None,
            "category": category
        }

    
   
    def get_top3(self, obj):
        """
        Compute top 3 marketers by total_sales in current year.
        Implementation avoids Coalesce / direct annotate on MarketerUser to
        ensure compatibility across Django versions.
        Steps:
         - aggregate transactions by marketer for the year
         - pick top 3 marketer ids by total
         - if fewer than 3, fill from other marketers (zero-sales) ordered by full_name
        """
        year = date.today().year


        sales_agg = (
            Transaction.objects
            .filter(transaction_date__year=year)
            .values('marketer')
            .annotate(total=Sum('total_amount'))
            .order_by('-total')
        )

        top_ids = [item['marketer'] for item in sales_agg if item.get('marketer')]
        entries = []
        rank = 1

        # Add actual top sellers (from transactions)
        for m_id in top_ids[:3]:
            try:
                marketer = MarketerUser.objects.get(pk=m_id)
            except MarketerUser.DoesNotExist:
                continue
            entries.append(self._build_leaderboard_entry(marketer, rank, year))
            rank += 1

        # If we have fewer than 3, fill with marketers who have zero sales (alphabetical)
        if len(entries) < 3:
            exclude_ids = top_ids
            needed = 3 - len(entries)
            zeros_qs = MarketerUser.objects.exclude(id__in=exclude_ids).order_by('full_name')[:needed]
            for marketer in zeros_qs:
                entries.append(self._build_leaderboard_entry(marketer, rank, year))
                rank += 1

        return entries

    def get_user_entry(self, obj):
        """
        Return current user's position (rank) among all marketers for current year.
        Build the same ordering as get_top3 uses: first marketers with sales desc,
        then remaining marketers (zero sales) ordered by full_name.
        """
        year = date.today().year

        # 1) ids ordered by sales (descending)
        sales_agg = (
            Transaction.objects
            .filter(transaction_date__year=year)
            .values('marketer')
            .annotate(total=Sum('total_amount'))
            .order_by('-total')
        )
        ordered_ids = [item['marketer'] for item in sales_agg if item.get('marketer')]

        # 2) append remaining marketers with zero sales, ordered by name
        remaining_ids = list(MarketerUser.objects.exclude(id__in=ordered_ids).order_by('full_name').values_list('id', flat=True))
        ordered_ids.extend(remaining_ids)

        # 3) find rank (1-based). If not found, rank=0
        try:
            idx = ordered_ids.index(obj.id)
            rank = idx + 1
        except ValueError:
            rank = 0

        return self._build_leaderboard_entry(obj, rank or 0, year)
    

