from rest_framework import serializers
from .dynamic_fields_serializer import DynamicFieldsModelSerializer
from estateApp.models import PropertyRequest
from .user_serializers import CustomUserSerializer
from .estate_serializers import EstateSerializer


class PropertyRequestSerializer(DynamicFieldsModelSerializer):
    client = CustomUserSerializer(read_only=True)
    estate = EstateSerializer(read_only=True)
    
    class Meta:
        model = PropertyRequest
        fields = '__all__'
