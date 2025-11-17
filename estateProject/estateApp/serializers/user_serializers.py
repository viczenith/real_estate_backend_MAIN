from .dynamic_fields_serializer import DynamicFieldsModelSerializer
from estateApp.models import CustomUser

class NestedUserSerializer(DynamicFieldsModelSerializer):
    class Meta:
        model = CustomUser
        fields = ('id', 'full_name', 'email')

class CustomUserSerializer(DynamicFieldsModelSerializer):
    # Optionally include nested marketer information if available
    marketer = NestedUserSerializer(read_only=True)
    
    class Meta:
        model = CustomUser
        fields = '__all__'
