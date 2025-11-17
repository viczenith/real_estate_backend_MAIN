from django.db.models import Count, Prefetch, Q
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.authentication import TokenAuthentication, SessionAuthentication
from rest_framework.pagination import PageNumberPagination
from rest_framework import permissions
from rest_framework.exceptions import NotFound

from estateApp.models import ClientUser, Transaction, MarketerUser
from DRF.marketers.serializers.client_record_serializers import ClientSummarySerializer, TransactionListSerializer
from DRF.marketers.serializers.client_record_serializers import ClientDetailSerializer

class IsMarketerOrStaffWithAccess(permissions.BasePermission):
    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        if user.is_staff or user.is_superuser:
            return True
        return getattr(user, 'role', '') == 'marketer'

    def has_object_permission(self, request, view, obj):
        if request.user.is_staff or request.user.is_superuser:
            return True
        assigned = getattr(obj, 'assigned_marketer', None)
        return assigned is not None and assigned.pk == request.user.pk


class StandardResultsSetPagination(PageNumberPagination):
    page_size = 12
    page_size_query_param = 'page_size'
    max_page_size = 100


class MarketerClientListAPIView(generics.ListAPIView):
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated, IsMarketerOrStaffWithAccess)
    serializer_class = ClientSummarySerializer
    pagination_class = StandardResultsSetPagination

    def get_queryset(self):
        user = self.request.user
        qs = ClientUser.objects.all().order_by('-date_registered')

        marketer_id = self.request.query_params.get('marketer_id')
        if getattr(user, 'role', '') == 'marketer':
            qs = qs.filter(assigned_marketer_id=user.id)
        elif marketer_id and (user.is_staff or user.is_superuser):
            qs = qs.filter(assigned_marketer_id=marketer_id)

        q = self.request.query_params.get('search')
        if q:
            qs = qs.filter(
                Q(full_name__icontains=q) |
                Q(email__icontains=q) |
                Q(phone__icontains=q)
            )

        qs = qs.annotate(tx_count=Count('transactions')).select_related('assigned_marketer')
        return qs

    def list(self, request, *args, **kwargs):
        page = self.paginate_queryset(self.get_queryset())
        serializer = self.get_serializer(page, many=True, context={'request': request})

        client_ids = [c.id for c in page]
        recent_tx_qs = (Transaction.objects.filter(client_id__in=client_ids)
                        .select_related('allocation__estate', 'allocation__plot_size', 'allocation__plot_number')
                        .order_by('-transaction_date'))

        recent_by_client = {}
        for tx in recent_tx_qs:
            lst = recent_by_client.setdefault(tx.client_id, [])
            if len(lst) < 3:
                lst.append(TransactionListSerializer(tx, context={'request': request}).data)

        results = serializer.data
        for item in results:
            cid = item['id']
            item['recent_transactions'] = recent_by_client.get(cid, [])

        return self.get_paginated_response(results)


class MarketerClientDetailAPIView(generics.RetrieveAPIView):
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (IsAuthenticated, IsMarketerOrStaffWithAccess)
    serializer_class = ClientDetailSerializer
    lookup_field = 'pk'

    def get_object(self):
        pk = self.kwargs.get(self.lookup_field)
        user = self.request.user

        qs = ClientUser.objects.filter(pk=pk)
        if getattr(user, 'role', '') == 'marketer':
            qs = qs.filter(assigned_marketer_id=user.id)
        else:
            marketer_id = self.request.query_params.get('marketer_id')
            if marketer_id:
                qs = qs.filter(assigned_marketer_id=marketer_id)

        client = qs.select_related('assigned_marketer').first()
        if not client:
            raise NotFound(detail='Client not found or not accessible')
        return client

    def get(self, request, *args, **kwargs):
        client = self.get_object()
        tx_qs = (Transaction.objects.filter(client=client)
                 .select_related('allocation__estate', 'allocation__plot_size', 'allocation__plot_number')
                 .order_by('-transaction_date'))
        serializer = self.get_serializer(client, context={'transactions_qs': tx_qs, 'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)
