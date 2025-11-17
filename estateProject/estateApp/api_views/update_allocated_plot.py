from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from estateApp.models import PlotAllocation, EstatePlot
from estateApp.serializers.update_allocated_plot_serializer import UpdateAllocatedPlotSerializer
from estateApp.serializers.plot_and_allocation_serializers import EstatePlotSerializer

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_allocated_plot(request):
    allocation_id = request.data.get('allocation_id')
    if not allocation_id:
        return Response({"error": "Allocation ID not provided"}, status=400)
    try:
        allocation = PlotAllocation.objects.get(id=allocation_id)
    except PlotAllocation.DoesNotExist:
        return Response({"error": "Allocation not found"}, status=404)

    serializer = UpdateAllocatedPlotSerializer(allocation, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response({"success": True, "data": serializer.data}, status=200)
    return Response(serializer.errors, status=400)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def load_plots(request):
    estate_id = request.query_params.get('estate_id')
    if not estate_id:
        return Response({'error': 'Estate ID not provided'}, status=400)
    try:
        estate_plots = EstatePlot.objects.filter(estate__id=estate_id)
        serializer = EstatePlotSerializer(estate_plots, many=True, context={'request': request})
        return Response(serializer.data, status=200)
    except Exception as e:
        return Response({'error': str(e)}, status=400)