from django.db.models import Prefetch
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.response import Response

from estateApp.models import (
    Estate, EstateFloorPlan, EstatePrototype, EstateLayout, EstateMap,
    EstateAmenitie, ProgressStatus, PlotSize, PlotSizeUnits, PlotNumber,
    EstatePlot, PlotAllocation
)
from DRF.clients.serializers.client_estate_detail_serializer import (
    EstateListSerializer, EstateDetailSerializer,
    PlotSizeUnitsSerializer
)


class EstateListAPIView(generics.ListAPIView):
    queryset = Estate.objects.all().order_by('-date_added')
    serializer_class = EstateListSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = None


class EstateDetailAPIView(generics.RetrieveAPIView):
    queryset = Estate.objects.all()
    serializer_class = EstateDetailSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Prefetch related objects efficiently to reduce DB hits.
        # Use select_related for FK (if any) and prefetch_related for m2m/related sets.
        qs = super().get_queryset().prefetch_related(
            Prefetch('progress_status', queryset=ProgressStatus.objects.order_by('-timestamp')),
            Prefetch('estate_amenity', queryset=EstateAmenitie.objects.all()),
            Prefetch('estate_layout', queryset=EstateLayout.objects.all()),
            Prefetch('prototypes', queryset=EstatePrototype.objects.select_related('plot_size').order_by('-date_uploaded')),
            Prefetch('floor_plans', queryset=EstateFloorPlan.objects.select_related('plot_size').order_by('-date_uploaded')),
            Prefetch('map', queryset=EstateMap.objects.all()),
            Prefetch('estate_plots__plotsizeunits__plot_size'),
        )
        return qs

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
