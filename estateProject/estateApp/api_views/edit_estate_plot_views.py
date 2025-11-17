from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from estateApp.models import EstatePlot, PlotSize, PlotSizeUnits, PlotNumber

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def edit_estate_plot(request, plot_id):
    """
    API endpoint to update an EstatePlot's configuration.
    
    Expects the following POST data:
      - plot_sizes: list of selected PlotSize IDs (as strings or numbers)
      - For each selected PlotSize, a field "plot_units_{size_id}" with the number of units.
      - plot_numbers: list of selected PlotNumber IDs.
      
    It validates that the total units specified equals the number of plot numbers selected.
    """
    estate_plot = get_object_or_404(EstatePlot, id=plot_id)

    # Retrieve selected plot size IDs.
    selected_plot_sizes = request.data.getlist("plot_sizes")
    if not isinstance(selected_plot_sizes, list):
        selected_plot_sizes = [selected_plot_sizes]

    # Retrieve unit count for each selected plot size.
    selected_units = {}
    for size_id in selected_plot_sizes:
        unit_value = request.data.get(f"plot_units_{size_id}")
        if unit_value is None or unit_value == '':
            continue
        try:
            selected_units[int(size_id)] = int(unit_value)
        except ValueError:
            return Response(
                {"error": f"Invalid unit value for plot size {size_id}"},
                status=400
            )

    # Retrieve selected plot number IDs.
    selected_plot_numbers = request.data.getlist("plot_numbers")
    if not isinstance(selected_plot_numbers, list):
        selected_plot_numbers = [selected_plot_numbers]

    # Validate that the sum of units equals the count of plot numbers.
    total_units = sum(selected_units.values())
    if total_units != len(selected_plot_numbers):
        return Response(
            {"error": "Total plot size units must equal the number of selected plot numbers."},
            status=400
        )

    # Clear existing plot size units and plot numbers.
    estate_plot.plotsizeunits.clear()
    estate_plot.plot_numbers.clear()

    # Create new PlotSizeUnits for each selected plot size.
    for size_id, units in selected_units.items():
        try:
            plot_size_instance = PlotSize.objects.get(id=size_id)
        except PlotSize.DoesNotExist:
            continue
        # Create a new PlotSizeUnits instance.
        unit_obj = PlotSizeUnits.objects.create(
            estate_plot=estate_plot,
            plot_size=plot_size_instance,
            total_units=units,
            full_allocations=0,  # Initially no allocations
            part_allocations=0
        )
        estate_plot.plotsizeunits.add(unit_obj)

    # Add the selected plot numbers to the estate_plot.
    for plot_number_id in selected_plot_numbers:
        try:
            plot_number_instance = PlotNumber.objects.get(id=plot_number_id)
        except PlotNumber.DoesNotExist:
            continue
        estate_plot.plot_numbers.add(plot_number_instance)

    estate_plot.save()
    return Response({"success": True}, status=200)
