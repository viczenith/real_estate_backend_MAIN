from rest_framework import serializers
from estateApp.models import MarketerUser

class MarketerUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = MarketerUser
        fields = '__all__'
