from rest_framework import serializers
from estateApp.models import ClientUser

class ClientUserSerializer(serializers.ModelSerializer):
    profile_image = serializers.SerializerMethodField()

    class Meta:
        model = ClientUser
        fields = [
            'id', 'full_name', 'about', 'company', 'job', 'country',
            'address', 'phone', 'email', 'profile_image'
        ]
        extra_kwargs = {
            'full_name': {'required': False},
            'about': {'required': False},
            'company': {'required': False},
            'job': {'required': False},
            'country': {'required': False},
            'address': {'required': False},
            'phone': {'required': False},
            'email': {'required': False},
            # No need for extra_kwargs on profile_image since it’s custom now
        }

    # def get_profile_image(self, obj):
    #     request = self.context.get('request')
    #     if obj.profile_image and hasattr(obj.profile_image, 'url') and request:
    #         return request.build_absolute_uri(obj.profile_image.url)
    #     return None

    def get_profile_image(self, obj):
        request = self.context.get('request')
        if obj.profile_image and request:
            return request.build_absolute_uri(obj.profile_image.url)
        return ''
