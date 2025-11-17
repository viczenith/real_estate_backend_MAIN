from django.utils import timezone
from django.db.models import Count, Q
from django.views.decorators.cache import cache_page
from django.utils.decorators import method_decorator
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from rest_framework.authentication import TokenAuthentication, SessionAuthentication

from datetime import timedelta, date
from dateutil.relativedelta import relativedelta

from estateApp.models import Transaction, ClientUser
from DRF.marketers.serializers.marketer_dashboard_serializers import DashboardFullSerializer

from DRF.marketers.api_views.marketer_profile_views import IsMarketer


def _daterange(start_date, end_date):
    """Yield dates from start_date to end_date inclusive."""
    cur = start_date
    while cur <= end_date:
        yield cur
        cur += timedelta(days=1)


def _month_labels(start_date, months):
    """Return list of (year, month) tuples for months starting from start_date (inclusive)"""
    labels = []
    cur = start_date
    for _ in range(months):
        labels.append((cur.year, cur.month))
        cur = cur + relativedelta(months=+1)
    return labels


def _format_date_label(d):
    return d.strftime("%d %b %Y")


def _format_month_label(yr, m):
    return date(yr, m, 1).strftime("%b %Y")


def build_daily_block(marketer, start_date, end_date):
    labels = []
    tx = []
    est = []
    cli = []

    for d in _daterange(start_date, end_date):
        labels.append(_format_date_label(d))

        tx_count = Transaction.objects.filter(
            marketer=marketer,
            transaction_date=d
        ).count()
        est_count = Transaction.objects.filter(
            marketer=marketer,
            transaction_date=d,
            allocation__payment_type='full'
        ).count()
        client_count = ClientUser.objects.filter(
            assigned_marketer=marketer,
            date_registered__date=d
        ).count()

        tx.append(tx_count)
        est.append(est_count)
        cli.append(client_count)

    return {"labels": labels, "tx": tx, "est": est, "cli": cli}


def build_monthly_block(marketer, months_back=12):
    today = timezone.localdate()
    first_of_month = date(today.year, today.month, 1) - relativedelta(months=months_back-1)
    month_tuples = _month_labels(first_of_month, months_back)

    labels = []
    tx = []
    est = []
    cli = []

    for yr, m in month_tuples:
        labels.append(_format_month_label(yr, m))
        start = date(yr, m, 1)
        end = start + relativedelta(months=+1) - timedelta(days=1)

        tx_count = Transaction.objects.filter(
            marketer=marketer,
            transaction_date__range=(start, end)
        ).count()

        est_count = Transaction.objects.filter(
            marketer=marketer,
            transaction_date__range=(start, end),
            allocation__payment_type='full'
        ).count()

        client_count = ClientUser.objects.filter(
            assigned_marketer=marketer,
            date_registered__date__range=(start, end)
        ).count()

        tx.append(tx_count)
        est.append(est_count)
        cli.append(client_count)

    return {"labels": labels, "tx": tx, "est": est, "cli": cli}


def build_yearly_block(marketer, years_back=5):
    today = timezone.localdate()
    start_year = today.year - (years_back - 1)
    labels = []
    tx = []
    est = []
    cli = []
    for yr in range(start_year, today.year + 1):
        labels.append(str(yr))
        start = date(yr, 1, 1)
        end = date(yr, 12, 31)

        tx_count = Transaction.objects.filter(
            marketer=marketer,
            transaction_date__range=(start, end)
        ).count()

        est_count = Transaction.objects.filter(
            marketer=marketer,
            transaction_date__range=(start, end),
            allocation__payment_type='full'
        ).count()

        client_count = ClientUser.objects.filter(
            assigned_marketer=marketer,
            date_registered__year=yr
        ).count()

        tx.append(tx_count)
        est.append(est_count)
        cli.append(client_count)

    return {"labels": labels, "tx": tx, "est": est, "cli": cli}


def build_alltime_block(marketer):
    first_tx = Transaction.objects.filter(marketer=marketer).order_by('transaction_date').first()
    first_client = ClientUser.objects.filter(assigned_marketer=marketer).order_by('date_registered').first()

    earliest = None
    dates = []
    if first_tx and first_client:
        earliest = min(first_tx.transaction_date, first_client.date_registered.date())
    elif first_tx:
        earliest = first_tx.transaction_date
    elif first_client:
        earliest = first_client.date_registered.date()

    if not earliest:
        today = timezone.localdate()
        return {"labels": [_format_date_label(today)], "tx": [0], "est": [0], "cli": [0]}

    start_year = earliest.year
    end_year = timezone.localdate().year
    labels = []
    tx = []
    est = []
    cli = []
    for yr in range(start_year, end_year + 1):
        labels.append(str(yr))
        start = date(yr, 1, 1)
        end = date(yr, 12, 31)

        tx_count = Transaction.objects.filter(
            marketer=marketer,
            transaction_date__range=(start, end)
        ).count()

        est_count = Transaction.objects.filter(
            marketer=marketer,
            transaction_date__range=(start, end),
            allocation__payment_type='full'
        ).count()

        client_count = ClientUser.objects.filter(
            assigned_marketer=marketer,
            date_registered__year=yr
        ).count()

        tx.append(tx_count)
        est.append(est_count)
        cli.append(client_count)

    return {"labels": labels, "tx": tx, "est": est, "cli": cli}


@method_decorator(cache_page(60 * 15), name='dispatch')
class MarketerDashboardAPIView(APIView):
    """
    Returns:
    {
      summary: { total_transactions, total_estates_sold, number_clients },
      weekly: { labels, tx, est, cli },
      monthly: { labels, tx, est, cli },
      yearly: { labels, tx, est, cli },
      alltime: { labels, tx, est, cli }
    }
    """
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (permissions.IsAuthenticated, IsMarketer)

    def get(self, request, *args, **kwargs):
        user = request.user
        try:
            marketer = user if getattr(user, 'role', '') == 'marketer' else None
            marketer_id = request.query_params.get('marketer_id')
            if (not marketer) and (marketer_id and (user.is_staff or user.is_superuser)):
                from estateApp.models import MarketerUser
                marketer = MarketerUser.objects.filter(pk=marketer_id).first()
            if not marketer:
                from estateApp.models import MarketerUser
                marketer = MarketerUser.objects.filter(pk=user.id).first()
            if not marketer:
                return Response({'detail': 'Marketer profile not found.'}, status=status.HTTP_404_NOT_FOUND)
        except Exception:
            return Response({'detail': 'Could not locate marketer.'}, status=status.HTTP_400_BAD_REQUEST)

        total_transactions = Transaction.objects.filter(marketer=marketer).count()
        total_estates_sold = Transaction.objects.filter(marketer=marketer, allocation__payment_type='full').values('allocation__estate').distinct().count()
        number_clients = ClientUser.objects.filter(assigned_marketer=marketer).count()

        summary = {
            "total_transactions": total_transactions,
            "total_estates_sold": total_estates_sold,
            "number_clients": number_clients
        }

        today = timezone.localdate()
        start_week = today - timedelta(days=6)
        weekly = build_daily_block(marketer, start_week, today)

        monthly = build_monthly_block(marketer, months_back=12)

        yearly = build_yearly_block(marketer, years_back=5)

        alltime = build_alltime_block(marketer)

        payload = {
            "summary": summary,
            "weekly": weekly,
            "monthly": monthly,
            "yearly": yearly,
            "alltime": alltime
        }

        serializer = DashboardFullSerializer(payload)
        return Response(serializer.data, status=status.HTTP_200_OK)


@method_decorator(cache_page(60 * 10), name='dispatch')
class MarketerChartRangeAPIView(APIView):
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (permissions.IsAuthenticated, IsMarketer)

    def get(self, request, *args, **kwargs):
        range_key = request.query_params.get('range', 'weekly')
        user = request.user
        from estateApp.models import MarketerUser
        if getattr(user, 'role', '') == 'marketer':
            marketer = user
        else:
            marketer_id = request.query_params.get('marketer_id')
            marketer = MarketerUser.objects.filter(pk=marketer_id).first() if marketer_id and (user.is_staff or user.is_superuser) else None

        if not marketer:
            return Response({'detail': 'Marketer not found'}, status=status.HTTP_404_NOT_FOUND)

        if range_key == 'weekly':
            today = timezone.localdate()
            start_week = today - timedelta(days=6)
            block = build_daily_block(marketer, start_week, today)
        elif range_key == 'monthly':
            block = build_monthly_block(marketer, months_back=12)
        elif range_key == 'yearly':
            block = build_yearly_block(marketer, years_back=5)
        else:
            block = build_alltime_block(marketer)

        return Response(block, status=status.HTTP_200_OK)
