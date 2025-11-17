from decimal import Decimal
from datetime import date
from dateutil.relativedelta import relativedelta
from django.db.models import Sum, Q
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from rest_framework import status, permissions, serializers as drf_serializers
from rest_framework.authentication import TokenAuthentication, SessionAuthentication
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
# from weasyprint import HTML, CSS  # Commented out due to Windows compatibility issues
from xhtml2pdf import pisa
import uuid
import logging
from io import BytesIO
from django.conf import settings
from django.template.loader import render_to_string, get_template

logger = logging.getLogger(__name__)
from django.urls import reverse
from django.core.signing import dumps, loads, BadSignature, SignatureExpired
from DRF.clients.serializers.client_profile_serializer import (
    PaymentRecordSerializer,
    ProfileSerializer,
    PlotAllocationSerializer,
    AppreciationPointSerializer,
    TransactionSerializer,
)
from estateApp.models import *

try:
    # from weasyprint import HTML, CSS  # Commented out due to Windows compatibility issues
    from xhtml2pdf import pisa
    HAVE_WEASY = True  # Keep the same flag name for backward compatibility
except Exception:
    HAVE_WEASY = False


class ChangePasswordSerializer(drf_serializers.Serializer):
    current_password = drf_serializers.CharField(required=True)
    new_password = drf_serializers.CharField(required=True, min_length=6)

class ClientProfileView(APIView):
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, *args, **kwargs):
        user = request.user
        try:
            # Optimize query with prefetch to reduce database hits
            client_obj = ClientUser.objects.select_related(
                'assigned_marketer'
            ).prefetch_related(
                'transactions',
                'transactions__allocation',
                'transactions__allocation__estate',
                'transactions__allocation__plot_size_unit',
                'plotallocation_set',
                'plotallocation_set__estate',
                'plotallocation_set__plot_size_unit'
            ).filter(pk=user.pk).first() or user
        except Exception:
            client_obj = user

        serializer = ProfileSerializer(client_obj, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)
        
class ClientProfileUpdateView(APIView):
    authentication_classes = (TokenAuthentication,)
    permission_classes = (permissions.IsAuthenticated,)
    parser_classes = (MultiPartParser, FormParser)

    def post(self, request, *args, **kwargs):
        user = request.user

        updatable = [
            'full_name', 'phone', 'address', 'date_of_birth',
            'about', 'company', 'job', 'country', 'email'
        ]
        for f in updatable:
            if f in request.data:
                val = request.data.get(f)
                if f == 'date_of_birth' and (val == '' or val is None):
                    setattr(user, f, None)
                else:
                    setattr(user, f, val)

        if 'profile_image' in request.FILES:
            user.profile_image = request.FILES['profile_image']

        user.save()
        try:
            client_obj = ClientUser.objects.select_related('assigned_marketer').filter(pk=user.pk).first() or user
        except Exception:
            client_obj = user

        serializer = ProfileSerializer(client_obj, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)

class ClientPropertiesView(APIView):
    authentication_classes = (TokenAuthentication,)
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, *args, **kwargs):
        user = request.user
        qs = Transaction.objects.filter(client=user).select_related(
            'allocation__estate', 'allocation__plot_size_unit'
        ).prefetch_related('payment_records')
        serializer = TransactionSerializer(qs, many=True, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)

class ClientAppreciationView(APIView):
    authentication_classes = (TokenAuthentication,)
    permission_classes = (permissions.IsAuthenticated,)

    def _serialize_points(self, points):
        normalized = []
        for p in points:
            d = p['date']
            if hasattr(d, 'isoformat'):
                d = d.isoformat()
            normalized.append({'date': d, 'value': float(p['value'])})
        return normalized

    def _serialize_transactions_for_user(self, request, user):
        qs = Transaction.objects.filter(client=user).select_related(
            'allocation__estate', 'allocation__plot_size_unit', 'marketer'
        ).prefetch_related('payment_records')
        serializer = TransactionSerializer(qs, many=True, context={'request': request})
        return serializer.data

    def get(self, request, *args, **kwargs):
        user = request.user
        allocations = PlotAllocation.objects.filter(client=user)

        if not allocations.exists():
            return Response({'series': [], 'transactions': []}, status=status.HTTP_200_OK)

        monthly_totals = {}
        found_history = False

        for alloc in allocations:
            try:
                ph_qs = PriceHistory.objects.filter(price__plot_unit=alloc.plot_size_unit).order_by('recorded_at')
                if ph_qs.exists():
                    found_history = True
                    for ph in ph_qs:
                        key = ph.recorded_at.date().replace(day=1)
                        monthly_totals.setdefault(key, 0.0)
                        monthly_totals[key] += float(ph.current)
            except Exception:
                continue

        transactions_payload = self._serialize_transactions_for_user(request, user)

        if found_history and monthly_totals:
            keys = sorted(monthly_totals.keys())
            start = keys[0]
            end = keys[-1]
            cur = start
            filled = {}
            last_val = 0.0
            while cur <= end:
                val = monthly_totals.get(cur, last_val)
                filled[cur] = float(val)
                last_val = float(val)
                cur = cur + relativedelta(months=1)

            items = sorted(filled.items())[-12:]
            payload = [{'date': k, 'value': v} for k, v in items]
            serialized_series = self._serialize_points(payload)

            return Response({
                'series': serialized_series,
                'transactions': transactions_payload
            }, status=status.HTTP_200_OK)

        total_current = 0.0
        for alloc in allocations:
            try:
                pp = PropertyPrice.objects.filter(
                    estate=alloc.estate, plot_unit=alloc.plot_size_unit
                ).order_by('-created_at').first()
                if pp:
                    total_current += float(pp.current)
            except Exception:
                continue

        pct_list = []
        for alloc in allocations:
            try:
                phs = PriceHistory.objects.filter(price__plot_unit=alloc.plot_size_unit).order_by('recorded_at')
                if phs.count() >= 2:
                    first = float(phs.first().current)
                    last = float(phs.last().current)
                    if first > 0:
                        pct = ((last - first) / first) * 100.0
                        pct_list.append(pct)
            except Exception:
                continue

        avg_annual_pct = (sum(pct_list) / len(pct_list)) if pct_list else 0.0
        monthly_rate = (avg_annual_pct / 100.0) / 12.0

        series = []
        today = date.today()
        for months_ago in reversed(range(0, 12)):
            dt = today - relativedelta(months=months_ago)
            months_from_now = months_ago
            denom = ((1.0 + monthly_rate) ** months_from_now) if (1.0 + monthly_rate) != 0 else 1.0
            approx_value = total_current / denom if denom != 0 else total_current
            series.append({'date': dt, 'value': round(float(approx_value), 2)})

        serialized_series = self._serialize_points(series)

        return Response({
            'series': serialized_series,
            'transactions': transactions_payload
        }, status=status.HTTP_200_OK)

class ChangePasswordView(APIView):
    authentication_classes = (TokenAuthentication,)
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, *args, **kwargs):
        serializer = ChangePasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        user = request.user
        current = serializer.validated_data['current_password']
        new = serializer.validated_data['new_password']

        if not user.check_password(current):
            return Response({'detail': 'Current password is incorrect.'}, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(new)
        user.save()
        return Response({'detail': 'Password updated successfully.'}, status=status.HTTP_200_OK)


class ClientTransactionsView(APIView):
    authentication_classes = (TokenAuthentication,)
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, *args, **kwargs):
        user = request.user
        qs = Transaction.objects.filter(client=user).select_related(
            'allocation__estate', 'allocation__plot_size_unit', 'marketer'
        ).prefetch_related('payment_records')
        serializer = TransactionSerializer(qs, many=True, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)

class TransactionDetailView(APIView):
    authentication_classes = (TokenAuthentication,)
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, transaction_id, *args, **kwargs):
        try:
            t = Transaction.objects.select_related('allocation__estate', 'allocation__plot_size_unit').get(pk=transaction_id, client=request.user)
        except Transaction.DoesNotExist:
            return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

        data = {
            'id': t.id,
            'allocation': {
                'estate': {'id': t.allocation.estate.id, 'name': t.allocation.estate.name},
                'plot_size': getattr(t.allocation.plot_size_unit.plot_size, 'size', None) if t.allocation.plot_size_unit else getattr(t.allocation.plot_size, 'size', None),
                'plot_number': t.allocation.plot_number.number if t.allocation.plot_number else None,
                'payment_type': t.allocation.payment_type,
            },
            'transaction_date': t.transaction_date.isoformat(),
            'total_amount': float(t.total_amount),
            'status': t.status,
            'installment_plan': t.installment_plan,
            'first_percent': t.first_percent,
            'second_percent': t.second_percent,
            'third_percent': t.third_percent,
            'first_installment': float(t.first_installment) if t.first_installment else None,
            'second_installment': float(t.second_installment) if t.second_installment else None,
            'third_installment': float(t.third_installment) if t.third_installment else None,
        }

        prs = t.payment_records.order_by('payment_date')
        payments_serializer = PaymentRecordSerializer(prs, many=True)
        data['payments'] = payments_serializer.data

        return Response(data, status=status.HTTP_200_OK)

class TransactionPaymentsView(APIView):
    authentication_classes = (TokenAuthentication,)
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, *args, **kwargs):
        tx_id = request.query_params.get('transaction_id') or request.data.get('transaction_id')
        if not tx_id:
            return Response({'detail': 'transaction_id required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            t = Transaction.objects.get(pk=tx_id, client=request.user)
        except Transaction.DoesNotExist:
            return Response({'detail': 'not found'}, status=status.HTTP_404_NOT_FOUND)

        prs = t.payment_records.order_by('payment_date')
        serializer = PaymentRecordSerializer(prs, many=True)
        return Response({'payments': serializer.data}, status=status.HTTP_200_OK)



# CLIENT TRANSACTION RECIEPTS
class ClientTransactionReceiptByIdAPIView(APIView):
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, transaction_id, *args, **kwargs):
        txn = get_object_or_404(Transaction.objects.select_related('client'), pk=transaction_id)
        if txn.client_id != request.user.id:
            return Response({'detail': 'Forbidden'}, status=status.HTTP_403_FORBIDDEN)

        payments_qs = PaymentRecord.objects.filter(transaction=txn).order_by('payment_date')
        payment = payments_qs.first() if payments_qs.exists() else None
        payments_total = sum([p.amount_paid for p in payments_qs]) if payments_qs.exists() else txn.total_amount

        context = {
            'transaction': txn,
            'payment': payment,
            'payments': payments_qs if payments_qs.exists() else None,
            'payments_total': payments_total,
            'today': getattr(__import__('django.utils.timezone', fromlist=['now']), 'now')().date(),
            'company': {
                'name': "NeuraLens Properties",
                'address': "123 NeuraLens, Wuse Zone 4, Abuja",
                'phone': "+234 812 345 6789",
                'email': "info@neuralensproperties.com",
                'website': "www.neuralensproperties.com"
            }
        }

        html_string = render_to_string('admin_side/management_page_sections/absolute_payment_reciept.html', context)

        if HAVE_WEASY:
            # Add CSS styling directly to the HTML
            html_with_css = f"""
            <html>
            <head>
                <style>
                    @page {{ size: A4; margin: 20mm; }}
                </style>
            </head>
            <body>
                {html_string}
            </body>
            </html>
            """
            
            # Create PDF using xhtml2pdf
            result = BytesIO()
            pdf = pisa.pisaDocument(BytesIO(html_with_css.encode("UTF-8")), result)
            
            if not pdf.err:
                resp = HttpResponse(result.getvalue(), content_type='application/pdf')
                resp['Content-Disposition'] = f'attachment; filename="receipt_txn_{transaction_id}.pdf"'
                return resp

        return HttpResponse(html_string, content_type='text/html')

class ClientPaymentReceiptByReferenceAPIView(APIView):
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (AllowAny,)

    SIGNING_SALT = 'receipt-download-salt'
    SIGN_MAX_AGE = 10 * 60

    TRANSACTION_REF_FIELDS = ['reference_code', 'receipt_number', 'reference', 'receipt']
    PAYMENTREF_FIELDS = ['reference_code', 'receipt_number', 'reference', 'receipt']

    def _authorize_by_signature(self, signature, reference):
        try:
            data = loads(signature, max_age=self.SIGN_MAX_AGE, salt=self.SIGNING_SALT)
        except SignatureExpired:
            return False, 'expired'
        except BadSignature:
            return False, 'bad'
        if not isinstance(data, dict):
            return False, 'invalid'
        if data.get('ref') != reference:
            return False, 'mismatch'
        try:
            user = ClientUser.objects.get(pk=data.get('uid'))
        except Exception:
            return False, 'no_user'
        return True, user

    def _model_has_field(self, model, name):
        return name in {f.name for f in model._meta.get_fields()}

    def _build_q_for_fields(self, model, field_names, ref_value):
        q = Q()
        for field in field_names:
            if self._model_has_field(model, field):
                q |= Q(**{f"{field}__iexact": ref_value})
        return q if q.children else None

    def get(self, request, reference=None, *args, **kwargs):
        ref_from_query = request.query_params.get('reference')
        sig = request.query_params.get('sig')
        txid_param = request.query_params.get('transaction_id') or request.query_params.get('transaction')

        reference = (reference or ref_from_query or '').strip()
        if not reference:
            return Response({'detail': 'reference required'}, status=status.HTTP_400_BAD_REQUEST)

        user = None
        if sig:
            ok, payload = self._authorize_by_signature(sig, reference)
            if not ok:
                logger.debug("Receipt sig auth failed for ref=%s reason=%s", reference, payload)
                return Response({'detail': 'Invalid or expired download token'}, status=status.HTTP_403_FORBIDDEN)
            user = payload

        if user is None:
            if not request.user or not request.user.is_authenticated:
                return Response({'detail': 'Authentication credentials were not provided.'}, status=status.HTTP_401_UNAUTHORIZED)
            user = request.user

        txn_q = self._build_q_for_fields(Transaction, self.TRANSACTION_REF_FIELDS, reference)
        txn = None
        if txn_q is not None:
            try:
                txn = Transaction.objects.filter(txn_q, client=user).select_related('allocation__estate').first()
                if txn:
                    logger.debug("Found transaction by reference on Transaction model: ref=%s txn_id=%s", reference, txn.id)
            except Exception as e:
                logger.exception("Error querying Transaction for receipt ref=%s: %s", reference, e)

        payments_qs = None
        payment = None
        if txn is None:
            pay_q = self._build_q_for_fields(PaymentRecord, self.PAYMENTREF_FIELDS, reference)
            if pay_q is not None:
                try:
                    payments_qs = PaymentRecord.objects.filter(pay_q, transaction__client=user).select_related('transaction').order_by('payment_date')
                    if payments_qs.exists():
                        payment = payments_qs.first()
                        txn = payment.transaction
                        logger.debug("Found payment record by reference: ref=%s payment_id=%s txn_id=%s", reference, payment.id, txn.id)
                    else:
                        payments_qs = None
                except Exception as e:
                    logger.exception("Error querying PaymentRecord for receipt ref=%s: %s", reference, e)

        if txn is None:
            alt_ref = reference.replace(' ', '').upper().strip().rstrip('/')
            if alt_ref != reference.upper():
                txn_q_alt = self._build_q_for_fields(Transaction, self.TRANSACTION_REF_FIELDS, alt_ref)
                if txn_q_alt is not None:
                    txn = Transaction.objects.filter(txn_q_alt, client=user).first()
                    if txn:
                        logger.debug("Found transaction by normalized alt ref: orig=%s alt=%s txn_id=%s", reference, alt_ref, txn.id)

                if txn is None:
                    pay_q_alt = self._build_q_for_fields(PaymentRecord, self.PAYMENTREF_FIELDS, alt_ref)
                    if pay_q_alt is not None:
                        payments_qs = PaymentRecord.objects.filter(pay_q_alt, transaction__client=user).select_related('transaction').order_by('payment_date')
                        if payments_qs.exists():
                            payment = payments_qs.first()
                            txn = payment.transaction
                            logger.debug("Found payment by normalized alt ref: orig=%s alt=%s payment_id=%s txn_id=%s", reference, alt_ref, payment.id, txn.id)

        if txn is None:
            if txid_param:
                try:
                    txid = int(txid_param)
                    txn = Transaction.objects.select_related('client', 'allocation__estate').filter(pk=txid, client=user).first()
                    if txn:
                        logger.debug("Fallback found txn by provided transaction_id=%s for ref=%s", txid, reference)
                except Exception:
                    pass

        if txn is None:
            logger.info("Receipt not found for ref=%s (user=%s). Tried Transaction fields %s and Payment fields %s",
                        reference, getattr(user, 'id', None), self.TRANSACTION_REF_FIELDS, self.PAYMENTREF_FIELDS)
            return Response({'detail': 'Receipt not found'}, status=status.HTTP_404_NOT_FOUND)

        payments_total = txn.total_amount
        if payments_qs is not None:
            try:
                payments_total = sum([p.amount_paid for p in payments_qs])
            except Exception:
                pass

        context = {
            'transaction': txn,
            'payment': payment,
            'payments': payments_qs,
            'payments_total': payments_total,
            'today': getattr(__import__('django.utils.timezone', fromlist=['now']), 'now')().date(),
            'company': {
                'name': "NeuraLens Properties",
                'address': "123 NeuraLens, Wuse Zone 4, Abuja",
                'phone': "+234 812 345 6789",
                'email': "info@neuralensproperties.com",
                'website': "www.neuralensproperties.com"
            }
        }

        html_string = render_to_string('admin_side/management_page_sections/absolute_payment_reciept.html', context)

        if HAVE_WEASY:
            # Add CSS styling directly to the HTML
            html_with_css = f"""
            <html>
            <head>
                <style>
                    @page {{ size: A4; margin: 20mm; }}
                </style>
            </head>
            <body>
                {html_string}
            </body>
            </html>
            """
            
            # Create PDF using xhtml2pdf
            result = BytesIO()
            pdf = pisa.pisaDocument(BytesIO(html_with_css.encode("UTF-8")), result)
            
            if not pdf.err:
                resp = HttpResponse(result.getvalue(), content_type='application/pdf')
                resp['Content-Disposition'] = f'attachment; filename="receipt_{reference}.pdf"'
                return resp

        return HttpResponse(html_string, content_type='text/html')

class ReceiptDownloadTokenAPIView(APIView):
    authentication_classes = (TokenAuthentication,)
    permission_classes = (permissions.IsAuthenticated,)

    MAX_AGE = 10 * 60
    SIGNING_SALT = 'receipt-download-salt'

    def post(self, request, *args, **kwargs):
        reference = request.data.get('reference')
        if not reference:
            return Response({'detail': 'reference required'}, status=status.HTTP_400_BAD_REQUEST)

        if Transaction.objects.filter(reference_code=reference, client=request.user).exists():
            pass
        elif PaymentRecord.objects.filter(reference_code=reference, transaction__client=request.user).exists():
            pass
        else:
            return Response({'detail': 'not found or not allowed'}, status=status.HTTP_404_NOT_FOUND)

        payload = {'ref': reference, 'uid': request.user.id}
        sig = dumps(payload, salt=self.SIGNING_SALT)
        download_path = reverse('client-receipt-download')
        download_url = request.build_absolute_uri(f"{download_path}?reference={reference}&sig={sig}")
        return Response({'download_url': download_url, 'expires_in': self.MAX_AGE}, status=status.HTTP_200_OK)


