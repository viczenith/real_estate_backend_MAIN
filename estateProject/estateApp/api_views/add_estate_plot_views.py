from rest_framework.decorators import api_view, permission_classes
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db import transaction, IntegrityError
from estateApp.models import EstatePlot, PlotNumber, PlotSizeUnits, PlotSize, PlotNumber as PlotNumberModel
from estateApp.serializers.add_estate_plot_serializer import AddEstatePlotSerializer

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_add_estate_plot_details(request, estate_id):
    try:
        # Get all plot sizes and numbers.
        all_sizes = PlotSize.objects.all().values('id', 'size')
        all_numbers = PlotNumberModel.objects.all().values('id', 'number')
        
        # Get plot numbers allocated to other estates.
        allocated_ids = EstatePlot.objects.exclude(estate_id=estate_id)\
            .values_list('plot_numbers__id', flat=True).distinct()
            
        # Get current estate configuration if it exists.
        current_plot_data = {'sizes': [], 'numbers': []}
        try:
            estate_plot = EstatePlot.objects.get(estate_id=estate_id)
            current_plot_data['sizes'] = estate_plot.plotsizeunits.all()\
                .values('plot_size__id', 'plot_size__size', 'total_units')
            current_plot_data['numbers'] = list(estate_plot.plot_numbers.values_list('id', flat=True))
        except EstatePlot.DoesNotExist:
            pass

        return Response({
            'all_plot_sizes': list(all_sizes),
            'all_plot_numbers': list(all_numbers),
            'allocated_plot_ids': list(allocated_ids),
            'current_plot_sizes': current_plot_data['sizes'],
            'current_plot_numbers': current_plot_data['numbers']
        })
    except Exception:
        # Return a general friendly error message.
        return Response(
            {"error": "An error occurred while retrieving plot details. Please try again later."},
            status=status.HTTP_400_BAD_REQUEST
        )

class AddEstatePlotView(generics.CreateAPIView):
    serializer_class = AddEstatePlotSerializer
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        estate = serializer.validated_data['estate']
        plot_sizes = serializer.validated_data['plot_sizes']
        new_plot_numbers = serializer.validated_data['plot_numbers']

        estate_plot, created = EstatePlot.objects.get_or_create(estate=estate)
        
        # Prevent removal of plot numbers that already have allocations.
        current_allocated_numbers = estate_plot.plot_numbers.filter(
            plotallocation__estate=estate
        ).values_list('id', flat=True)
        
        for allocated_id in current_allocated_numbers:
            if allocated_id not in new_plot_numbers:
                allocated_plot = PlotNumberModel.objects.get(id=allocated_id)
                return Response(
                    {"error": (
                        f"Plot number '{allocated_plot.number}' has existing allocations and cannot be removed. "
                        "Please adjust your selection."
                    )},
                    status=status.HTTP_400_BAD_REQUEST
                )

        # Update plot numbers.
        try:
            estate_plot.plot_numbers.set(new_plot_numbers)
        except IntegrityError:
            return Response(
                {"error": "There was a problem updating the plot numbers. Please check your input and try again."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Update or create plot size units.
        existing_units = {str(unit.plot_size_id): unit for unit in estate_plot.plotsizeunits.all()}
        for size_data in plot_sizes:
            plot_size_id = str(size_data['plot_size_id'])
            units = size_data['units']
            
            if plot_size_id in existing_units:
                unit = existing_units[plot_size_id]
                total_allocated = unit.full_allocations + unit.part_allocations
                
                if units < total_allocated:
                    return Response(
                        {
                            'error': (
                                f"Cannot decrease plot size {unit.plot_size.size} below current total allocations. "
                                f"Allocated: {unit.full_allocations}, Reserve: {unit.part_allocations}, "
                                f"Total Allocation: {total_allocated}"
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )
                
                unit.total_units = units
                unit.available_units = units - total_allocated
                unit.save()
            else:
                PlotSizeUnits.objects.create(
                    estate_plot=estate_plot,
                    plot_size_id=size_data['plot_size_id'],
                    total_units=units,
                    available_units=units
                )

        # Remove any unused plot size units.
        selected_ids = {str(s['plot_size_id']) for s in plot_sizes}
        for unit in existing_units.values():
            if str(unit.plot_size_id) not in selected_ids:
                if unit.allocations.exists():
                    return Response(
                        {"error": f"You cannot remove the plot size '{unit.plot_size.size}' because it has existing allocations."},
                        status=status.HTTP_400_BAD_REQUEST
                    )
                unit.delete()

        return Response(
            {'message': 'Your estate plot configuration has been saved successfully.'},
            status=status.HTTP_201_CREATED
        )




