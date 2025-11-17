from rest_framework import serializers
from estateApp.models import PlotSize, PlotNumber, PlotSizeUnits, EstatePlot, PlotAllocation

class PlotSizeSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlotSize
        fields = ['id', 'size']

class PlotSizeUnitsSerializer(serializers.ModelSerializer):
    plot_size = PlotSizeSerializer(read_only=True)
    plot_size_id = serializers.PrimaryKeyRelatedField(
        source='plot_size', queryset=PlotSize.objects.all(), write_only=True
    )

    class Meta:
        model = PlotSizeUnits
        fields = [
            'id',
            'plot_size',
            'plot_size_id',
            'total_units',
            'available_units',
        ]
        read_only_fields = ['available_units']

class PlotNumberSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlotNumber
        fields = ['id', 'number']

class EstatePlotDetailSerializer(serializers.ModelSerializer):
    plotsizeunits = PlotSizeUnitsSerializer(many=True, read_only=True)
    plot_numbers = PlotNumberSerializer(many=True, read_only=True)

    class Meta:
        model = EstatePlot
        fields = ['id', 'estate', 'plotsizeunits', 'plot_numbers']


class EstatePlotUpdateSerializer(serializers.Serializer):
    """
    Expect payload:
      {
        "units": { "<plotsize_id>": <total_units>, ... },
        "plot_numbers": [<plot_number_id>, ...]
      }
    """
    units = serializers.DictField(
        child=serializers.IntegerField(min_value=1),
        help_text="Map of PlotSize ID → total_units"
    )
    plot_numbers = serializers.ListField(
        child=serializers.IntegerField(), help_text="List of selected PlotNumber IDs"
    )

    def validate(self, data):
        total_units = sum(data['units'].values())
        if total_units != len(data['plot_numbers']):
            raise serializers.ValidationError(
                "Sum of total_units must equal number of selected plot_numbers."
            )
        return data

    def update(self, instance: EstatePlot, validated_data):
        # 1. Update/replace PlotSizeUnits
        #   Remove existing size-units
        instance.plotsizeunits.all().delete()
        #   Create new ones
        for size_id, total in validated_data['units'].items():
            PlotSizeUnits.objects.create(
                estate_plot=instance,
                plot_size_id=size_id,
                total_units=total
            )
        # 2. Update plot_numbers M2M
        instance.plot_numbers.set(validated_data['plot_numbers'])
        instance.full_clean()  # ensure clean validation
        instance.save()
        return instance




