from rest_framework import serializers
from estateApp.models import Estate, EstatePlot

class EstateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Estate
        fields = ['id', 'name', 'location', 'estate_size', 'title_deed']


class EstatePlotSerializer(serializers.ModelSerializer):
    class Meta:
        model = EstatePlot
        fields = ['id', 'estate', 'plot_size', 'plot_number']
