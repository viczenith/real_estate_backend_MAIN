from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from estateApp.models import Estate
from estateApp.serializers.estate_serializers import EstateSerializer

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_estate_list(request):
    """
    API endpoint that returns a list of all estates in JSON format.
    """
    estates = Estate.objects.all()
    serializer = EstateSerializer(estates, many=True)
    return Response(serializer.data)
