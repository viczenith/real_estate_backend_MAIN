from rest_framework import serializers
from .dynamic_fields_serializer import DynamicFieldsModelSerializer
from estateApp.models import EstatePlot, PlotSizeUnits, PlotAllocation, PlotNumber, ClientUser, Estate, PlotSize
from .user_serializers import CustomUserSerializer


class PlotSizeUnitsSerializer(DynamicFieldsModelSerializer):
    size = serializers.CharField(source='plot_size.size', read_only=True)
    full_allocations = serializers.IntegerField(read_only=True)
    reserved_units = serializers.IntegerField(
        source='part_allocations',
        read_only=True
    )
    available_units = serializers.IntegerField(
        source='computed_available_units',
        read_only=True
    )


    class Meta:
        model = PlotSizeUnits
        fields = [
            'id',
            'size',
            'total_units',
            'full_allocations',
            'reserved_units',
            'available_units',
        ]

class PlotNumberSerializer(DynamicFieldsModelSerializer):
    is_available = serializers.SerializerMethodField()
    
    class Meta:
        model = PlotNumber
        fields = ['id', 'number', 'is_available']
    
    def get_is_available(self, obj):
        # Check if plot number is allocated in this estate
        estate = self.context.get('estate')
        if estate:
            return not PlotAllocation.objects.filter(
                estate=estate,
                plot_number=obj
            ).exists()
        return True

class EstatePlotSerializer(DynamicFieldsModelSerializer):
    plot_size_units = PlotSizeUnitsSerializer(many=True, read_only=True)
    plot_numbers = serializers.SerializerMethodField()
    
    class Meta:
        model = EstatePlot
        fields = ['plot_size_units', 'plot_numbers']
    
    def get_plot_numbers(self, obj):
        numbers = obj.plot_numbers.all()
        return PlotNumberSerializer(
            numbers, 
            many=True,
            context={'estate': obj.estate}
        ).data



class PlotAllocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlotAllocation
        fields = ['id', 'client', 'plot_size_unit', 'plot_number', 'payment_type', 'date_allocated']
        read_only_fields = ['date_allocated']

        
class UpdatePlotAllocationSerializer(serializers.ModelSerializer):
    client_id = serializers.PrimaryKeyRelatedField(
        queryset=ClientUser.objects.all(),
        source='client',
        write_only=True
    )
    estate_id = serializers.PrimaryKeyRelatedField(
        queryset=Estate.objects.all(),
        source='estate',
        write_only=True
    )
    plot_size_unit_id = serializers.PrimaryKeyRelatedField(
        queryset=PlotSizeUnits.objects.select_related('plot_size').all(),
        source='plot_size_unit',
        write_only=True
    )

    plot_number_id = serializers.PrimaryKeyRelatedField(
        queryset=PlotNumber.objects.all(),
        source='plot_number',
        write_only=True,
        required=False,
        allow_null=True,
        default=None, 
    )

    class Meta:
        model = PlotAllocation
        fields = [
            'client_id',
            'estate_id',
            'plot_size_unit_id',
            'plot_number_id',
            'payment_type'
        ]

    def validate(self, data):
        payment_type = data.get('payment_type')
        plot_number = data.get('plot_number')

        # full payment must have a plot number
        if payment_type == 'full' and not plot_number:
            raise serializers.ValidationError({
                'plot_number_id': 'Plot number is required for full payment'
            })

        # ensure it isn’t already taken
        if payment_type == 'full' and plot_number:
            estate = data.get('estate')
            if PlotAllocation.objects.filter(estate=estate, plot_number=plot_number).exists():
                raise serializers.ValidationError({
                    'plot_number_id': 'This plot number is already allocated'
                })

        return data

    def create(self, validated_data):
        # automatically set plot_size from the unit
        validated_data['plot_size'] = validated_data['plot_size_unit'].plot_size
        return super().create(validated_data)



