from rest_framework import serializers
from estateApp.models import Estate, EstatePlot

class AddEstatePlotSerializer(serializers.Serializer):
    estate = serializers.PrimaryKeyRelatedField(queryset=Estate.objects.all())
    plot_sizes = serializers.ListField(child=serializers.DictField())
    plot_numbers = serializers.ListField(child=serializers.IntegerField())

    def validate(self, data):
        estate = data['estate']
        new_plot_numbers = data['plot_numbers']
        
        # Check for conflicts with plot numbers that belong to other estates
        conflicts = EstatePlot.objects.exclude(estate=estate)\
            .filter(plot_numbers__id__in=new_plot_numbers)\
            .values_list('plot_numbers__number', flat=True).distinct()
            
        if conflicts.exists():
            friendly_message = (
                "The following plot numbers are already in use: "
                f"{', '.join(map(str, list(conflicts)))}. Please choose different plot numbers."
            )
            raise serializers.ValidationError({'non_field_errors': [friendly_message]})
        
        # Validate that the total number of units equals the number of selected plot numbers.
        total_units = sum(item['units'] for item in data['plot_sizes'])
        if total_units != len(new_plot_numbers):
            raise serializers.ValidationError({
                'non_field_errors': [
                    "The total number of units does not match the number of selected plot numbers. Please verify your inputs."
                ]
            })
            
        return data

class AddEstatePlotDetailsSerializer(serializers.Serializer):
    plot_sizes = serializers.ListField(child=serializers.DictField())
    plot_numbers = serializers.ListField(child=serializers.DictField())
    allocated_plot_ids = serializers.ListField(child=serializers.IntegerField())
    current_estate_plot_ids = serializers.ListField(child=serializers.IntegerField())

    def to_representation(self, instance):
        return {
            'all_plot_sizes': [{'id': s['id'], 'size': s['size']} for s in instance['plot_sizes']],
            'all_plot_numbers': [{'id': n['id'], 'number': n['number']} for n in instance['plot_numbers']],
            'allocated_plot_ids': instance['allocated_plot_ids'],
            'current_plot_numbers': instance['current_estate_plot_ids']
        }



