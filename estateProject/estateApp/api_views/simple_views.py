from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from estateApp.models import *
from estateApp.serializers.simple_serializers import *


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_estates(request):
    estates = Estate.objects.all()
    serializer = EstateSerializer(estates, many=True)
    return Response(serializer.data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_plot_sizes_estate_plots(request):
    plot_sizes = PlotSize.objects.all()
    serializer = PlotSizeSerializer(plot_sizes, many=True)
    return Response(serializer.data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_plot_numbers(request):
    plot_numbers = PlotNumber.objects.all()
    serializer = PlotNumberSerializer(plot_numbers, many=True)
    return Response(serializer.data)



