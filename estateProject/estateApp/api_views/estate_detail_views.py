from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from rest_framework import status, generics, permissions
from django.shortcuts import get_object_or_404
from estateApp.models import *
from estateApp.serializers.estate_assets_serializers import (
    EstateDetailSerializer, EstateMapSerializer, EstateFloorPlanSerializer,
    EstatePrototypeSerializer, PlotAllocationSerializer
)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_estate_details(request, estate_id):
    """
    Return full details for a given estate, including nested data.
    """
    try:
        estate = Estate.objects.prefetch_related(
            'map', 'estate_amenity', 'estate_layout', 'floor_plans', 'prototypes', 'progress_status'
        ).get(id=estate_id)
    except Estate.DoesNotExist:
        return Response({"error": "Estate not found"}, status=404)
    
    serializer = EstateDetailSerializer(estate, context={'request': request})
    return Response(serializer.data)



from django.shortcuts import get_object_or_404

@api_view(['GET', 'POST'])
def update_estate_plot(request, estate_id):
    estate_plot = get_object_or_404(EstatePlot, estate_id=estate_id)
    
    if request.method == 'GET':
        plot_sizes = PlotSize.objects.all()
        plot_numbers = PlotNumber.objects.all()
        
        # Get selected plot sizes with their units
        selected_plot_size_units = PlotSizeUnits.objects.filter(estate_plot=estate_plot).select_related('plot_size')
        
        # Prepare response data
        response_data = {
            'plot_sizes': [],
            'plot_numbers': [],
            'selected_plot_sizes': [],
            'selected_plot_numbers': list(estate_plot.plot_numbers.values_list('id', flat=True)),
            'selected_units': {}
        }
        
        # Add all plot sizes with their selection status and units
        for size in plot_sizes:
            size_data = {
                'id': size.id,
                'size': str(size.size),
                'description': getattr(size, 'description', '')
            }
            
            # Check if this size is selected
            plot_size_unit = selected_plot_size_units.filter(plot_size=size).first()
            if plot_size_unit:
                size_data.update({
                    'total_units': plot_size_unit.total_units,
                    'available_units': plot_size_unit.available_units,
                    'is_selected': True
                })
                response_data['selected_plot_sizes'].append(size.id)
                response_data['selected_units'][size.id] = plot_size_unit.total_units
            else:
                size_data.update({
                    'total_units': 0,
                    'available_units': 0,
                    'is_selected': False
                })
            
            response_data['plot_sizes'].append(size_data)
        
        # Add all plot numbers with their allocation status
        for num in plot_numbers:
            response_data['plot_numbers'].append({
                'id': num.id,
                'number': num.number,
                'is_allocated': getattr(num, 'is_allocated', False)
            })
        
        return Response(response_data)
    
    elif request.method == 'POST':
        # Handle form submission
        plot_sizes = request.data.get('plot_sizes', [])
        plot_numbers = request.data.get('plot_numbers', [])
        
        # Validate input
        if not isinstance(plot_sizes, list) or not isinstance(plot_numbers, list):
            return Response({'error': 'Invalid data format'}, status=400)
        
        try:
            # Update plot sizes and units
            PlotSizeUnits.objects.filter(estate_plot=estate_plot).delete()
            for size_data in plot_sizes:
                plot_size = PlotSize.objects.get(id=size_data['id'])
                PlotSizeUnits.objects.create(
                    estate_plot=estate_plot,
                    plot_size=plot_size,
                    total_units=size_data.get('units', 0),
                    available_units=size_data.get('units', 0)
                )
            
            # Update plot numbers
            estate_plot.plot_numbers.clear()
            plot_numbers_to_add = PlotNumber.objects.filter(id__in=plot_numbers)
            estate_plot.plot_numbers.add(*plot_numbers_to_add)
            
            return Response({'status': 'success'})
        except Exception as e:
            return Response({'error': str(e)}, status=400)
        

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def estate_map_detail(request, estate_id):
    """
    Fetch map details for a specific estate.
    """
    try:
        estate_map = EstateMap.objects.get(estate_id=estate_id)
        serializer = EstateMapSerializer(estate_map, context={'request': request})
        return Response(serializer.data)
    except EstateMap.DoesNotExist:
        return Response({"error": "Map data not found for this estate"}, status=404)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def estate_list(request):
    """
    Get a list of all estates with full details.
    """
    estates = Estate.objects.all()
    serializer = EstateDetailSerializer(estates, many=True, context={'request': request})
    return Response(serializer.data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def estate_floor_plans(request, estate_id):
    """
    Get all floor plans for a specific estate.
    """
    try:
        estate = Estate.objects.get(id=estate_id)
    except Estate.DoesNotExist:
        return Response({"error": "Estate not found"}, status=404)
    
    floor_plans = estate.floor_plans.all()
    serializer = EstateFloorPlanSerializer(floor_plans, many=True, context={'request': request})
    return Response(serializer.data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def estate_prototypes(request, estate_id):
    """
    Get all prototypes for a specific estate.
    """
    try:
        estate = Estate.objects.get(id=estate_id)
    except Estate.DoesNotExist:
        return Response({"error": "Estate not found"}, status=404)
    
    prototypes = estate.prototypes.all()
    serializer = EstatePrototypeSerializer(prototypes, many=True, context={'request': request})
    return Response(serializer.data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def estate_allocations(request, estate_id):
    """
    Get all plot allocations for a specific estate.
    """
    allocations = PlotAllocation.objects.filter(estate_id=estate_id).select_related(
        'client', 'estate', 'plot_size', 'plot_number'
    )
    serializer = PlotAllocationSerializer(allocations, many=True)
    return Response(serializer.data)



