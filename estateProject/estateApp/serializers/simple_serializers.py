from rest_framework import serializers
from estateApp.models import PlotSize, PlotNumber, Estate

class PlotSizeSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlotSize
        fields = '__all__'

class PlotNumberSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlotNumber
        fields = '__all__'

class EstateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Estate
        fields = '__all__'