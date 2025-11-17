# from rest_framework import serializers
# from estateApp.models import PlotAllocation, PlotSizeUnits, PlotNumber

# class UpdateAllocatedPlotSerializer(serializers.ModelSerializer):
#     plot_size_unit = serializers.PrimaryKeyRelatedField(
#         queryset=PlotSizeUnits.objects.all(), required=True
#     )
#     plot_number = serializers.PrimaryKeyRelatedField(
#         queryset=PlotNumber.objects.all(), required=False, allow_null=True
#     )
#     payment_type = serializers.ChoiceField(choices=[('full', 'Full Payment'), ('part', 'Part Payment')])
    
#     class Meta:
#         model = PlotAllocation
#         fields = ['payment_type', 'plot_size_unit', 'plot_number']
    
#     def validate(self, data):
#         if data.get('payment_type') == 'full' and not data.get('plot_number'):
#             raise serializers.ValidationError("For full payment, a plot number must be chosen.")
#         return data


from rest_framework import serializers
from estateApp.models import PlotAllocation, PlotSizeUnits, PlotNumber

class UpdateAllocatedPlotSerializer(serializers.ModelSerializer):
    payment_type = serializers.CharField(source='payment_type')
    plot_size_unit = serializers.PrimaryKeyRelatedField(queryset=PlotSizeUnits.objects.all(), required=False)
    plot_number = serializers.PrimaryKeyRelatedField(queryset=PlotNumber.objects.all(), required=False)
    
    class Meta:
        model = PlotAllocation
        fields = ['id', 'payment_type', 'plot_size_unit', 'plot_number']

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['plot_size_unit'].queryset = PlotSizeUnits.objects.all()
        self.fields['plot_number'].queryset = PlotNumber.objects.all()

    def validate(self, data):
        payment_type = data.get('payment_type', self.instance.payment_type if self.instance else None)
        plot_number = data.get('plot_number', self.instance.plot_number if self.instance else None)

        if payment_type == 'full' and not plot_number:
            raise serializers.ValidationError("For full payment, a plot number must be selected.")
        if payment_type == 'part' and plot_number:
            raise serializers.ValidationError("For part payment, plot number should not be selected.")

        if plot_number and plot_number.is_allocated and plot_number != self.instance.plot_number:
            raise serializers.ValidationError("This plot number is already allocated to another client.")

        return data
