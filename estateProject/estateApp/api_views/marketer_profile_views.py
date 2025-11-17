from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from estateApp.models import MarketerUser
from estateApp.serializers.marketer_profile_serializer import MarketerUserSerializer
from django.shortcuts import get_object_or_404

class MarketerDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        marketer = get_object_or_404(MarketerUser, pk=pk)
        serializer = MarketerUserSerializer(marketer)
        return Response(serializer.data)

    def put(self, request, pk):
        marketer = get_object_or_404(MarketerUser, pk=pk)
        serializer = MarketerUserSerializer(marketer, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({"message": "Marketer profile updated successfully", "data": serializer.data})
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


