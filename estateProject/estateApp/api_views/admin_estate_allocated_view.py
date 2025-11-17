from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from estateApp.models import *
from estateApp.serializers.view_allocated_estate_serializers import (
    EstateFullDetailSerializer, 
    PlotAllocationSerializer, 
    UpdateAllocatedPlotSerializer)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_estate_full_allocation_details(request, estate_id):
    try:
        estate = Estate.objects.get(id=estate_id)
        serializer = EstateFullDetailSerializer(estate, context={'request': request})
        return Response(serializer.data, status=200)
    except Estate.DoesNotExist:
        return Response({"error": "Estate not found"}, status=404)



# @api_view(['PUT', 'PATCH'])
# @permission_classes([IsAuthenticated])
# def update_allocated_plot(request, pk):
#     try:
#         allocation = PlotAllocation.objects.get(pk=pk)
#     except PlotAllocation.DoesNotExist:
#         return Response({'detail': 'Allocation not found.'}, status=status.HTTP_404_NOT_FOUND)

#     partial = (request.method == 'PATCH')
#     serializer = UpdateAllocatedPlotSerializer(allocation, data=request.data, partial=partial)
#     if serializer.is_valid():
#         serializer.save()
#         return Response(PlotAllocationSerializer(allocation).data)
#     return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# @api_view(['PUT', 'PATCH'])
# @permission_classes([IsAuthenticated])
# def update_allocated_plot_for_estate(request, pk):
#     try:
#         allocation = PlotAllocation.objects.get(pk=pk)
#     except PlotAllocation.DoesNotExist:
#         return Response({'detail': 'Allocation not found'}, status=status.HTTP_404_NOT_FOUND)

#     serializer = UpdateAllocatedPlotSerializer(
#         allocation, data=request.data, partial=True, context={'request': request}
#     )
#     if serializer.is_valid():
#         serializer.save()
#         return Response(serializer.data, status=status.HTTP_200_OK)
#     return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# @api_view(['PATCH'])
# @permission_classes([IsAuthenticated])
# def update_allocated_plot_for_estate(request, pk):
#     try:
#         alloc = PlotAllocation.objects.get(pk=pk)
#     except PlotAllocation.DoesNotExist:
#         return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

#     serializer = UpdateAllocatedPlotSerializer(
#       alloc, data=request.data, partial=True, context={'request': request}
#     )
#     if serializer.is_valid():
#         serializer.save()
#         return Response(serializer.data)
#     return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import JSONParser

@api_view(['PATCH'])
@parser_classes([JSONParser])
def update_allocated_plot_for_estate(request, pk):
    alloc = get_object_or_404(PlotAllocation, pk=pk)
    serializer = UpdateAllocatedPlotSerializer(alloc, data=request.data, partial=True)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    serializer.save()
    return Response(serializer.data, status=status.HTTP_200_OK)

    
