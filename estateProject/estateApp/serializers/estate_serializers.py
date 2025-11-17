from rest_framework import serializers
from .dynamic_fields_serializer import DynamicFieldsModelSerializer
from estateApp.models import Estate

class EstateSerializer(DynamicFieldsModelSerializer):
    # Include computed properties as read-only fields
    inventory_status = serializers.ReadOnlyField()
    available_floor_plans = serializers.ReadOnlyField()
    layout_url = serializers.ReadOnlyField()
    map_url = serializers.ReadOnlyField()

    class Meta:
        model = Estate
        fields = '__all__'
