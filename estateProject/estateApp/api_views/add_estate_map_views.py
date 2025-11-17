from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from estateApp.models import Estate, EstateMap
from estateApp.serializers.estate_assets_serializers import EstateMapSerializer

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def update_estate_map(request, estate_id):
    """
    GET: Return the current estate map details.
    POST: Update the estate map with new latitude, longitude and google_map_link.
    """
    try:
        estate = Estate.objects.get(id=estate_id)
    except Estate.DoesNotExist:
        return Response({"error": "Estate not found"}, status=404)
    
    # Try to get the estate map record; if it does not exist, create a new one.
    try:
        estate_map = EstateMap.objects.get(estate=estate)
    except EstateMap.DoesNotExist:
        estate_map = EstateMap.objects.create(estate=estate)
    
    if request.method == 'GET':
        serializer = EstateMapSerializer(estate_map)
        return Response(serializer.data, status=200)
    
    # For POST, update the existing estate map record.
    serializer = EstateMapSerializer(estate_map, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=200)
    else:
        return Response(serializer.errors, status=400)
