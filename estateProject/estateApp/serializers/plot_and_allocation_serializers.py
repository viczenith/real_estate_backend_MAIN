from rest_framework import serializers
from .dynamic_fields_serializer import DynamicFieldsModelSerializer
from estateApp.models import EstatePlot, PlotSizeUnits, PlotAllocation, PlotNumber, ClientUser, Estate
from .user_serializers import CustomUserSerializer

# class PlotSizeUnitsSerializer(DynamicFieldsModelSerializer):
#     class Meta:
#         model = PlotSizeUnits
#         fields = '__all__'

class PlotSizeUnitsSerializer(DynamicFieldsModelSerializer):
    """
    Serializer for PlotSizeUnits that provides formatted plot size details.
    """
    plot_size = serializers.SerializerMethodField()

    class Meta:
        model = PlotSizeUnits
        fields = [
            'id',
            'plot_size',
            'total_units',
            'full_allocations',
            'part_allocations',
            'available_units',
        ]

    def get_plot_size(self, obj):
        # Return something like "500 sqm"
        if obj.plot_size and hasattr(obj.plot_size, 'size'):
            return f"{obj.plot_size.size}"
        return None
    

# class PlotNumberSerializer(DynamicFieldsModelSerializer):
#     class Meta:
#         model = PlotNumber
#         fields = '__all__'

class PlotNumberSerializer(serializers.ModelSerializer):
    is_allocated = serializers.SerializerMethodField()

    class Meta:
        model = PlotNumber
        fields = ['id', 'number', 'is_allocated']

    def get_is_allocated(self, obj):
        return obj.plotallocation_set.exists()

class EstatePlotSerializer(DynamicFieldsModelSerializer):
    # Nest PlotSizeUnits and PlotNumbers within EstatePlot.
    plotsizeunits = PlotSizeUnitsSerializer(many=True, read_only=True)
    plot_numbers = PlotNumberSerializer(many=True, read_only=True)
    
    class Meta:
        model = EstatePlot
        fields = '__all__'



class PlotAllocationSerializer(DynamicFieldsModelSerializer):
    client = CustomUserSerializer(read_only=True)
    # plot_size_unit = serializers.PrimaryKeyRelatedField(read_only=True)
    plot_size_unit = PlotSizeUnitsSerializer(read_only=True)
    plot_number = PlotNumberSerializer(read_only=True)
    payment_type_display = serializers.CharField(source='get_payment_type_display', read_only=True)

    class Meta:
        model = PlotAllocation
        fields = [
            'id',
            'client',
            'plot_size_unit',
            'plot_number',
            'payment_type',
            'payment_type_display',
            'date_allocated'
        ]



# class UpdatePlotAllocationSerializer(serializers.ModelSerializer):
#     class Meta:
#         model = PlotAllocation
#         fields = ('plot_size_unit', 'payment_type', 'plot_number')

#     def validate(self, data):
#         """
#         Enforce that full-payment allocations require a plot_number,
#         and that the chosen plot_number isn’t already taken in this estate.
#         """
#         alloc = self.instance
#         payment = data.get('payment_type', alloc.payment_type)
#         number = data.get('plot_number', alloc.plot_number)

#         # If full payment, must have a number
#         if payment == 'full' and number is None:
#             raise serializers.ValidationError({
#                 'plot_number': 'Plot number is required for full payment.'
#             })

#         # If a number is chosen, ensure uniqueness
#         if number:
#             conflict = PlotAllocation.objects.filter(
#                 estate=alloc.estate,
#                 plot_number=number
#             ).exclude(pk=alloc.pk).first()
#             if conflict:
#                 raise serializers.ValidationError({
#                     'plot_number': f'This plot number is already allocated to {conflict.client.full_name}.'
#                 })

#         # Validate available units on change of size unit
#         new_unit = data.get('plot_size_unit', alloc.plot_size_unit)
#         if new_unit != alloc.plot_size_unit:
#             if new_unit.available_units <= 0:
#                 raise serializers.ValidationError({
#                     'plot_size_unit': 'No available units left for that plot size.'
#                 })

#         return data

#     def update(self, instance, validated_data):
#         """
#         Adjust available_units on the related PlotSizeUnits if needed,
#         then save.
#         """
#         old_unit = instance.plot_size_unit
#         new_unit = validated_data.get('plot_size_unit', old_unit)

#         # If size unit changed, return one to old and take one from new
#         if new_unit != old_unit:
#             old_unit.available_units += 1
#             old_unit.save()
#             new_unit.available_units -= 1
#             new_unit.save()

#         return super().update(instance, validated_data)




class UpdatePlotAllocationSerializer(serializers.ModelSerializer):
    client = CustomUserSerializer(read_only=True)
    plot_size_unit = serializers.PrimaryKeyRelatedField(
        queryset=PlotSizeUnits.objects.all(),
        help_text="ID of the PlotSizeUnits to allocate"
    )
    payment_type = serializers.ChoiceField(
        choices=PlotAllocation.PAYMENT_TYPE_CHOICES
    )
    plot_number = serializers.PrimaryKeyRelatedField(
        queryset=PlotNumber.objects.all(),
        allow_null=True,
        required=False,
        help_text="ID of the PlotNumber (null if reserving without a specific number)"
    )
    plot_number_choices = serializers.SerializerMethodField()
    date_allocated = serializers.DateField(read_only=True)

    class Meta:
        model = PlotAllocation
        fields = [
            'id',
            'client',
            'plot_size_unit',
            'payment_type',
            'plot_number',
            'plot_number_choices',
            'date_allocated',
        ]

    def get_plot_number_choices(self, allocation):
        estate = allocation.estate
        numbers = PlotNumber.objects.filter(estates__estate=estate).distinct()
        return [
            {
                'id': str(num.id), 
                'label': num.number,
                'is_allocated': PlotAllocation.objects.filter(plot_number=num).exists()
            }
            for num in numbers
        ]




