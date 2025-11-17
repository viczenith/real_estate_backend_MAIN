from rest_framework import serializers
from estateApp.models import MarketerUser

class MarketerUserSerializer(serializers.ModelSerializer):
    profile_image = serializers.SerializerMethodField()

    class Meta:
        model = MarketerUser
        fields = '__all__'
        extra_kwargs = {
            'full_name': {'required': False},
            'about': {'required': False},
            'company': {'required': False},
            'job': {'required': False},
            'country': {'required': False},
            'address': {'required': False},
            'phone': {'required': False},
            'email': {'required': False},
            
        }

    def get_profile_image(self, obj):
        request = self.context.get('request')
        if obj.profile_image and hasattr(obj.profile_image, 'url'):
            return request.build_absolute_uri(obj.profile_image.url)
        return ''
