from rest_framework import serializers
from .dynamic_fields_serializer import DynamicFieldsModelSerializer
from estateApp.models import *
from estateApp.models import EstateAmenitie, AMENITIES_CHOICES, AMENITY_ICONS

class PlotSizeSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlotSize
        fields = ['id', 'size']
        read_only_fields = ['id']

class PlotNumberSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlotNumber
        fields = ['id', 'number']
        read_only_fields = ['id']



class EstateFloorPlanSerializer(DynamicFieldsModelSerializer):
    plot_size = serializers.PrimaryKeyRelatedField(queryset=PlotSize.objects.all())
    floor_plan_image_url = serializers.SerializerMethodField()

    class Meta:
        model = EstateFloorPlan
        fields = '__all__'

    def get_floor_plan_image_url(self, obj):
        request = self.context.get('request')
        if obj.floor_plan_image and request:
            return request.build_absolute_uri(obj.floor_plan_image.url)
        return ''

# Prototype Serializer with nested PlotSize and absolute image URL
class EstatePrototypeSerializer(DynamicFieldsModelSerializer):
    plot_size = serializers.PrimaryKeyRelatedField(queryset=PlotSize.objects.all())
    prototype_image_url = serializers.SerializerMethodField()

    class Meta:
        model = EstatePrototype
        fields = '__all__'

    def get_prototype_image_url(self, obj):
        request = self.context.get('request')
        if obj.prototype_image and request:
            return request.build_absolute_uri(obj.prototype_image.url)
        return ''


# Estate Amenitie Serializer with a computed field for display
class EstateAmenitieSerializer(DynamicFieldsModelSerializer):
    amenities_display = serializers.SerializerMethodField()

    class Meta:
        model = EstateAmenitie
        fields = '__all__'

    def get_amenities_display(self, obj):
        choices_dict = dict(AMENITIES_CHOICES)
        if obj.amenities:
            return [
                {
                    'name': choices_dict.get(code, code),
                    'icon': AMENITY_ICONS.get(code, '')
                }
                for code in obj.amenities
            ]
        return []

# Estate Layout Serializer with absolute URL for image
class EstateLayoutSerializer(DynamicFieldsModelSerializer):
    layout_image_url = serializers.SerializerMethodField()
    
    class Meta:
        model = EstateLayout
        fields = '__all__'
    
    def get_layout_image_url(self, obj):
        request = self.context.get('request')
        if obj.layout_image and request:
            return request.build_absolute_uri(obj.layout_image.url)
        return ''

# Estate Map Serializer – returns map info and generated Google Map link
class EstateMapSerializer(serializers.ModelSerializer):
    generated_google_map_link = serializers.ReadOnlyField(source='generate_google_map_link')
    
    class Meta:
        model = EstateMap
        fields = '__all__'

# Progress Status Serializer
class ProgressStatusSerializer(DynamicFieldsModelSerializer):
    class Meta:
        model = ProgressStatus
        fields = '__all__'

# Comprehensive Estate Detail Serializer
class EstateDetailSerializer(serializers.ModelSerializer):
    progress_status = ProgressStatusSerializer(many=True, source='progress_status.all', read_only=True)
    estate_amenity = EstateAmenitieSerializer(many=True, source='estate_amenity.all', read_only=True)
    estate_layout = EstateLayoutSerializer(many=True, source='estate_layout.all', read_only=True)
    floor_plans = EstateFloorPlanSerializer(many=True, source='floor_plans.all', read_only=True)
    prototypes = EstatePrototypeSerializer(many=True, read_only=True)
    map = serializers.SerializerMethodField()
    
    class Meta:
        model = Estate
        fields = [
            'id', 'name', 'location', 'estate_size', 'title_deed',
            'progress_status', 'estate_amenity', 'estate_layout',
            'floor_plans', 'prototypes', 'map'
        ]
    
    def get_map(self, obj):
        map_qs = obj.map.all()
        if map_qs.exists():
            estate_map = map_qs.first()
            return EstateMapSerializer(estate_map, context=self.context).data
        return None
    


class PlotAllocationSerializer(serializers.ModelSerializer):
    client_name = serializers.CharField(source='client.full_name', read_only=True)
    estate_name = serializers.CharField(source='estate.name', read_only=True)
    plot_size_display = serializers.CharField(source='plot_size.size', read_only=True)
    payment_type_display = serializers.CharField(source='get_payment_type_display', read_only=True)

    class Meta:
        model = PlotAllocation
        fields = '__all__'


