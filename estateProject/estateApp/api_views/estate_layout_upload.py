from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from estateApp.models import Estate, EstateLayout
from estateApp.serializers.estate_assets_serializers import EstateLayoutSerializer

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def upload_estate_layout(request):
    """
    API endpoint for uploading an estate layout.
    Expects a multipart/form-data POST request with:
      - 'estate': the ID of the estate (as a form field)
      - 'layout_image': the uploaded image file
    """
    estate_id = request.data.get('estate')
    if not estate_id:
        return Response({"error": "Estate id is required."}, status=400)
    
    try:
        estate = Estate.objects.get(id=estate_id)
    except Estate.DoesNotExist:
        return Response({"error": "Estate not found."}, status=404)
    
    # Copy data to allow modification (DRF's request.data is immutable in multipart)
    data = request.data.copy()
    # Ensure the estate field is set (could be either the id or the estate instance depending on your model)
    data['estate'] = estate.id
    
    serializer = EstateLayoutSerializer(data=data)
    if serializer.is_valid():
        serializer.save()
        return Response({"success": True, "layout": serializer.data}, status=201)
    else:
        return Response(serializer.errors, status=400)
