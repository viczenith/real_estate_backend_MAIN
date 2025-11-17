from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from estateApp.models import PlotAllocation

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def delete_allocation(request):
    allocation_id = request.data.get('allocation_id')
    if not allocation_id:
        return Response({'error': 'Allocation ID not provided'}, status=400)
    try:
        allocation = PlotAllocation.objects.get(id=allocation_id)
        allocation.delete()
        return Response({'success': True})
    except PlotAllocation.DoesNotExist:
        return Response({'error': 'Allocation not found'}, status=404)
