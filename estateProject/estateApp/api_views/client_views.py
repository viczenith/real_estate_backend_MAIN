from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from estateApp.models import ClientUser
from estateApp.serializers.client_serializer import ClientUserSerializer

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def client_list(request):
    """
    Retrieve a list of all clients.
    """
    clients = ClientUser.objects.all()
    serializer = ClientUserSerializer(clients, many=True, context={'request': request})
    return Response(serializer.data)


@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated])
def client_detail(request, pk):
    """
    Retrieve, update, or delete a client.
    """
    try:
        client = ClientUser.objects.get(pk=pk)
    except ClientUser.DoesNotExist:
        return Response({'detail': 'Client not found.'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        serializer = ClientUserSerializer(client, context={'request': request})
        return Response(serializer.data)

    elif request.method in ['PUT', 'PATCH']:
        serializer = ClientUserSerializer(client, data=request.data, partial=True, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == 'DELETE':
        client.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
