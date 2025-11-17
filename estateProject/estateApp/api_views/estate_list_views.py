# from rest_framework.decorators import api_view, permission_classes
# from rest_framework.permissions import IsAuthenticated
# from rest_framework.response import Response
# from rest_framework import status
# from estateApp.models import Estate
# from estateApp.serializers.estate_list_serializer import EstateSerializer

# @api_view(['GET'])
# @permission_classes([IsAuthenticated])
# def get_estate_list(request):
#     """
#     Returns a list of all estates.
#     """
#     estates = Estate.objects.all()
#     serializer = EstateSerializer(estates, many=True)
#     return Response(serializer.data, status=status.HTTP_200_OK)


from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from estateApp.models import Estate
from estateApp.serializers.estate_list_serializer import EstateSerializer, EstateUpdateSerializer

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_estate_list(request):
    """
    Returns a list of all estates.
    """
    estates = Estate.objects.all().order_by('-date_added')
    serializer = EstateSerializer(estates, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)



@api_view(['GET', 'PUT'])
@permission_classes([IsAuthenticated])
def update_estate(request, pk):
    """
    Retrieve or update an estate instance.
    """
    try:
        estate = Estate.objects.get(pk=pk)
    except Estate.DoesNotExist:
        return Response(status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        serializer = EstateSerializer(estate)
        return Response(serializer.data)

    elif request.method == 'PUT':
        serializer = EstateUpdateSerializer(estate, data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
