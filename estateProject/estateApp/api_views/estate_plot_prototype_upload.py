from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from estateApp.models import EstatePrototype, Estate, PlotSize
from estateApp.serializers.estate_assets_serializers import EstatePrototypeSerializer
from estateApp.serializers.simple_serializers import PlotSizeSerializer


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def upload_estate_prototype(request):
    """
    API endpoint to upload a prototype image along with title, description,
    estate and plot size details.
    """
    serializer = EstatePrototypeSerializer(data=request.data, context={'request': request})
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=201)
    return Response(serializer.errors, status=400)