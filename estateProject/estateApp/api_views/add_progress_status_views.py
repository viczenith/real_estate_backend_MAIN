from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.utils import timezone
from estateApp.models import Estate, ProgressStatus
from estateApp.serializers.estate_assets_serializers import ProgressStatusSerializer

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def update_work_progress(request, estate_id):
    """
    GET: Return a list of work progress updates for the specified estate.
    POST: Create a new work progress update for the specified estate.
    """
    try:
        estate = Estate.objects.get(id=estate_id)
    except Estate.DoesNotExist:
        return Response({'error': 'Estate not found'}, status=404)
    
    if request.method == 'GET':
        # Return all progress updates for the estate ordered by most recent.
        progress_list = ProgressStatus.objects.filter(estate=estate).order_by('-timestamp')
        serializer = ProgressStatusSerializer(progress_list, many=True)
        return Response(serializer.data, status=200)
    
    if request.method == 'POST':
        progress_text = request.data.get('progress_status')
        if not progress_text:
            return Response({'error': 'Progress status text is required'}, status=400)
        
        progress = ProgressStatus.objects.create(
            estate=estate,
            progress_status=progress_text,
            timestamp=timezone.now()
        )
        serializer = ProgressStatusSerializer(progress)
        return Response(serializer.data, status=201)
