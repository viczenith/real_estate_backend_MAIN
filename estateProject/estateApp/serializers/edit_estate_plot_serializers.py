# serializers.py
from rest_framework import serializers
from estateApp.models import EstatePlot, PlotSize, PlotNumber

class PlotSizeSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlotSize
        fields = ['id', 'size']

class PlotNumberSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlotNumber
        fields = ['id', 'number']

class EstatePlotSerializer(serializers.ModelSerializer):
    # Include related data so your Flutter UI has all necessary information
    plot_sizes = PlotSizeSerializer(many=True, read_only=True)
    plot_numbers = PlotNumberSerializer(many=True, read_only=True)
    
    class Meta:
        model = EstatePlot
        fields = ['id', 'name', 'size', 'plot_sizes', 'plot_numbers']
