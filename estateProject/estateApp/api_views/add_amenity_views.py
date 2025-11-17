from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from estateApp.models import Estate, EstateAmenitie
from estateApp.serializers.estate_assets_serializers import EstateAmenitieSerializer
from estateApp.models import AMENITIES_CHOICES, AMENITY_ICONS

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_estate_amenities(request):
    # Get the estate id from the request data.
    estate_id = request.data.get('estate')
    if not estate_id:
        return Response({'error': 'Estate ID is required'}, status=400)
    try:
        estate = Estate.objects.get(id=estate_id)
    except Estate.DoesNotExist:
        return Response({'error': 'Estate not found'}, status=404)
    
    # Retrieve amenities from the request.
    # Expecting JSON payload so we use .get() directly.
    amenities_codes = request.data.get('amenities', [])
    if not isinstance(amenities_codes, list):
        amenities_codes = [amenities_codes]
    
    # Update or create the EstateAmenitie record for this estate.
    amenity_obj, created = EstateAmenitie.objects.get_or_create(estate=estate)
    amenity_obj.amenities = amenities_codes
    amenity_obj.save()

    serializer = EstateAmenitieSerializer(amenity_obj, context={'request': request})
    return Response(serializer.data, status=200)



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_available_amenities(request):
    amenities = [
        {'code': code, 'name': name, 'icon': AMENITY_ICONS.get(code, '')}
        for code, name in AMENITIES_CHOICES
    ]
    return Response(amenities)

