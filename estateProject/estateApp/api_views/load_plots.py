from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from estateApp.models import EstatePlot
from estateApp.serializers.plot_and_allocation_serializers import EstatePlotSerializer

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

