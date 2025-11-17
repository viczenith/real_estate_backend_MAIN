from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from estateApp.models import Estate, EstatePlot
from estateApp.serializers.add_estate_serializer import EstateSerializer, EstatePlotSerializer

class AddEstateView(APIView):
    def post(self, request, *args, **kwargs):
        serializer = EstateSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response({"message": "Estate added successfully."}, status=status.HTTP_201_CREATED)
        return Response({"error": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)


class AddEstatePlotView(APIView):
    def post(self, request, *args, **kwargs):
        serializer = EstatePlotSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response({"message": "Estate plot added successfully."}, status=status.HTTP_201_CREATED)
        return Response({"error": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)
