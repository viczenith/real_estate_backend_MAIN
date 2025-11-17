from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from estateApp.models import Estate, EstatePlot, PlotSize
from estateApp.serializers.estate_assets_serializers import EstateFloorPlanSerializer
from estateApp.serializers.simple_serializers import PlotSizeSerializer


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def upload_floor_plan(request):
    """
    Expects a multipart/form-data POST request with the following fields:
      - estate: the estate ID (hidden field)
      - plot_size: the plot size ID (selected from dropdown)
      - floor_plan_image: the uploaded image file
      - plan_title: title of the floor plan
      - description: (optional) description text
    """
    data = request.data.copy()

    # Validate that the estate exists.
    estate_id = data.get('estate')
    if not estate_id:
        return Response({"error": "Estate is required"}, status=400)
    try:
        estate = Estate.objects.get(id=estate_id)
    except Estate.DoesNotExist:
        return Response({"error": "Estate not found"}, status=404)

    # Ensure plot_size is provided.
    if not data.get('plot_size'):
        return Response({"error": "Plot size is required"}, status=400)

    serializer = EstateFloorPlanSerializer(data=data, context={'request': request})
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=201)
    return Response(serializer.errors, status=400)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_plot_sizes(request, estate_id):
    """
    API endpoint to fetch available plot sizes for a given estate.
    """
    try:
        # Find the EstatePlot instance for the given estate.
        estate_plot = EstatePlot.objects.filter(estate__id=estate_id).first()
        if not estate_plot:
            return Response({'error': 'EstatePlot not found for this estate'}, status=404)
        
        # Retrieve all PlotSize objects linked to this estate plot.
        plot_sizes = estate_plot.plot_sizes.all()
        serializer = PlotSizeSerializer(plot_sizes, many=True)
        return Response(serializer.data, status=200)
    except Exception as e:
        # Log the error if needed.
        print("Error in get_plot_sizes:", e)
        return Response({'error': str(e)}, status=500)

