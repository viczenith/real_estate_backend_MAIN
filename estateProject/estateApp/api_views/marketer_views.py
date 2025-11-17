from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from estateApp.models import MarketerUser
from estateApp.serializers.marketer_serializer import MarketerUserSerializer

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def marketer_list(request):
    """
    Retrieve a list of all marketers.
    """
    marketers = MarketerUser.objects.all()
    serializer = MarketerUserSerializer(marketers, many=True, context={'request': request})
    return Response(serializer.data)


@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated])
def marketer_detail(request, pk):
    """
    Retrieve, update, or delete a marketer.
    """
    try:
        marketer = MarketerUser.objects.get(pk=pk)
    except MarketerUser.DoesNotExist:
        return Response({'detail': 'Marketer not found.'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        serializer = MarketerUserSerializer(marketer, context={'request': request})
        return Response(serializer.data)

    elif request.method in ['PUT', 'PATCH']:
        serializer = MarketerUserSerializer(marketer, data=request.data, partial=True, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == 'DELETE':
        marketer.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
