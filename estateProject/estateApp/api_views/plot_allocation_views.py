from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from estateApp.models import PlotSizeUnits, EstatePlot, PlotNumber, Estate, PlotAllocation
# from estateApp.serializers.plot_and_allocation_serializers import (
from estateApp.serializers.plot_allocation_serializer import (
    EstatePlotSerializer, PlotAllocationSerializer,
    UpdatePlotAllocationSerializer, PlotSizeUnitsSerializer,
    PlotNumberSerializer
)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def load_plots_for_plot_allocation(request):
    estate_id = request.query_params.get('estate_id')
    if not estate_id:
        return Response({'detail': 'estate_id is required'}, status=400)

    try:
        estate = Estate.objects.get(id=estate_id)
        estate_plot = EstatePlot.objects.filter(estate=estate).first()
        
        if not estate_plot:
            return Response({
                'plot_size_units': [],
                'plot_numbers': []
            }, status=200)
        
        # Get plot size units with prefetch_related for better performance
        plot_size_units = PlotSizeUnits.objects.filter(
            estate_plot=estate_plot
        ).select_related('plot_size')
        
        # Get plot numbers
        plot_numbers = PlotNumber.objects.filter(
            estates=estate_plot
        )
        
        size_serializer = PlotSizeUnitsSerializer(plot_size_units, many=True)
        number_serializer = PlotNumberSerializer(
            plot_numbers,
            many=True,
            context={'estate': estate}
        )
        
        return Response({
            'plot_size_units': size_serializer.data,
            'plot_numbers': number_serializer.data
        })
        
    except Estate.DoesNotExist:
        return Response({'detail': 'Estate not found'}, status=404)
    except Exception as e:
        return Response({'detail': str(e)}, status=400)
    

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_availability(request, size_id):
    """
    GET /api/check-availability/{size_id}/
    Returns { available: int, message: str }
    """
    try:
        unit = PlotSizeUnits.objects.get(id=size_id)
    except PlotSizeUnits.DoesNotExist:
        return Response({'available': 0, 'message': 'Invalid size_id'}, status=404)

    allocated = unit.full_allocations + unit.part_allocations
    available = unit.total_units - allocated
    msg = (
        f"{unit.plot_size.size} sqm units available: {available}"
        if available>0
        else f"{unit.plot_size.size} sqm fully allocated"
    )
    return Response({'available': available, 'message': msg})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def available_plot_numbers(request, estate_id):
    """
    GET /api/available-plot-numbers/{estate_id}/
    Returns list of { id, number } not yet allocated.
    """
    numbers = PlotNumber.objects.filter(
        estates__estate_id=estate_id
    ).exclude(
        plotallocation__isnull=False
    )
    serializer = PlotNumberSerializer(numbers, many=True)
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_allocation(request):
    serializer = UpdatePlotAllocationSerializer(data=request.data)
    if serializer.is_valid():
        try:
            allocation = serializer.save()
            return Response({
                'status': 'success',
                'allocation_id': allocation.id,
                'client': allocation.client.full_name,
                'plot_size': allocation.plot_size.size,
                'plot_number': allocation.plot_number.number if allocation.plot_number else None
            }, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({
                'status': 'error',
                'message': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)
    return Response({
        'status': 'error',
        'errors': serializer.errors
    }, status=status.HTTP_400_BAD_REQUEST)





