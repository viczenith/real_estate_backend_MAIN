from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Sum
from estateApp.models import CustomUser, Estate, PlotAllocation

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_dashboard_data(request):
    total_clients = CustomUser.objects.filter(role='client').count()
    total_marketers = CustomUser.objects.filter(role='marketer').count()
    total_allocations = PlotAllocation.objects.count()
    pending_allocations = PlotAllocation.objects.filter(payment_type='part').count()

    estates = Estate.objects.all()
    estate_allocations = []
    for estate in estates:
        plots = []
        # Iterate over each estate_plot and then each through model entry.
        for estate_plot in estate.estate_plots.all():
            for unit in estate_plot.plotsizeunits.all():
                plots.append({
                    "plot_size": unit.plot_size.size,        # dynamic plot size string
                    "total_units": unit.total_units,
                    "allocated": unit.full_allocations,        # computed property in your model
                    "reserved": unit.part_allocations,         # computed property in your model
                    "available": unit.available_units,
                })
        # For aggregated estate-level numbers, you may use other queries
        estate_allocations.append({
            "estate": estate.name,
            "location": estate.location,
            "estate_size": estate.estate_size,
            "allocations": PlotAllocation.objects.filter(estate=estate, payment_type='full').count(),
            "pending": PlotAllocation.objects.filter(estate=estate, payment_type='part').count(),
            "available": sum([p["available"] for p in plots]),
            "plots": plots,  # List of plot sizes
        })

    data = {
        "total_clients": total_clients,
        "total_marketers": total_marketers,
        "total_allocations": total_allocations,
        "pending_allocations": pending_allocations,
        "estate_allocations": estate_allocations,
    }
    return Response(data)
