from rest_framework import serializers
from estateApp.models import Estate, PlotAllocation, PlotSizeUnits, PlotNumber
from estateApp.serializers.plot_and_allocation_serializers import PlotAllocationSerializer

class EstateFullDetailSerializer(serializers.ModelSerializer):
    estate_name = serializers.SerializerMethodField()
    plot_sizes = serializers.SerializerMethodField()
    plot_numbers = serializers.SerializerMethodField()
    allocations = serializers.SerializerMethodField()

    class Meta:
        model = Estate
        fields = [
            'id',
            'estate_name',
            'location',
            'estate_size',
            'plot_sizes',
            'plot_numbers',
            'allocations'
        ]

    def get_estate_name(self, obj):
        return obj.name if obj.name else "Unknown Estate"

    def get_plot_sizes(self, obj):
        plot_sizes_data = []
        for estate_plot in obj.estate_plots.all():
            for unit in estate_plot.plotsizeunits.all():
                plot_size_data = {
                    'id': unit.plot_size.id,
                    'size': unit.plot_size.size,
                }
                plot_sizes_data.append({
                    'plot_size': plot_size_data,
                    'allocated': unit.full_allocations,
                    'total_units': unit.total_units,
                    'reserved': unit.part_allocations,
                    'available': unit.total_units - unit.full_allocations if unit.total_units is not None and unit.full_allocations is not None else None,
                })
        return plot_sizes_data

    # def get_plot_numbers(self, obj):
    #     plot_numbers_data = []
    #     for estate_plot in obj.estate_plots.all():
    #         if estate_plot.plot_numbers.exists():
    #             for number in estate_plot.plot_numbers.all():
    #                 plot_numbers_data.append({
    #                     'number': number.number,
    #                     'is_allocated': number.plotallocation_set.exists(),
    #                 })
    #         else:
    #             plot_numbers_data.append({
    #                 'number': 'No plot numbers assigned',
    #                 'is_allocated': False,
    #             })
    #     return plot_numbers_data


    def get_plot_numbers(self, obj):
        plot_numbers_data = []
        for estate_plot in obj.estate_plots.all():
            if estate_plot.plot_numbers.exists():
                for number in estate_plot.plot_numbers.all():
                    plot_numbers_data.append({
                        'id': number.id,  # Include the PlotNumber ID
                        'number': number.number,
                        'is_allocated': number.plotallocation_set.exists(),
                    })
            else:
                plot_numbers_data.append({
                    'id': None,  # Explicitly handle missing ID
                    'number': 'No plot numbers assigned',
                    'is_allocated': False,
                })
        return plot_numbers_data


    def get_allocations(self, obj):
        qs = PlotAllocation.objects.filter(estate=obj)
        return PlotAllocationSerializer(qs, many=True, context=self.context).data



# class UpdateAllocatedPlotSerializer(serializers.ModelSerializer):
#     plot_size_unit = serializers.PrimaryKeyRelatedField(
#         queryset=PlotSizeUnits.objects.none()
#     )
#     plot_number = serializers.PrimaryKeyRelatedField(
#         queryset=PlotNumber.objects.none(),
#         allow_null=True,
#         required=False
#     )

#     def __init__(self, *args, **kwargs):
#         super().__init__(*args, **kwargs)
#         if self.instance:
#             # Get related EstatePlot through the allocation's plot_size_unit
#             estate_plot = self.instance.plot_size_unit.estate_plot
#             estate = estate_plot.estate
            
#             # Filter PlotSizeUnits through EstatePlot
#             self.fields['plot_size_unit'].queryset = PlotSizeUnits.objects.filter(
#                 estate_plot=estate_plot
#             )
            
#             # Filter PlotNumbers through EstatePlot
#             self.fields['plot_number'].queryset = PlotNumber.objects.filter(
#                 estate_plot=estate_plot
#             )

#     class Meta:
#         model = PlotAllocation
#         fields = ('plot_size_unit', 'payment_type', 'plot_number')

#     def validate(self, data):
#         instance = self.instance
#         payment_type = data.get('payment_type', instance.payment_type)
#         plot_number = data.get('plot_number', instance.plot_number)

#         if payment_type == 'full' and not plot_number:
#             raise serializers.ValidationError(
#                 "Plot number is required for full payment allocations."
#             )

#         if plot_number and plot_number.estate_plot != instance.plot_size_unit.estate_plot:
#             raise serializers.ValidationError(
#                 "Plot number does not belong to the same estate plot."
#             )

#         return data



class UpdateAllocatedPlotSerializer(serializers.ModelSerializer):
    plot_size_unit = serializers.PrimaryKeyRelatedField(
        queryset=PlotSizeUnits.objects.none()
    )
    plot_number = serializers.PrimaryKeyRelatedField(
        queryset=PlotNumber.objects.none(),
        allow_null=True,
        required=False
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.instance:
            estate_plot = self.instance.plot_size_unit.estate_plot
            self.fields['plot_size_unit'].queryset = PlotSizeUnits.objects.filter(
                estate_plot=estate_plot
            )
            self.fields['plot_number'].queryset = PlotNumber.objects.filter(
                estate_plot=estate_plot
            )

    def validate(self, data):
        instance = self.instance
        estate_plot = instance.plot_size_unit.estate_plot
        
        if data.get('plot_size_unit'):
            new_unit = data['plot_size_unit']
            if new_unit.estate_plot != estate_plot:
                raise serializers.ValidationError({
                    'plot_size_unit': 'Plot size unit must belong to the same estate plot'
                })

        if data.get('plot_number'):
            plot_number = data['plot_number']
            if plot_number.estate_plot != estate_plot:
                raise serializers.ValidationError({
                    'plot_number': 'Plot number must belong to the same estate plot'
                })

        return data

    class Meta:
        model = PlotAllocation
        fields = ('plot_size_unit', 'payment_type', 'plot_number')

        