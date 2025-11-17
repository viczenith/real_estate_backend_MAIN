from rest_framework import permissions, status
from rest_framework.authentication import TokenAuthentication, SessionAuthentication
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.generics import ListAPIView, RetrieveAPIView
from rest_framework.pagination import PageNumberPagination
from decimal import Decimal
from django.utils import timezone
from django.db.models import Prefetch, Q 

from estateApp.models import (
    Transaction, PlotAllocation, PlotSizeUnits, PropertyPrice, PriceHistory,
    PromotionalOffer, Estate, PlotSize, PlotNumber
)

from DRF.clients.serializers.client_dashboard_serializers import (
    EstateDetailSerializer, PromotionDashboardSerializer, PriceHistoryListSerializer,
    EstateSizePriceSerializer, PromotionDetailSerializer, PromotionListItemSerializer, PromotionalOfferSimpleSerializer
)


def _get_active_promo_for_estate(estate):
    today = timezone.localdate()
    return PromotionalOffer.objects.filter(estates=estate, start__lte=today, end__gte=today).order_by('-discount').first()

class ClientDashboardAPIView(APIView):
    authentication_classes = (TokenAuthentication, SessionAuthentication)
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, *args, **kwargs):
        user = request.user

        tx_qs = Transaction.objects.filter(client=user).select_related('allocation__estate', 'allocation__plot_size_unit')
        total_properties = tx_qs.count()

        fully_paid = 0
        for t in tx_qs:
            try:
                if getattr(t.allocation, 'payment_type', '') == 'full':
                    fully_paid += 1
                else:
                    s = getattr(t, 'status', None)
                    if s and str(s).lower() in ('fully paid', 'paid complete', 'paid_complete'):
                        fully_paid += 1
            except Exception:
                continue
        not_fully_paid = max(0, total_properties - fully_paid)

        today = timezone.localdate()
        active_promos_qs = PromotionalOffer.objects.filter(start__lte=today, end__gte=today).prefetch_related(
            Prefetch('estates', queryset=Estate.objects.prefetch_related('property_prices__plot_unit__plot_size', 'promotional_offers'))
        ).order_by('-discount')
        active_promotions = PromotionDashboardSerializer(active_promos_qs, many=True, context={'request': request}).data

        latest_histories = PriceHistory.objects.select_related(
            'price', 'price__estate', 'price__plot_unit', 'price__plot_unit__plot_size'
        ).order_by('-recorded_at')[:50]
        latest_value = PriceHistoryListSerializer(latest_histories, many=True).data

        return Response({
            "total_properties": total_properties,
            "fully_paid_allocations": fully_paid,
            "not_fully_paid_allocations": not_fully_paid,
            "active_promotions": active_promotions,
            "latest_value": latest_value,
        }, status=status.HTTP_200_OK)

class PriceUpdateDetailAPIView(RetrieveAPIView):
    queryset = PriceHistory.objects.select_related('price', 'price__estate', 'price__plot_unit', 'price__plot_unit__plot_size')
    serializer_class = PriceHistoryListSerializer
    permission_classes = (permissions.AllowAny,)
    lookup_field = 'pk'

class EstateListAPIView(ListAPIView):
    """
    API endpoint for estate list with promotional offer support.
    
    Endpoints:
    1. GET /api/estates/ - Returns paginated list of all estates with promo preview
    2. GET /api/estates/?estate_id=X - Returns single estate with full plot sizes & prices
       (Used by promo_estates_list.html modal "View Plots & prices")
    3. GET /api/estates/?q=search - Filter estates by name/location
    
    Response Structure for single estate (?estate_id=X):
    {
        "id": int,
        "name": str,
        "estate_id": int,  # duplicate for template compatibility
        "estate_name": str,  # duplicate for template compatibility
        "location": str,
        "promo": {
            "active": bool,  # True if promo is currently active
            "id": int,
            "name": str,
            "discount": decimal,
            "discount_pct": int,  # integer percentage
            "start": date,
            "end": date
        },
        "promotional_offers": [...],  # all promos for this estate
        "sizes": [
            {
                "plot_unit_id": int,
                "size": str,
                "amount": float,
                "discounted": float,  # amount with promo discount applied
                "discount_pct": int
            }
        ]
    }
    """
    permission_classes = (permissions.AllowAny,)
    pagination_class = PageNumberPagination
    serializer_class = None

    def get_queryset(self):
        qs = Estate.objects.all().order_by('-date_added').prefetch_related(
            Prefetch(
                'promotional_offers', 
                queryset=PromotionalOffer.objects.order_by('-discount', '-start')
            ),
            Prefetch(
                'property_prices', 
                queryset=PropertyPrice.objects.select_related('plot_unit__plot_size').order_by('-created_at')
            )
        )
        q = self.request.GET.get('q')
        if q:
            qs = qs.filter(Q(name__icontains=q) | Q(location__icontains=q))
        return qs

    def list(self, request, *args, **kwargs):
        estate_id = request.GET.get('estate_id')

        # Single estate detail endpoint (for "View Plots & prices" modal)
        if estate_id:
            try:
                estate = Estate.objects.prefetch_related(
                    'property_prices__plot_unit__plot_size',
                    Prefetch(
                        'promotional_offers', 
                        queryset=PromotionalOffer.objects.order_by('-discount', '-start')
                    )
                ).get(pk=int(estate_id))
            except (Estate.DoesNotExist, ValueError):
                return Response({"error": "Estate not found"}, status=status.HTTP_404_NOT_FOUND)

            serializer = EstateDetailSerializer(estate, context={'request': request})
            
            # Debug logging for modal data
            import logging
            logger = logging.getLogger(__name__)
            modal_data = serializer.data
            logger.warning(f"🏢 MODAL DATA for Estate {estate_id} ({estate.name}):")
            logger.warning(f"   📏 Sizes count: {len(modal_data.get('sizes', []))}")
            if modal_data.get('sizes'):
                logger.warning(f"   📐 First size: {modal_data['sizes'][0]}")
            else:
                logger.warning(f"   ⚠️ NO SIZES DATA!")
            logger.warning(f"   🏷️ Promo: {modal_data.get('promo')}")
            logger.warning(f"   📦 Full promotional_offers: {modal_data.get('promotional_offers')}")
            
            return Response(modal_data, status=status.HTTP_200_OK)

        # List all estates with promo preview (for estate listing page)
        qs = self.get_queryset()
        page = self.paginate_queryset(qs)
        if page is not None:
            data = []
            for e in page:
                # Get ALL promos (not just first 3) and serialize them properly
                # This matches Django template which shows all promos with proper active/inactive badges
                promos_qs = e.promotional_offers.all()
                promo_preview = [
                    PromotionalOfferSimpleSerializer(p, context={'request': request}).data
                    for p in promos_qs
                ]
                
                # Format date_added consistently
                date_added = getattr(e, 'date_added', None)
                created_at_str = None
                if date_added:
                    if hasattr(date_added, 'isoformat'):
                        created_at_str = date_added.isoformat()
                    elif hasattr(date_added, 'strftime'):
                        created_at_str = date_added.strftime('%Y-%m-%d')
                    else:
                        created_at_str = str(date_added)
                
                estate_data = {
                    "id": e.id,
                    "name": e.name,
                    "location": e.location,
                    "created_at": created_at_str,
                    "promos_count": len(promo_preview),
                    "promotional_offers": promo_preview  # includes is_active, active, discount_pct, properly formatted dates
                }
                
                # Debug logging
                import logging
                logger = logging.getLogger(__name__)
                logger.warning(f"🏢 Estate {e.id} ({e.name}): {len(promo_preview)} promotional offers")
                if promo_preview:
                    logger.warning(f"🏷️ First promo for {e.name}: {promo_preview[0]}")
                else:
                    logger.warning(f"⚠️ NO PROMOS for estate {e.name}")
                logger.warning(f"📦 Full estate data being sent: {estate_data}")
                
                data.append(estate_data)
            return self.get_paginated_response(data)

        # Fallback: non-paginated entire queryset
        data = []
        for e in qs:
            promos_qs = e.promotional_offers.all()
            promo_preview = [
                PromotionalOfferSimpleSerializer(p, context={'request': request}).data
                for p in promos_qs
            ]
            
            # Format date_added consistently
            date_added = getattr(e, 'date_added', None)
            created_at_str = None
            if date_added:
                if hasattr(date_added, 'isoformat'):
                    created_at_str = date_added.isoformat()
                elif hasattr(date_added, 'strftime'):
                    created_at_str = date_added.strftime('%Y-%m-%d')
                else:
                    created_at_str = str(date_added)
            
            data.append({
                "id": e.id,
                "name": e.name,
                "location": e.location,
                "created_at": created_at_str,
                "promos_count": len(promo_preview),
                "promotional_offers": promo_preview  # includes is_active, active, discount_pct, properly formatted dates
            })
        return Response(data, status=status.HTTP_200_OK)

class ActivePromotionsListAPIView(APIView):
    permission_classes = (permissions.AllowAny,)

    def get(self, request, *args, **kwargs):
        today = timezone.localdate()
        promos = PromotionalOffer.objects.filter(start__lte=today, end__gte=today).prefetch_related(
            Prefetch('estates', queryset=Estate.objects.prefetch_related('property_prices__plot_unit__plot_size'))
        ).order_by('-discount')
        serializer = PromotionDashboardSerializer(promos, many=True, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)


class SmallPageNumberPagination(PageNumberPagination):
    page_size = 12
    page_size_query_param = 'page_size'
    max_page_size = 50

class PromotionsListAPIView(APIView):
    permission_classes = (permissions.AllowAny,)
    pagination_class = SmallPageNumberPagination

    def get(self, request, *args, **kwargs):
        today = timezone.localdate()
        q = request.GET.get('q', '').strip()
        filt = request.GET.get('filter', 'all').lower()

        base_qs = PromotionalOffer.objects.prefetch_related(
            Prefetch('estates', queryset=Estate.objects.only('id', 'name', 'location'))
        ).order_by('-start', '-created_at')

        active_qs = base_qs.filter(start__lte=today, end__gte=today)
        active_serialized = PromotionListItemSerializer(active_qs, many=True, context={'request': request}).data

        if filt == 'active':
            promos_qs = active_qs
        elif filt == 'past':
            promos_qs = base_qs.filter(end__lt=today)
        else:
            promos_qs = base_qs.exclude(pk__in=active_qs.values_list('pk', flat=True))

        if q:
            promos_qs = promos_qs.filter(Q(name__icontains=q) | Q(description__icontains=q))

        paginator = self.pagination_class()
        page = paginator.paginate_queryset(promos_qs, request, view=self)
        serialized_page = PromotionListItemSerializer(page, many=True, context={'request': request}).data
        paginated_response = paginator.get_paginated_response(serialized_page).data

        return Response({
            "active_promotions": active_serialized,
            "promotions": paginated_response
        }, status=status.HTTP_200_OK)



class PromotionDetailAPIView(RetrieveAPIView):
    queryset = PromotionalOffer.objects.prefetch_related(
        Prefetch('estates', queryset=Estate.objects.prefetch_related('property_prices__plot_unit__plot_size'))
    )
    serializer_class = PromotionDetailSerializer
    permission_classes = (permissions.AllowAny,)
    lookup_field = 'pk'

