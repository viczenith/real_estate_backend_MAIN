from rest_framework import serializers
from django.conf import settings
from estateApp.models import (
    Estate, EstateFloorPlan, EstatePrototype, EstateLayout, EstateMap,
    EstateAmenitie, ProgressStatus, PlotSize, PlotSizeUnits, PlotNumber,
    EstatePlot, PlotAllocation
)


class PlotSizeSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlotSize
        fields = ('id', 'size')


class PlotSizeUnitsSerializer(serializers.ModelSerializer):
    plot_size = PlotSizeSerializer(read_only=True)

    class Meta:
        model = PlotSizeUnits
        fields = ('id', 'plot_size', 'total_units', 'available_units', 'computed_available_units')


class PlotNumberSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlotNumber
        fields = ('id', 'number')


class ProgressStatusSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProgressStatus
        fields = ('id', 'progress_status', 'timestamp')


class EstateAmenitySerializer(serializers.ModelSerializer):
    # returns amenity ids + display list (list-of-lists or list-of-tuples serialized -> list of lists)
    amenities_display = serializers.SerializerMethodField()

    class Meta:
        model = EstateAmenitie
        fields = ('id', 'amenities', 'amenities_display')

    def get_amenities_display(self, obj):
        # get_amenity_display() returns a list of (display_name, icon_class) in your template
        try:
            return obj.get_amenity_display() or []
        except Exception:
            # fallback: attempt to marshal if stored differently
            ad = getattr(obj, 'amenities_display', None)
            if isinstance(ad, (list, tuple)):
                return ad
            return []


#
# Image helpers: produce absolute urls using request context
#
def absolute_image_url(request, field_file):
    if not field_file:
        return ''
    try:
        # if serializer has request in context, use request.build_absolute_uri
        if request is not None:
            # field_file may be ImageFieldFile -> .url works
            return request.build_absolute_uri(field_file.url)
    except Exception:
        try:
            return field_file.url
        except Exception:
            return ''
    return ''


class EstateFloorPlanSerializer(serializers.ModelSerializer):
    plot_size = PlotSizeSerializer(read_only=True)
    floor_plan_image = serializers.SerializerMethodField()

    class Meta:
        model = EstateFloorPlan
        fields = ('id', 'plan_title', 'plot_size', 'floor_plan_image', 'date_uploaded')

    def get_floor_plan_image(self, obj):
        request = self.context.get('request')
        return absolute_image_url(request, getattr(obj, 'floor_plan_image', None))


class EstatePrototypeSerializer(serializers.ModelSerializer):
    plot_size = PlotSizeSerializer(read_only=True)
    prototype_image = serializers.SerializerMethodField()

    class Meta:
        model = EstatePrototype
        fields = ('id', 'Title', 'Description', 'plot_size', 'prototype_image', 'date_uploaded')

    def get_prototype_image(self, obj):
        request = self.context.get('request')
        return absolute_image_url(request, getattr(obj, 'prototype_image', None))


class EstateLayoutSerializer(serializers.ModelSerializer):
    layout_image = serializers.SerializerMethodField()

    class Meta:
        model = EstateLayout
        fields = ('id', 'layout_image')

    def get_layout_image(self, obj):
        request = self.context.get('request')
        return absolute_image_url(request, getattr(obj, 'layout_image', None))


class EstateMapSerializer(serializers.ModelSerializer):
    # include computed/google link if lat/lng exist
    generate_google_map_link = serializers.SerializerMethodField()
    google_map_link = serializers.SerializerMethodField()

    class Meta:
        model = EstateMap
        fields = ('id', 'latitude', 'longitude', 'google_map_link', 'generate_google_map_link')

    def get_generate_google_map_link(self, obj):
        lat = getattr(obj, 'latitude', None)
        lon = getattr(obj, 'longitude', None)
        if lat is not None and lon is not None:
            return f'https://www.google.com/maps?q={lat},{lon}&z=15'
        return ''

    def get_google_map_link(self, obj):
        # Provide existing model field if present; if not, fall back to computed link
        link = getattr(obj, 'google_map_link', None)
        if link:
            return link
        return self.get_generate_google_map_link(obj)


class EstateListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Estate
        fields = ('id', 'name', 'location', 'estate_size', 'title_deed', 'date_added')


class EstateDetailSerializer(serializers.ModelSerializer):
    # Related lists (serialized as JSON lists)
    progress_status = ProgressStatusSerializer(many=True, read_only=True)
    estate_amenity = EstateAmenitySerializer(many=True, read_only=True)
    estate_layout = EstateLayoutSerializer(many=True, read_only=True)
    map = EstateMapSerializer(many=True, read_only=True)

    # dynamic lists (controlled by SerializerMethodField so we can apply query param filter)
    plot_size_units = serializers.SerializerMethodField()
    floor_plans = serializers.SerializerMethodField()
    prototypes = serializers.SerializerMethodField()

    class Meta:
        model = Estate
        fields = (
            'id', 'name', 'location', 'estate_size', 'title_deed', 'date_added',
            'progress_status', 'estate_amenity', 'estate_layout', 'map',
            'plot_size_units', 'floor_plans', 'prototypes'
        )

    def get_plot_size_units(self, estate):
        # Provide list of PlotSizeUnits for the estate (plot_size nested)
        qs = PlotSizeUnits.objects.filter(estate_plot__estate=estate).select_related('plot_size')
        serializer = PlotSizeUnitsSerializer(qs, many=True, context=self.context)
        return serializer.data

    def get_floor_plans(self, estate):
        request = self.context.get('request')
        plot_size_id = None
        if request:
            plot_size_id = request.query_params.get('plot_size')
        qs = EstateFloorPlan.objects.filter(estate=estate)
        if plot_size_id:
            qs = qs.filter(plot_size_id=plot_size_id)
        qs = qs.select_related('plot_size').order_by('-date_uploaded')
        serializer = EstateFloorPlanSerializer(qs, many=True, context=self.context)
        return serializer.data

    def get_prototypes(self, estate):
        request = self.context.get('request')
        plot_size_id = None
        if request:
            plot_size_id = request.query_params.get('plot_size')
        qs = EstatePrototype.objects.filter(estate=estate)
        if plot_size_id:
            qs = qs.filter(plot_size_id=plot_size_id)
        qs = qs.select_related('plot_size').order_by('-date_uploaded')
        serializer = EstatePrototypeSerializer(qs, many=True, context=self.context)
        return serializer.data
